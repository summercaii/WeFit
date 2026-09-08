import SwiftUI

struct WorkoutListView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var workouts: [Workout] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView("Loading workouts...")
                    .padding()
            } else if workouts.isEmpty {
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
        .onAppear {
            loadWorkouts()
        }
    }
    
    private func loadWorkouts() {
        guard let userId = authManager.currentUser?.id else { 
            print("❌ No user ID found for loading workouts")
            return 
        }
        
        print("🔍 Loading workouts for user ID: \(userId.uuidString)")
        isLoading = true
        
        Task {
            do {
                // First, test the count query like stats do
                print("🧪 Testing count query first...")
                let countResponse = try await DatabaseManager.client
                    .from("workouts")
                    .select("*", count: .exact)
                    .eq("user_id", value: userId.uuidString)
                    .execute()
                print("📊 Count query result: \(countResponse.count ?? 0) workouts found")
                
                let workoutService = WorkoutService()
                // Fetch more workouts for profile view (not just 5 recent ones)
                print("📡 Making database query for workouts...")
                let fetchedWorkouts = try await workoutService.fetchRecentWorkouts(userId: userId.uuidString, limit: 50)
                print("✅ Successfully fetched \(fetchedWorkouts.count) workouts from database")
                
                // Log first few workouts for debugging
                for (index, workout) in fetchedWorkouts.prefix(3).enumerated() {
                    print("Workout \(index + 1): \(workout.workout_type.rawValue) on \(workout.workout_date)")
                }
                
                await MainActor.run {
                    self.workouts = fetchedWorkouts
                    self.isLoading = false
                    print("🎯 Updated UI with \(fetchedWorkouts.count) workouts")
                }
            } catch {
                print("❌ Error loading workouts: \(error)")
                print("❌ Error details: \(String(describing: error))")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct WorkoutCard: View {
    let workout: Workout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForWorkoutType(workout.workout_type))
                    .font(.title2)
                Text(workout.workout_type.rawValue.capitalized)
                    .font(.headline)
                Spacer()
                Text("\(Int(workout.points)) pts")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            
            Text(workout.workout_date.formatted(date: .abbreviated, time: .shortened))
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