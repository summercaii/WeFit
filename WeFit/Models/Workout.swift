import Foundation

enum WorkoutType: String, Codable, CaseIterable {
    case running
    case weightlifting
    case basketball
    
    var displayName: String {
        switch self {
        case .running:
            return "Running"
        case .weightlifting:
            return "Weightlifting"
        case .basketball:
            return "Basketball"
        }
    }
    
    var icon: String {
        switch self {
        case .running:
            return "figure.run"
        case .weightlifting:
            return "figure.strengthtraining.traditional"
        case .basketball:
            return "basketball.fill"
        }
    }
}

struct Workout: Identifiable, Codable {
    let id: UUID
    let user_id: UUID
    let workout_date: Date
    let workout_type: WorkoutType
    let points: Double
    let created_at: Date
    
    // Optional detailed information
    var basketballDetails: BasketballWorkoutDetails?
    var runningDetails: RunningWorkoutDetails?
    var weightliftingDetails: WeightliftingWorkoutDetails?
}

// MARK: - Basketball Workout Details
struct BasketballWorkoutDetails: Codable {
    let workout_id: UUID
    let shots_attempted_inside: Int
    let shots_made_inside: Int
    let shots_attempted_wing: Int
    let shots_made_wing: Int
    let shots_attempted_shoulder: Int
    let shots_made_shoulder: Int
    let shots_attempted_corner: Int
    let shots_made_corner: Int
    let total_shots_attempted: Int
    let total_shots_made: Int
    
    var overallShootingPercentage: Double {
        guard total_shots_attempted > 0 else { return 0.0 }
        return (Double(total_shots_made) / Double(total_shots_attempted)) * 100
    }
    
    var insideShootingPercentage: Double {
        guard shots_attempted_inside > 0 else { return 0.0 }
        return (Double(shots_made_inside) / Double(shots_attempted_inside)) * 100
    }
    
    var wingShootingPercentage: Double {
        guard shots_attempted_wing > 0 else { return 0.0 }
        return (Double(shots_made_wing) / Double(shots_attempted_wing)) * 100
    }
    
    var shoulderShootingPercentage: Double {
        guard shots_attempted_shoulder > 0 else { return 0.0 }
        return (Double(shots_made_shoulder) / Double(shots_attempted_shoulder)) * 100
    }
    
    var cornerShootingPercentage: Double {
        guard shots_attempted_corner > 0 else { return 0.0 }
        return (Double(shots_made_corner) / Double(shots_attempted_corner)) * 100
    }
}

// MARK: - Running Workout Details
struct RunningWorkoutDetails: Codable {
    let workout_id: UUID
    let duration: String // PostgreSQL interval as string
    let distance: Double // in miles or kilometers
    let splits: [Double]? // pace splits
    
    var averagePace: Double? {
        guard let splits = splits, !splits.isEmpty else { return nil }
        return splits.reduce(0, +) / Double(splits.count)
    }
    
    var formattedDuration: String {
        // Convert PostgreSQL interval to readable format
        return duration
    }
    
    var formattedDistance: String {
        return String(format: "%.2f miles", distance)
    }
}

// MARK: - Weightlifting Workout Details
struct WeightliftingWorkoutDetails: Codable {
    let workout_id: UUID
    let workout_name: String?
    let sets: Int
    let reps: [Int] // Array of reps per set
    let weight: [Double] // Array of weights per set
    
    var totalVolume: Double {
        var volume = 0.0
        for i in 0..<min(reps.count, weight.count) {
            volume += Double(reps[i]) * weight[i]
        }
        return volume
    }
    
    var averageWeight: Double {
        guard !weight.isEmpty else { return 0.0 }
        return weight.reduce(0, +) / Double(weight.count)
    }
    
    var totalReps: Int {
        return reps.reduce(0, +)
    }
}
