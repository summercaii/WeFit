import Foundation
import Supabase

enum AuthenticationError: Error {
    case invalidCredentials
    case emailAlreadyExists
    case usernameAlreadyExists
    case networkError
    case unknown
    
    var message: String {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .emailAlreadyExists:
            return "An account with this email already exists"
        case .usernameAlreadyExists:
            return "This username is already taken"
        case .networkError:
            return "Unable to connect to server"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var authError: AuthenticationError?
    @Published var showError = false
    @Published var isLoadingProfile = false
    
    // Reference to your Supabase client
    private let client = DatabaseManager.client
    let userService = UserService()

    func signIn(email: String, password: String) async throws {
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            await MainActor.run {
                isAuthenticated = true
            }
            // Fetch user profile from your public.users table
            try await fetchCurrentUser()
        } catch {
            await MainActor.run {
                authError = .invalidCredentials
                showError = true
            }
            throw AuthenticationError.invalidCredentials
        }
    }
    
    func signUp(username: String, email: String, password: String) async throws {
        // Check if username is taken
        if await isUsernameTaken(username) {
            await MainActor.run {
                authError = .usernameAlreadyExists
                showError = true
            }
            throw AuthenticationError.usernameAlreadyExists
        }
        
        do {
            print("Attempting auth signup with email: \(email)")
            let authResponse = try await client.auth.signUp(email: email, password: password)
            print("Auth signup successful, user ID: \(authResponse.user.id)")
            
            // Give database trigger a moment to complete
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            // Update the username in the users table
            // (since the trigger likely only creates with email)
            try await updateUsername(for: email, to: username)
            
            await MainActor.run {
                isAuthenticated = true
            }
            
            try await fetchCurrentUser()
        } catch let authError as AuthError {
            print("Auth error during signup: \(authError)")
            await MainActor.run {
                if "\(authError)".contains("Password should be at least") {
                    self.authError = .invalidCredentials
                } else if "\(authError)".contains("User already registered") {
                    self.authError = .emailAlreadyExists
                } else {
                    self.authError = .unknown
                }
                showError = true
            }
            throw authError
        } catch {
            print("Unexpected error during signup: \(error)")
            await MainActor.run {
                authError = .unknown
                showError = true
            }
            throw error
        }
    }
    
    func signOut() {
        Task {
            try? await client.auth.signOut()
            await MainActor.run {
                isAuthenticated = false
                currentUser = nil
            }
        }
    }

    // Fetch the current user's profile from your public.users table
    private func fetchCurrentUser() async throws {
        guard let userId = client.auth.currentUser?.id else { return }
        
        await MainActor.run {
            self.isLoadingProfile = true
        }
        
        do {
            // Fetch the user profile directly with the string ID
            var user = try await userService.fetchUser(userId: userId.uuidString)
            
            // Fetch user stats
            let stats = try await userService.fetchUserStats(userId: userId.uuidString)
            user.totalWorkouts = stats.workouts
            user.completedChallenges = stats.challenges
            user.totalPoints = stats.points
            
            await MainActor.run {
                self.currentUser = user
                self.isLoadingProfile = false
            }
        } catch {
            print("Error fetching user profile: \(error)")
            await MainActor.run {
                self.isLoadingProfile = false
            }
            throw error
        }
    }
    
    // Public method to refresh user profile data
    func refreshUserProfile() async {
        do {
            try await fetchCurrentUser()
        } catch {
            print("Failed to refresh user profile: \(error)")
        }
    }

    // Update the username in your public.users table after sign up
    private func updateUsername(for email: String, to username: String) async throws {
        _ = try await client
            .from("users")
            .update(["username": username])
            .eq("email", value: email)
            .execute()
    }

    private func isUsernameTaken(_ username: String) async -> Bool {
        return await userService.isUsernameTaken(username)
    }

    // New method to directly create a user in the users table
    func createUserDirectly(userId: UUID, username: String, email: String) async throws {
        let now = Date()
        
        // Create the user object as an Encodable struct
        struct NewDirectUser: Encodable {
            let id: String
            let username: String
            let email: String
            let created_at: String
        }
        
        let newUser = NewDirectUser(
            id: userId.uuidString,
            username: username,
            email: email,
            created_at: now.ISO8601Format()
        )
        
        print("Creating user directly: \(newUser)")
        
        do {
            // Use the same approach that works in your DatabaseTest.swift
            let response = try await client
                .from("users")
                .insert([newUser])
                .execute()
            
            print("User creation response: \(response.status)")
        } catch {
            print("Error creating user directly: \(error)")
            throw error
        }
    }
}
