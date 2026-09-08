import SwiftUI

struct GoalsListView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var goals: [Goal] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView("Loading goals...")
                    .padding()
            } else if goals.isEmpty {
                EmptyStateView(
                    imageName: "target",
                    title: "No Goals Set",
                    message: "Set your first fitness goal to start tracking your progress!"
                )
            } else {
                ForEach(goals) { goal in
                    GoalCard(goal: goal) {
                        // Refresh goals when status changes
                        loadGoals()
                    }
                }
            }
        }
        .padding()
        .onAppear {
            loadGoals()
        }
    }
    
    private func loadGoals() {
        guard let userId = authManager.currentUser?.id else {
            print("❌ No user ID found for loading goals")
            return
        }
        
        print("🎯 Loading goals for user ID: \(userId.uuidString)")
        isLoading = true
        
        Task {
            do {
                let goalService = GoalService()
                let fetchedGoals = try await goalService.fetchUserGoals(userId: userId)
                
                await MainActor.run {
                    self.goals = fetchedGoals
                    self.isLoading = false
                    print("✅ Updated UI with \(fetchedGoals.count) goals")
                }
            } catch {
                print("❌ Error loading goals: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct GoalCard: View {
    let goal: Goal
    let onUpdate: () -> Void
    @State private var showingActionSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Goal type icon and name
                HStack(spacing: 8) {
                    Image(systemName: goal.goalType.icon)
                        .font(.system(size: 20))
                        .foregroundColor(Color(AppSettings.Colors.primary))
                    
                    Text(goal.goalType.displayName)
                        .font(.custom(AppSettings.Fonts.title, size: 16))
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                // Status badge and menu
                HStack(spacing: 8) {
                    StatusBadge(status: goal.goalStatus.displayName)
                    
                    Button(action: {
                        showingActionSheet = true
                    }) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Target
            Text(goal.target)
                .font(.custom(AppSettings.Fonts.body, size: 16))
                .foregroundColor(Color(AppSettings.Colors.text))
            
            // Description (if exists)
            if let description = goal.description, !description.isEmpty {
                Text(description)
                    .font(.custom(AppSettings.Fonts.body, size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            // Created date
            Text("Created \(formatDate(goal.created_at))")
                .font(.custom(AppSettings.Fonts.body, size: 12))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .confirmationDialog("Goal Options", isPresented: $showingActionSheet) {
            if goal.goalStatus == .active {
                Button("Mark Complete") {
                    updateGoalStatus(.completed)
                }
                Button("Pause Goal") {
                    updateGoalStatus(.paused)
                }
            } else if goal.goalStatus == .paused {
                Button("Resume Goal") {
                    updateGoalStatus(.active)
                }
                Button("Mark Complete") {
                    updateGoalStatus(.completed)
                }
            } else if goal.goalStatus == .completed {
                Button("Reactivate Goal") {
                    updateGoalStatus(.active)
                }
            }
            
            Button("Delete Goal", role: .destructive) {
                deleteGoal()
            }
            
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func updateGoalStatus(_ newStatus: GoalStatus) {
        Task {
            do {
                let goalService = GoalService()
                try await goalService.updateGoalStatus(goalId: goal.id, status: newStatus)
                
                await MainActor.run {
                    onUpdate()
                }
            } catch {
                print("❌ Error updating goal status: \(error)")
            }
        }
    }
    
    private func deleteGoal() {
        Task {
            do {
                let goalService = GoalService()
                try await goalService.deleteGoal(goalId: goal.id)
                
                await MainActor.run {
                    onUpdate()
                }
            } catch {
                print("❌ Error deleting goal: \(error)")
            }
        }
    }
} 
