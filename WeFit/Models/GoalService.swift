import Foundation

class GoalService {
    
    func createGoal(userId: UUID, goalType: GoalType, target: String, description: String?) async throws -> Goal {
        let goal = Goal(
            user_id: userId,
            goal_type: goalType,
            target: target,
            description: description
        )
        
        print("🎯 Creating goal: \(goalType.displayName) - \(target)")
        
        let response = try await DatabaseManager.client
            .from("goals")
            .insert([
                "user_id": goal.user_id.uuidString,
                "goal_type": goal.goal_type,
                "target": goal.target,
                "description": goal.description ?? "",
                "status": goal.status
            ])
            .execute()
        
        print("✅ Goal created successfully")
        return goal
    }
    
    func fetchUserGoals(userId: UUID) async throws -> [Goal] {
        print("📡 Fetching goals for user: \(userId.uuidString)")
        
        let response = try await DatabaseManager.client
            .from("goals")
            .select("*")
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
        
        let goals = try DatabaseManager.decoder.decode([Goal].self, from: response.data)
        print("✅ Successfully fetched \(goals.count) goals")
        
        return goals
    }
    
    func updateGoalStatus(goalId: UUID, status: GoalStatus) async throws {
        print("🔄 Updating goal status: \(goalId) to \(status.displayName)")
        
        try await DatabaseManager.client
            .from("goals")
            .update([
                "status": status.rawValue,
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: goalId.uuidString)
            .execute()
        
        print("✅ Goal status updated successfully")
    }
    
    func deleteGoal(goalId: UUID) async throws {
        print("🗑️ Deleting goal: \(goalId)")
        
        try await DatabaseManager.client
            .from("goals")
            .delete()
            .eq("id", value: goalId.uuidString)
            .execute()
        
        print("✅ Goal deleted successfully")
    }
} 