import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    var username: String
    var email: String
    let created_at: Date

    
    // Stats and computed properties
    var totalWorkouts: Int = 0
    var completedChallenges: Int = 0
    var totalPoints: Double = 0
} 
