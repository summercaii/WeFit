import Foundation

enum ChallengeType: String, Codable, CaseIterable {
    case group = "group"
    
    var displayName: String {
        return "Group Challenge"
    }
    
    var icon: String {
        return "person.3.fill"
    }
}

enum ChallengeStatus: String, Codable, CaseIterable {
    case active = "active"
    case in_progress = "in_progress"
    case completed = "completed"
    case expired = "expired"
    case joined = "joined"
    case not_joined = "not_joined"
    
    var displayName: String {
        switch self {
        case .active:
            return "Active"
        case .in_progress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .expired:
            return "Expired"
        case .joined:
            return "Joined"
        case .not_joined:
            return "Available"
        }
    }
    
    var color: String {
        switch self {
        case .active, .joined, .in_progress:
            return "blue"
        case .completed:
            return "green"
        case .expired:
            return "red"
        case .not_joined:
            return "gray"
        }
    }
}

struct Challenge: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String?
    let challenge_type: String
    let target: String?
    let points_reward: Double
    let start_date: Date?
    let end_date: Date?
    let created_at: Date
    
    // Computed properties for easier access
    var challengeType: ChallengeType {
        return ChallengeType(rawValue: challenge_type) ?? .group
    }
    
    var pointsReward: Int {
        return Int(points_reward)
    }
    
    var isActive: Bool {
        guard let endDate = end_date else { return true }
        return Date() <= endDate
    }
    
    var isExpired: Bool {
        guard let endDate = end_date else { return false }
        return Date() > endDate
    }
    
    var daysRemaining: Int {
        guard let endDate = end_date else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return max(0, components.day ?? 0)
    }
    
    var formattedEndDate: String {
        guard let endDate = end_date else { return "No deadline" }
        return endDate.formatted(date: .abbreviated, time: .omitted)
    }
}

struct UserChallenge: Codable {
    let user_id: UUID
    let challenge_id: UUID
    let status: String
    let completed_at: Date?
    
    var challengeStatus: ChallengeStatus {
        return ChallengeStatus(rawValue: status) ?? .not_joined
    }
}

struct ChallengeWithUserStatus: Identifiable {
    let challenge: Challenge
    let userStatus: ChallengeStatus
    let userChallenge: UserChallenge?
    
    var id: UUID { challenge.id }
}

struct LeaderboardEntry: Identifiable, Codable {
    let id: UUID
    let user_id: UUID
    let username: String
    let total_points: Double
    let completed_challenges: Int
    
    var formattedPoints: String {
        return String(format: "%.0f", total_points)
    }
} 