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
    
    // Tell Swift which fields to expect from the JSON
    enum CodingKeys: String, CodingKey {
        case id, username, email, created_at
        // Note: stat fields are deliberately excluded
    }
} 
