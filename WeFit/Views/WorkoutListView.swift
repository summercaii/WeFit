import SwiftUI

struct WorkoutListView: View {
    @State private var workouts: [Workout] = []
    
    var body: some View {
        VStack(spacing: 16) {
            if workouts.isEmpty {
                EmptyStateView(
                    imageName: "figure.run",
                    title: "No Workouts Yet",
                    message: "Start tracking your fitness journey by adding your first workout!"
                )
            } else {
                ForEach(workouts) { workout in
                    WorkoutCard(workout: workout)
                }
            }
        }
        .padding()
    }
}

struct WorkoutCard: View {
    let workout: Workout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForWorkoutType(workout.workoutType))
                    .font(.title2)
                Text(workout.workoutType.rawValue.capitalized)
                    .font(.headline)
                Spacer()
                Text("\(Int(workout.points)) pts")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            
            Text(workout.workoutDate.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private func iconForWorkoutType(_ type: WorkoutType) -> String {
        switch type {
        case .running:
            return "figure.run"
        case .weightlifting:
            return "figure.strengthtraining.traditional"
        case .basketball:
            return "basketball.fill"
        }
    }
} 