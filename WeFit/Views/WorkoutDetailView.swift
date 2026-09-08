import SwiftUI

struct WorkoutDetailView: View {
    let workoutId: String
    @State private var workout: Workout?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Loading workout details...")
                            .padding()
                    } else if let errorMessage = errorMessage {
                        ErrorView(message: errorMessage)
                    } else if let workout = workout {
                        WorkoutDetailContent(workout: workout)
                    }
                }
                .padding()
            }
            .navigationTitle("Workout Details")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadWorkoutDetails()
        }
    }
    
    private func loadWorkoutDetails() async {
        do {
            let workoutService = WorkoutService()
            let detailedWorkout = try await workoutService.fetchWorkoutDetails(workoutId: workoutId)
            
            await MainActor.run {
                self.workout = detailedWorkout
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load workout details: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

struct WorkoutDetailContent: View {
    let workout: Workout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header Section
            WorkoutHeaderSection(workout: workout)
            
            // Detailed Stats Section
            switch workout.workout_type {
            case .basketball:
                if let details = workout.basketballDetails {
                    BasketballStatsSection(details: details)
                } else {
                    NoDetailsSection(workoutType: "Basketball")
                }
            case .running:
                if let details = workout.runningDetails {
                    RunningStatsSection(details: details)
                } else {
                    NoDetailsSection(workoutType: "Running")
                }
            case .weightlifting:
                if let details = workout.weightliftingDetails {
                    WeightliftingStatsSection(details: details)
                } else {
                    NoDetailsSection(workoutType: "Weightlifting")
                }
            }
        }
    }
}

// MARK: - Header Section
struct WorkoutHeaderSection: View {
    let workout: Workout
    
    var body: some View {
        VStack(spacing: 16) {
            // Workout Type and Icon
            HStack {
                Image(systemName: workout.workout_type.icon)
                    .font(.system(size: 40))
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading) {
                    Text(workout.workout_type.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(workout.workout_date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Points Badge
                VStack {
                    Text("\(Int(workout.points))")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Basketball Stats Section
struct BasketballStatsSection: View {
    let details: BasketballWorkoutDetails
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basketball Stats")
                .font(.title2)
                .fontWeight(.bold)
            
            // Overall Stats
            StatsCard(title: "Overall Performance") {
                HStack {
                    WorkoutStatItem(
                        title: "Total Shots",
                        value: "\(details.total_shots_made)/\(details.total_shots_attempted)",
                        subtitle: "Made/Attempted"
                    )
                    
                    WorkoutStatItem(
                        title: "Shooting %",
                        value: String(format: "%.1f%%", details.overallShootingPercentage),
                        subtitle: "Accuracy"
                    )
                }
            }
            
            // Zone Breakdown
            StatsCard(title: "Shooting by Zone") {
                VStack(spacing: 12) {
                    ShootingZoneRow(
                        zone: "Inside",
                        made: details.shots_made_inside,
                        attempted: details.shots_attempted_inside,
                        percentage: details.insideShootingPercentage
                    )
                    
                    ShootingZoneRow(
                        zone: "Wing",
                        made: details.shots_made_wing,
                        attempted: details.shots_attempted_wing,
                        percentage: details.wingShootingPercentage
                    )
                    
                    ShootingZoneRow(
                        zone: "Shoulder",
                        made: details.shots_made_shoulder,
                        attempted: details.shots_attempted_shoulder,
                        percentage: details.shoulderShootingPercentage
                    )
                    
                    ShootingZoneRow(
                        zone: "Corner",
                        made: details.shots_made_corner,
                        attempted: details.shots_attempted_corner,
                        percentage: details.cornerShootingPercentage
                    )
                }
            }
        }
    }
}

struct ShootingZoneRow: View {
    let zone: String
    let made: Int
    let attempted: Int
    let percentage: Double
    
    var body: some View {
        HStack {
            Text(zone)
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)
            
            Text("\(made)/\(attempted)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .center)
            
            Spacer()
            
            Text(String(format: "%.1f%%", percentage))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(percentage >= 50 ? .green : percentage >= 30 ? .orange : .red)
        }
    }
}

// MARK: - Running Stats Section
struct RunningStatsSection: View {
    let details: RunningWorkoutDetails
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Running Stats")
                .font(.title2)
                .fontWeight(.bold)
            
            StatsCard(title: "Performance") {
                HStack {
                    WorkoutStatItem(
                        title: "Distance",
                        value: details.formattedDistance,
                        subtitle: "Miles"
                    )
                    
                    WorkoutStatItem(
                        title: "Duration",
                        value: details.formattedDuration,
                        subtitle: "Time"
                    )
                }
            }
            
            if let averagePace = details.averagePace {
                StatsCard(title: "Pace Analysis") {
                    WorkoutStatItem(
                        title: "Average Pace",
                        value: String(format: "%.2f", averagePace),
                        subtitle: "min/mile"
                    )
                }
            }
        }
    }
}

// MARK: - Weightlifting Stats Section
struct WeightliftingStatsSection: View {
    let details: WeightliftingWorkoutDetails
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weightlifting Stats")
                .font(.title2)
                .fontWeight(.bold)
            
            if let workoutName = details.workout_name {
                StatsCard(title: "Workout") {
                    Text(workoutName)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            
            StatsCard(title: "Performance") {
                VStack(spacing: 12) {
                    HStack {
                        WorkoutStatItem(
                            title: "Sets",
                            value: "\(details.sets)",
                            subtitle: "Total"
                        )
                        
                        WorkoutStatItem(
                            title: "Reps",
                            value: "\(details.totalReps)",
                            subtitle: "Total"
                        )
                    }
                    
                    HStack {
                        WorkoutStatItem(
                            title: "Volume",
                            value: String(format: "%.0f lbs", details.totalVolume),
                            subtitle: "Total"
                        )
                        
                        WorkoutStatItem(
                            title: "Avg Weight",
                            value: String(format: "%.1f lbs", details.averageWeight),
                            subtitle: "Per Set"
                        )
                    }
                }
            }
            
            // Set by Set Breakdown
            if !details.reps.isEmpty && !details.weight.isEmpty {
                StatsCard(title: "Set Breakdown") {
                    VStack(spacing: 8) {
                        ForEach(Array(zip(details.reps.indices, zip(details.reps, details.weight))), id: \.0) { index, values in
                            HStack {
                                Text("Set \(index + 1)")
                                    .font(.subheadline)
                                    .frame(width: 60, alignment: .leading)
                                
                                Text("\(values.0) reps")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(Int(values.1)) lbs")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Helper Views
struct StatsCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct WorkoutStatItem: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct NoDetailsSection: View {
    let workoutType: String
    
    var body: some View {
        StatsCard(title: "\(workoutType) Details") {
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text("No detailed statistics available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("This workout was logged without detailed metrics")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}


#Preview {
    WorkoutDetailView(workoutId: "sample-id")
} 