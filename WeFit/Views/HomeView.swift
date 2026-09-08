import SwiftUI

struct HomeView: View {
    @State private var user = User(id: UUID(), username: "Emma", email: "emma@example.com", created_at: Date(), totalWorkouts: 45, completedChallenges: 12, totalPoints: 3250)
    @State private var recentWorkouts: [Workout] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // User stats section
                    statsGridView
                    
                    // Recent workouts section
                    recentWorkoutsSection
                    
                    // Quick access buttons
                    quickAccessSection
                }
                .padding()
            }
            .navigationTitle("WeFit")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Settings action
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(Color(AppSettings.Colors.primary))
                    }
                }
            }
            .onAppear {
                // Simulated data loading
                loadRecentWorkouts()
            }
        }
    }
    
    // Stats grid section
    private var statsGridView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Stats")
                .font(.custom(AppSettings.Fonts.title, size: 20))
                .foregroundColor(Color(AppSettings.Colors.text))
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(title: "Workouts", value: "\(user.totalWorkouts)", icon: "figure.run")
                StatCard(title: "Challenges", value: "\(user.completedChallenges)", icon: "trophy.fill")
                StatCard(title: "Points", value: "\(Int(user.totalPoints))", icon: "star.fill")
            }
        }
        .padding()
        .background(Color(AppSettings.Colors.background))
        .cornerRadius(12)
    }
    
    // Recent workouts section
    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activities")
                    .font(.custom(AppSettings.Fonts.title, size: 20))
                    .foregroundColor(Color(AppSettings.Colors.text))
                
                Spacer()
                
                NavigationLink(destination: Text("All Activities")) {
                    Text("View All")
                        .font(.custom(AppSettings.Fonts.body, size: 14))
                        .foregroundColor(Color(AppSettings.Colors.primary))
                }
            }
            
            if recentWorkouts.isEmpty {
                EmptyStateView(
                    imageName: "figure.run",
                    title: "No Recent Activities",
                    message: "Complete your first workout to see it here!"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(recentWorkouts) { workout in
                            RecentWorkoutCard(workout: workout)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(AppSettings.Colors.background))
        .cornerRadius(12)
    }
    
    // Quick access buttons
    private var quickAccessSection: some View {
        HStack(spacing: 20) {
            QuickAccessButton(
                title: "Start Workout",
                icon: "play.fill",
                color: Color(AppSettings.Colors.primary)
            )
            
            QuickAccessButton(
                title: "Join Challenge",
                icon: "trophy.fill",
                color: Color(AppSettings.Colors.secondary)
            )
            
            QuickAccessButton(
                title: "Find Friends",
                icon: "person.2.fill",
                color: .orange
            )
        }
    }
    
    // Simulated data loading
    private func loadRecentWorkouts() {
        // Simulate loading workouts
        recentWorkouts = [
            Workout(id: UUID(), userId: user.id, workoutDate: Date().addingTimeInterval(-86400), workoutType: .running, points: 120, created_at: Date().addingTimeInterval(-86400)),
            Workout(id: UUID(), userId: user.id, workoutDate: Date().addingTimeInterval(-172800), workoutType: .weightlifting, points: 100, created_at: Date().addingTimeInterval(-172800)),
            Workout(id: UUID(), userId: user.id, workoutDate: Date().addingTimeInterval(-259200), workoutType: .basketball, points: 150, created_at: Date().addingTimeInterval(-259200))
        ]
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Color(AppSettings.Colors.primary))
            
            Text(value)
                .font(.custom(AppSettings.Fonts.title, size: 22))
                .foregroundColor(Color(AppSettings.Colors.text))
            
            Text(title)
                .font(.custom(AppSettings.Fonts.body, size: 14))
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(height: 110)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct RecentWorkoutCard: View {
    let workout: Workout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: iconForWorkoutType(workout.workoutType))
                    .font(.system(size: 22))
                    .foregroundColor(Color(AppSettings.Colors.primary))
                
                Spacer()
                
                Text("\(Int(workout.points)) pts")
                    .font(.custom(AppSettings.Fonts.body, size: 14))
                    .foregroundColor(Color(AppSettings.Colors.secondary))
            }
            
            Spacer()
            
            Text(workout.workoutType.rawValue.capitalized)
                .font(.custom(AppSettings.Fonts.title, size: 16))
                .foregroundColor(Color(AppSettings.Colors.text))
            
            Text(formattedDate(workout.workoutDate))
                .font(.custom(AppSettings.Fonts.body, size: 12))
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 160, height: 130)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
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
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct QuickAccessButton: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.custom(AppSettings.Fonts.body, size: 12))
                .foregroundColor(Color(AppSettings.Colors.text))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HomeView()
} 
