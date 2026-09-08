import Foundation
import Supabase

enum AuthenticationError: Error {
    case invalidCredentials
    case emailAlreadyExists
    case usernameAlreadyExists
    case networkError
    case emailVerificationRequired
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
        case .emailVerificationRequired:
            return "Please check your email and click the verification link to complete your account setup"
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

    init() {
        // Check for existing session on app launch
        Task {
            await checkExistingSession()
        }
    }
    
    // Check if there's an existing valid session
    private func checkExistingSession() async {
        do {
            // Get the current session
            let session = try await client.auth.session
            print("🔍 Checking existing session: \(session.user.id)")
            
            await MainActor.run {
                self.isAuthenticated = true
            }
            
            // Fetch user profile
            try await fetchCurrentUser()
            print("✅ Existing session restored successfully")
            
        } catch {
            print("❌ No existing session found: \(error)")
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
            }
        }
    }
    
    // Verify current authentication status
    func verifyAuthenticationStatus() async -> Bool {
        do {
            let session = try await client.auth.session
            let isValid = session.accessToken.count > 0
            print("🔍 Auth verification: Session valid = \(isValid), User ID = \(session.user.id)")
            
            await MainActor.run {
                self.isAuthenticated = isValid
            }
            
            return isValid
        } catch {
            print("❌ Auth verification failed: \(error)")
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
            }
            return false
        }
    }
    
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
            print("🔐 Attempting auth signup with email: \(email)")
            let authResponse = try await client.auth.signUp(email: email, password: password)
            print("✅ Auth signup successful, user ID: \(authResponse.user.id)")
            
            // Wait for database trigger to complete
            print("⏳ Waiting for database trigger to complete...")
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            // Update the username in the users table
            print("📝 Updating username in users table...")
            try await updateUsername(for: email, to: username)
            
            // Important: Verify session is properly established before proceeding
            print("🔍 Verifying session after signup...")
            let isSessionValid = await verifyAuthenticationStatus()
            
            if isSessionValid {
                print("✅ Session verified successfully")
                try await fetchCurrentUser()
                print("✅ User profile fetched successfully")
            } else {
                print("⚠️ Session not immediately available - user needs to verify email")
                // This is normal behavior for email verification - not an error!
                await MainActor.run {
                    self.isAuthenticated = false
                    self.authError = .emailVerificationRequired
                    self.showError = true
                }
                throw AuthenticationError.emailVerificationRequired
            }
            
        } catch let authError as AuthError {
            print("❌ Auth error during signup: \(authError)")
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
        } catch AuthenticationError.emailVerificationRequired {
            // Don't override this error - it's already set with proper message
            print("📧 Email verification required - user has been notified")
            throw AuthenticationError.emailVerificationRequired
        } catch {
            print("❌ Unexpected error during signup: \(error)")
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
        // Verify we have a valid session first
        guard let userId = client.auth.currentUser?.id else {
            print("❌ fetchCurrentUser: No authenticated user found")
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
                self.isLoadingProfile = false
            }
            throw AuthenticationError.invalidCredentials
        }
        
        print("🔍 fetchCurrentUser: Fetching profile for user ID: \(userId)")
        
        await MainActor.run {
            self.isLoadingProfile = true
        }
        
        do {
            // Fetch the user profile directly with the string ID
            var user = try await userService.fetchUser(userId: userId.uuidString)
            print("✅ fetchCurrentUser: User profile fetched successfully")
            
            // Fetch user stats
            print("📊 fetchCurrentUser: Fetching user stats...")
            let stats = try await userService.fetchUserStats(userId: userId.uuidString)
            user.totalWorkouts = stats.workouts
            user.completedChallenges = stats.challenges
            user.totalPoints = stats.points
            print("✅ fetchCurrentUser: User stats fetched successfully")
            
            await MainActor.run {
                self.currentUser = user
                self.isLoadingProfile = false
                self.isAuthenticated = true
            }
        } catch {
            print("❌ fetchCurrentUser: Error fetching user profile: \(error)")
            await MainActor.run {
                self.isLoadingProfile = false
                // Don't reset authentication state on profile fetch failure
                // The session might still be valid
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

