import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedSegment = 0
    @State private var isEditingProfile = false
    @State private var editedUsername = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                if authManager.isLoadingProfile {
                    ProgressView("Loading profile...")
                        .padding(.top, 100)
                } else if let user = authManager.currentUser {
                VStack(spacing: 20) {
                    // Profile Header
                        ProfileHeaderView(
                            user: user,
                            isEditing: $isEditingProfile,
                            editedUsername: $editedUsername
                        )
                    
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
                } else {
                    Text("Unable to load profile")
                        .foregroundColor(.secondary)
                        .padding(.top, 100)
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditingProfile {
                        Button("Save") {
                            saveProfile()
                        }
                    } else {
                        Button("Edit") {
                            startEditing()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sign Out") {
                        authManager.signOut()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await authManager.refreshUserProfile()
            }
        }
    }
    
    private func startEditing() {
        if let user = authManager.currentUser {
            editedUsername = user.username
        }
        isEditingProfile = true
    }
    
    private func saveProfile() {
        guard var user = authManager.currentUser else { return }
        user.username = editedUsername
        
        Task {
            do {
                try await authManager.userService.updateProfile(user: user)
                await authManager.refreshUserProfile()
                isEditingProfile = false
            } catch {
                print("Error updating profile: \(error)")
            }
        }
    }
}

struct ProfileHeaderView: View {
    let user: User
    @Binding var isEditing: Bool
    @Binding var editedUsername: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
            
            if isEditing {
                TextField("Username", text: $editedUsername)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
                    .multilineTextAlignment(.center)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            } else {
                Text(user.username)
                .font(.title2)
                .bold()
            }
            
            Text(user.email)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Member since \(user.created_at.formatted(.dateTime.month().year()))")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
        .padding(.horizontal)
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
