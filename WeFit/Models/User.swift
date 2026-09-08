import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    var username: String
    var email: String
    let created_at: Date

    
    // Stats from database
    var totalWorkouts: Int = 0
    var completedChallenges: Int = 0
    var challengePoints: Double = 0
    var workoutPoints: Double = 0
    
    // Computed property for total points
    var totalPoints: Double {
        return workoutPoints + challengePoints
    }
    
    // Tell Swift which fields to expect from the JSON
    enum CodingKeys: String, CodingKey {
        case id, username, email, created_at
        case totalWorkouts = "total_workouts"
        case completedChallenges = "completed_challenges"
        case challengePoints = "challenge_points"
        case workoutPoints = "workout_points"
    }
} 
