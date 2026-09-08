import Foundation

enum WorkoutType: String, Codable, CaseIterable {
    case running
    case weightlifting
    case basketball
}

struct Workout: Identifiable, Codable {
    let id: UUID
    let user_id: UUID
    let workout_date: Date
    let workout_type: WorkoutType
    let points: Double
    let created_at: Date
}
