import Foundation

enum WorkoutType: String, Codable, CaseIterable {
    case running
    case weightlifting
    case basketball
}

struct Workout: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let workoutDate: Date
    let workoutType: WorkoutType
    let points: Double
    let created_at: Date
}
