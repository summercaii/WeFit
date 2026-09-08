import SwiftUI

struct Goal: Identifiable {
    let id: UUID
    let goalType: String
    let target: String
    let description: String
    let status: String
    let created_at: Date
}

struct GoalsListView: View {
    @State private var goals: [Goal] = []
    
    var body: some View {
        VStack(spacing: 16) {
            if goals.isEmpty {
                EmptyStateView(
                    imageName: "target",
                    title: "No Goals Set",
                    message: "Set your first fitness goal to start tracking your progress!"
                )
            } else {
                ForEach(goals) { goal in
                    GoalCard(goal: goal)
                }
            }
        }
        .padding()
    }
}

struct GoalCard: View {
    let goal: Goal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.goalType)
                    .font(.headline)
                Spacer()
                StatusBadge(status: goal.status)
            }
            
            Text(goal.target)
                .font(.subheadline)
            
            if !goal.description.isEmpty {
                Text(goal.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
} 
