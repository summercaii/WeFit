import Foundation

enum GoalType: String, CaseIterable {
    case weight_loss = "weight_loss"
    case muscle_gain = "muscle_gain"
    case endurance = "endurance"
    case strength = "strength"
    case general_fitness = "general_fitness"
    case habit_building = "habit_building"
    
    var displayName: String {
        switch self {
        case .weight_loss:
            return "Weight Loss"
        case .muscle_gain:
            return "Muscle Gain"
        case .endurance:
            return "Endurance"
        case .strength:
            return "Strength"
        case .general_fitness:
            return "General Fitness"
        case .habit_building:
            return "Habit Building"
        }
    }
    
    var icon: String {
        switch self {
        case .weight_loss:
            return "arrow.down.circle"
        case .muscle_gain:
            return "figure.strengthtraining.traditional"
        case .endurance:
            return "figure.run"
        case .strength:
            return "dumbbell"
        case .general_fitness:
            return "heart.circle"
        case .habit_building:
            return "repeat.circle"
        }
    }
}

enum GoalStatus: String, CaseIterable {
    case active = "active"
    case completed = "completed"
    case paused = "paused"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .active:
            return "Active"
        case .completed:
            return "Completed"
        case .paused:
            return "Paused"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    var color: String {
        switch self {
        case .active:
            return "green"
        case .completed:
            return "blue"
        case .paused:
            return "orange"
        case .cancelled:
            return "red"
        }
    }
}

struct Goal: Identifiable, Codable {
    let id: UUID
    let user_id: UUID
    let goal_type: String
    let target: String
    let description: String?
    let status: String
    let created_at: Date
    let updated_at: Date
    
    // Computed properties for easier access
    var goalType: GoalType {
        return GoalType(rawValue: goal_type) ?? .general_fitness
    }
    
    var goalStatus: GoalStatus {
        return GoalStatus(rawValue: status) ?? .active
    }
    
    init(id: UUID = UUID(), user_id: UUID, goal_type: GoalType, target: String, description: String? = nil, status: GoalStatus = .active, created_at: Date = Date(), updated_at: Date = Date()) {
        self.id = id
        self.user_id = user_id
        self.goal_type = goal_type.rawValue
        self.target = target
        self.description = description
        self.status = status.rawValue
        self.created_at = created_at
        self.updated_at = updated_at
    }
} 