import Foundation
import Supabase

class UserService {
    // Reference to your Supabase client
    private let client = DatabaseManager.client
    
    // Fetch user profile by ID
    func fetchUser(userId: String) async throws -> User {
        let response = try await client
            .from("users")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
        
        // Debug: Log raw user data to see actual date format
        if let jsonString = String(data: response.data, encoding: .utf8) {
            print("📋 Raw user response data: \(jsonString)")
        }
        
        let decoder = JSONDecoder()
        // Custom date decoder that handles both formats
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try format with microseconds first (users table)
            let formatterWithMicroseconds = DateFormatter()
            formatterWithMicroseconds.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
            if let date = formatterWithMicroseconds.date(from: dateString) {
                return date
            }
            
            // Fall back to format without microseconds (workouts table)
            let formatterNoMicroseconds = DateFormatter()
            formatterNoMicroseconds.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            if let date = formatterNoMicroseconds.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode date string \(dateString)")
            )
        }
        
        return try decoder.decode(User.self, from: response.data)
    }
    
    // Update user profile
    func updateProfile(user: User) async throws {
        // Create a manual dictionary with only the fields we want to update
        let userDict: [String: String] = [
            "username": user.username,
            "email": user.email
        ]
        
        _ = try await client
            .from("users")
            .update(userDict)
            .eq("id", value: user.id.uuidString)
            .execute()
    }
    
    // Fetch user stats
    func fetchUserStats(userId: String) async throws -> (workouts: Int, challenges: Int, points: Double) {
        // This is where you'd implement calls to fetch workout count, completed challenges, etc.
        // For example:
        
        // Fetch workout count
        let workoutsResponse = try await client
            .from("workouts")
            .select("*", count: .exact)
            .eq("user_id", value: userId)
            .execute()
        
        let workoutsCount = workoutsResponse.count ?? 0
        
        // Fetch completed challenges
        let challengesResponse = try await client
            .from("user_challenges")
            .select("*", count: .exact)
            .eq("user_id", value: userId)
            .eq("status", value: "completed")
            .execute()
        
        let challengesCount = challengesResponse.count ?? 0
        
        // Calculate points (this is just an example, adjust based on your app's logic)
        let points = Double(workoutsCount * 10 + challengesCount * 50)
        
        return (workouts: workoutsCount, challenges: challengesCount, points: points)
    }
    
    // Check if username is taken
    func isUsernameTaken(_ username: String) async -> Bool {
        let response = try? await client
            .from("users")
            .select()
            .eq("username", value: username)
            .execute()
        
        return (response?.count ?? 0) > 0
    }
} 