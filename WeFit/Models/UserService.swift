import Foundation
import Supabase

class UserService {
    // Reference to your Supabase client
    private let client = DatabaseManager.client
    
    // Fetch user profile by ID
    func fetchUser(userId: String) async throws -> User {
        let response = try await client
            .from("users")
            .select("id, username, email, created_at, challenge_points, workout_points, completed_challenges, total_workouts")
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
        print("🔍 UserService: Fetching user stats for user_id: \(userId)")
        
        // Fetch workout count and sum of points from workouts
        let workoutsResponse = try await client
            .from("workouts")
            .select("points", count: .exact)
            .eq("user_id", value: userId)
            .execute()
        
        let workoutsCount = workoutsResponse.count ?? 0
        print("📊 UserService: Found \(workoutsCount) workouts")
        
        // Parse workout points from response
        var workoutPoints: Double = 0
        if let jsonData = String(data: workoutsResponse.data, encoding: .utf8) {
            print("📋 Raw workouts response: \(jsonData)")
            
            // Decode the workouts to sum up points
            struct WorkoutPoints: Decodable {
                let points: Double
            }
            
            if let workoutsData = try? JSONDecoder().decode([WorkoutPoints].self, from: workoutsResponse.data) {
                workoutPoints = workoutsData.reduce(0) { $0 + $1.points }
                print("💰 Total workout points: \(workoutPoints)")
            }
        }
        
        // Fetch completed challenges count and sum of points_reward
        let challengesResponse = try await client
            .from("user_challenges")
            .select("challenges(points_reward)", count: .exact)
            .eq("user_id", value: userId)
            .eq("status", value: "completed")
            .execute()
        
        let challengesCount = challengesResponse.count ?? 0
        print("🏆 UserService: Found \(challengesCount) completed challenges")
        
        // Parse challenge points from response
        var challengePoints: Double = 0
        if let jsonData = String(data: challengesResponse.data, encoding: .utf8) {
            print("📋 Raw challenges response: \(jsonData)")
            
            // Decode the challenges to sum up points_reward
            struct ChallengePointsWrapper: Decodable {
                let challenges: ChallengePoints?
                
                struct ChallengePoints: Decodable {
                    let points_reward: Double
                }
            }
            
            if let challengesData = try? JSONDecoder().decode([ChallengePointsWrapper].self, from: challengesResponse.data) {
                challengePoints = challengesData.compactMap { $0.challenges?.points_reward }.reduce(0, +)
                print("💰 Total challenge points: \(challengePoints)")
            }
        }
        
        // Calculate total points from actual database values
        let totalPoints = workoutPoints + challengePoints
        print("💯 UserService: Total points calculated: \(totalPoints) (workouts: \(workoutPoints) + challenges: \(challengePoints))")
        
        return (workouts: workoutsCount, challenges: challengesCount, points: totalPoints)
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
    
    // Sync user stats - recalculate and update challenge_points, workout_points, completed_challenges, total_workouts
    func syncUserStats(userId: String) async throws {
        print("🔄 UserService: Syncing stats for user: \(userId)")
        
        // Get calculated stats
        let stats = try await fetchUserStats(userId: userId)
        
        // Calculate workout points from workouts table
        let workoutsResponse = try await client
            .from("workouts")
            .select("points")
            .eq("user_id", value: userId)
            .execute()
        
        struct WorkoutPoints: Decodable {
            let points: Double
        }
        
        let workouts = try DatabaseManager.decoder.decode([WorkoutPoints].self, from: workoutsResponse.data)
        let workoutPoints = workouts.reduce(0) { $0 + $1.points }
        
        // Calculate challenge points from completed challenges
        let challengesResponse = try await client
            .from("user_challenges")
            .select("challenges(points_reward)")
            .eq("user_id", value: userId)
            .eq("status", value: "completed")
            .execute()
        
        struct ChallengePointsWrapper: Decodable {
            let challenges: ChallengePoints?
            
            struct ChallengePoints: Decodable {
                let points_reward: Double
            }
        }
        
        let challengeData = try DatabaseManager.decoder.decode([ChallengePointsWrapper].self, from: challengesResponse.data)
        let challengePoints = challengeData.compactMap { $0.challenges?.points_reward }.reduce(0, +)
        
        // Update the users table with calculated values
        _ = try await client
            .from("users")
            .update([
                "workout_points": workoutPoints,
                "challenge_points": challengePoints,
                "completed_challenges": Double(stats.challenges),
                "total_workouts": Double(stats.workouts)
            ])
            .eq("id", value: userId)
            .execute()
        
        print("✅ UserService: Successfully synced stats - Workout Points: \(workoutPoints), Challenge Points: \(challengePoints), Total: \(workoutPoints + challengePoints)")
    }
} 