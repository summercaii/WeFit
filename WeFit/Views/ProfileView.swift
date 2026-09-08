import SwiftUI

struct ProfileView: View {
    @State private var user: User? = nil // This would be fetched from your backend
    @State private var selectedSegment = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    ProfileHeaderView(user: user)
                    
                    // Stats Overview
                    StatsGridView(user: user)
                    
                    // Segment Control
                    Picker("Content", selection: $selectedSegment) {
                        Text("Workouts").tag(0)
                        Text("Goals").tag(1)
                        Text("Challenges").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Content based on selected segment
                    switch selectedSegment {
                    case 0:
                        WorkoutListView()
                    case 1:
                        GoalsListView()
                    case 2:
                        ChallengesListView()
                    default:
                        EmptyView()
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Show settings
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
    }
}

struct ProfileHeaderView: View {
    let user: User?
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
            
            Text(user?.username ?? "Username")
                .font(.title2)
                .bold()
            
            Text("Member since \(user?.created_at.formatted(.dateTime.month().year()) ?? "")")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct StatsGridView: View {
    let user: User?
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 20) {
            StatItem(title: "Workouts", value: "\(user?.totalWorkouts ?? 0)")
            StatItem(title: "Challenges", value: "\(user?.completedChallenges ?? 0)")
            StatItem(title: "Points", value: "\(Int(user?.totalPoints ?? 0))")
        }
        .padding(.horizontal)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .bold()
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
} 
