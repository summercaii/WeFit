import Foundation
import Supabase

class ChallengeService {
    private let client = DatabaseManager.client
    
    // MARK: - Fetch Challenges
    
    func fetchChallenges() async throws -> [Challenge] {
        print("📋 ChallengeService: Fetching all challenges")
        
        let response = try await client
            .from("challenges")
            .select()
            .order("created_at", ascending: false)
            .execute()
        
        let challenges = try DatabaseManager.decoder.decode([Challenge].self, from: response.data)
        print("✅ Successfully fetched \(challenges.count) challenges")
        return challenges
    }
    
    func fetchChallengesWithUserStatus(userId: String) async throws -> [ChallengeWithUserStatus] {
        print("📋 ChallengeService: Fetching challenges with user status for user: \(userId)")
        
        // Fetch all challenges
        let challenges = try await fetchChallenges()
        
        // Fetch user's challenge statuses
        let userChallenges = try await fetchUserChallenges(userId: userId)
        let userChallengeDict = Dictionary(uniqueKeysWithValues: userChallenges.map { ($0.challenge_id, $0) })
        
        // Combine challenges with user status
        let challengesWithStatus = challenges.map { challenge in
            let userChallenge = userChallengeDict[challenge.id]
            let status: ChallengeStatus
            
            if let userChallenge = userChallenge {
                status = userChallenge.challengeStatus
            } else if challenge.isExpired {
                status = .expired
            } else {
                status = .not_joined
            }
            
            return ChallengeWithUserStatus(
                challenge: challenge,
                userStatus: status,
                userChallenge: userChallenge
            )
        }
        
        print("✅ Successfully processed \(challengesWithStatus.count) challenges with user status")
        return challengesWithStatus
    }
    
    func fetchUserChallenges(userId: String) async throws -> [UserChallenge] {
        print("📋 ChallengeService: Fetching user challenges for user: \(userId)")
        
        let response = try await client
            .from("user_challenges")
            .select()
            .eq("user_id", value: userId)
            .execute()
        
        let userChallenges = try DatabaseManager.decoder.decode([UserChallenge].self, from: response.data)
        print("✅ Successfully fetched \(userChallenges.count) user challenges")
        return userChallenges
    }
    
    func fetchChallengeDetails(challengeId: String) async throws -> Challenge? {
        print("📋 ChallengeService: Fetching challenge details for ID: \(challengeId)")
        
        let response = try await client
            .from("challenges")
            .select()
            .eq("id", value: challengeId)
            .execute()
        
        let challenges = try DatabaseManager.decoder.decode([Challenge].self, from: response.data)
        let challenge = challenges.first
        
        if challenge != nil {
            print("✅ Successfully fetched challenge details")
        } else {
            print("❌ No challenge found with ID: \(challengeId)")
        }
        
        return challenge
    }
    
    // MARK: - Create Challenge
    
    func createChallenge(
        title: String,
        description: String,
        challengeType: ChallengeType,
        target: String,
        pointsReward: Int,
        duration: Int
    ) async throws -> Challenge {
        print("📝 ChallengeService: Creating new challenge: \(title)")
        
        let now = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: duration, to: now)!
        
        struct CreateChallengeData: Encodable {
            let title: String
            let description: String
            let challenge_type: String
            let target: String
            let points_reward: Double
            let start_date: String
            let end_date: String
        }
        
        let challengeData = CreateChallengeData(
            title: title,
            description: description,
            challenge_type: challengeType.rawValue,
            target: target,
            points_reward: Double(pointsReward),
            start_date: ISO8601DateFormatter().string(from: now),
            end_date: ISO8601DateFormatter().string(from: endDate)
        )
        
        let response = try await client
            .from("challenges")
            .insert([challengeData])
            .select()
            .execute()
        
        let challenges = try DatabaseManager.decoder.decode([Challenge].self, from: response.data)
        guard let newChallenge = challenges.first else {
            throw NSError(domain: "ChallengeService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create challenge"])
        }
        
        print("✅ Successfully created challenge with ID: \(newChallenge.id)")
        return newChallenge
    }
    
    // MARK: - Join/Leave Challenge
    
    func joinChallenge(challengeId: String, userId: String) async throws {
        print("🤝 ChallengeService: User \(userId) joining challenge \(challengeId)")
        
        // First, let's verify the challenge exists
        let challengeResponse = try await client
            .from("challenges")
            .select("id, title")
            .eq("id", value: challengeId)
            .execute()
        
        if challengeResponse.data.isEmpty {
            throw NSError(domain: "ChallengeService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Challenge not found"])
        }
        
        // First check if user has already joined this challenge - be very specific
        print("🔍 Checking for existing join with user_id=\(userId) and challenge_id=\(challengeId)")
        
        let checkResponse = try await client
            .from("user_challenges")
            .select("user_id, challenge_id, status")
            .eq("user_id", value: userId)
            .eq("challenge_id", value: challengeId)
            .limit(1)
            .execute()
        
        // Debug: Show raw response
        if let jsonString = String(data: checkResponse.data, encoding: .utf8) {
            print("🔍 Join check raw response: \(jsonString)")
        }
        
        // Parse the response to see exactly what we got
        do {
            let existingJoins = try JSONDecoder().decode([UserChallenge].self, from: checkResponse.data)
            if !existingJoins.isEmpty {
                print("❌ Join blocked: Found \(existingJoins.count) existing record(s)")
                for join in existingJoins {
                    print("   - Status: \(join.status)")
                }
                throw NSError(domain: "ChallengeService", code: 2, userInfo: [NSLocalizedDescriptionKey: "You have already joined this challenge"])
            }
        } catch {
            if error.localizedDescription.contains("already joined") {
                throw error
            }
            // If we can't parse the response, assume it's empty and continue
            print("⚠️ Could not parse join check response, assuming no existing joins: \(error)")
        }
        
        print("✅ No existing join found, proceeding with insert")
        
        // Create the join record
        struct JoinChallengeData: Encodable {
            let user_id: String
            let challenge_id: String
            let status: String
        }
        
        let joinData = JoinChallengeData(
            user_id: userId,
            challenge_id: challengeId,
            status: "in_progress"
        )
        
        print("🔍 Attempting to insert: user_id=\(userId), challenge_id=\(challengeId), status=in_progress")
        
        do {
            let insertResponse = try await client
                .from("user_challenges")
                .insert([joinData])
                .execute()
            
            print("✅ Successfully joined challenge - insert response received")
            
            // Debug: Show insert response
            if let jsonString = String(data: insertResponse.data, encoding: .utf8) {
                print("🔍 Insert response: \(jsonString)")
            }
        } catch {
            print("❌ Insert failed: \(error.localizedDescription)")
            throw NSError(domain: "ChallengeService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to join challenge: \(error.localizedDescription)"])
        }
    }
    
    func completeChallenge(challengeId: String, userId: String) async throws {
        print("🎉 ChallengeService: User \(userId) completing challenge \(challengeId)")
        
        // First, check if the challenge is already completed
        let statusCheckResponse = try await client
            .from("user_challenges")
            .select("status")
            .eq("user_id", value: userId)
            .eq("challenge_id", value: challengeId)
            .execute()
        
        if !statusCheckResponse.data.isEmpty {
            struct UserChallengeStatus: Codable {
                let status: String
            }
            
            let statusData = try DatabaseManager.decoder.decode([UserChallengeStatus].self, from: statusCheckResponse.data)
            if let currentStatus = statusData.first, currentStatus.status == "completed" {
                print("⚠️ Challenge already completed, not awarding points again")
                throw NSError(domain: "ChallengeService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Challenge already completed"])
            }
        }
        
        // Get the challenge details to know how many points to award
        let challengeResponse = try await client
            .from("challenges")
            .select("points_reward")
            .eq("id", value: challengeId)
            .execute()
        
        guard let challengeData = challengeResponse.data.first else {
            throw NSError(domain: "ChallengeService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Challenge not found"])
        }
        
        // Parse the points reward
        struct ChallengePoints: Codable {
            let points_reward: Double
        }
        
        let challengePoints = try DatabaseManager.decoder.decode([ChallengePoints].self, from: challengeResponse.data)
        guard let challenge = challengePoints.first else {
            throw NSError(domain: "ChallengeService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get challenge points"])
        }
        
        let pointsToAward = challenge.points_reward
        print("🎯 Awarding \(pointsToAward) points to user \(userId)")
        
        let now = ISO8601DateFormatter().string(from: Date())
        
        // Update the user_challenges table to mark as completed
        _ = try await client
            .from("user_challenges")
            .update([
                "status": "completed",
                "completed_at": now
            ])
            .eq("user_id", value: userId)
            .eq("challenge_id", value: challengeId)
            .execute()
        
        // Update the user's challenge points and completed challenges count
        // First get current values
        let userResponse = try await client
            .from("users")
            .select("challenge_points, completed_challenges")
            .eq("id", value: userId)
            .execute()
        
        struct UserStats: Codable {
            let challenge_points: Double?
            let completed_challenges: Int?
        }
        
        let userStats = try DatabaseManager.decoder.decode([UserStats].self, from: userResponse.data)
        guard let currentStats = userStats.first else {
            throw NSError(domain: "ChallengeService", code: 3, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        
        let currentChallengePoints = currentStats.challenge_points ?? 0
        let currentCompletedChallenges = currentStats.completed_challenges ?? 0
        
        let newChallengePoints = currentChallengePoints + pointsToAward
        let newCompletedChallenges = currentCompletedChallenges + 1
        
        print("🎯 Updating user: \(currentChallengePoints) + \(pointsToAward) = \(newChallengePoints) challenge points")
        print("🎯 Updating completed challenges: \(currentCompletedChallenges) + 1 = \(newCompletedChallenges)")
        
        // Update the user's stats
        _ = try await client
            .from("users")
            .update([
                "challenge_points": newChallengePoints,
                "completed_challenges": Double(newCompletedChallenges)
            ])
            .eq("id", value: userId)
            .execute()
        
        print("✅ Successfully completed challenge and awarded \(pointsToAward) points")
    }
    
    func leaveChallenge(challengeId: String, userId: String) async throws {
        print("👋 ChallengeService: User \(userId) leaving challenge \(challengeId)")
        
        _ = try await client
            .from("user_challenges")
            .delete()
            .eq("user_id", value: userId)
            .eq("challenge_id", value: challengeId)
            .execute()
        
        print("✅ Successfully left challenge")
    }
    
    // MARK: - Leaderboard
    
    func fetchLeaderboard(limit: Int = 10) async throws -> [LeaderboardEntry] {
        print("🏆 ChallengeService: Fetching leaderboard (limit: \(limit))")
        
        let response = try await client
            .from("users")
            .select("id, username, challenge_points, completed_challenges")
            .execute()
        
        // Parse the response manually since the structure might be different
        struct LeaderboardUser: Codable {
            let id: UUID
            let username: String
            let challenge_points: Double?
            let completed_challenges: Int?
        }
        
        let users = try DatabaseManager.decoder.decode([LeaderboardUser].self, from: response.data)
        
        let leaderboard = users.map { user in
            let challengePoints = user.challenge_points ?? 0
            return LeaderboardEntry(
                id: user.id,
                user_id: user.id,
                username: user.username,
                total_points: challengePoints, // Only challenge points for leaderboard
                completed_challenges: user.completed_challenges ?? 0
            )
        }
        .sorted { $0.total_points > $1.total_points } // Sort by challenge points descending
        .prefix(limit) // Apply the limit after sorting
        
        print("✅ Successfully fetched leaderboard with \(leaderboard.count) entries")
        return Array(leaderboard)
    }
    
    // MARK: - Challenge Participants
    
    func fetchChallengeParticipants(challengeId: String) async throws -> [LeaderboardEntry] {
        print("👥 ChallengeService: Fetching participants for challenge: \(challengeId)")
        
        let response = try await client
            .from("user_challenges")
            .select("""
                users!inner(id, username, total_points)
            """)
            .eq("challenge_id", value: challengeId)
            .execute()
        
        // This would need custom parsing based on the joined data structure
        // For now, return empty array and implement when needed
        print("✅ Participants query executed")
        return []
    }
} 