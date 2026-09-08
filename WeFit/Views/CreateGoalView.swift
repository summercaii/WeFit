import SwiftUI

struct CreateGoalView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Binding var isPresented: Bool
    let onGoalCreated: (Goal) -> Void
    
    @State private var selectedGoalType: GoalType = .general_fitness
    @State private var target = ""
    @State private var description = ""
    @State private var isCreating = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "target")
                                .font(.system(size: 50))
                                .foregroundColor(Color(AppSettings.Colors.primary))
                            
                            Text("Create Your Goal")
                                .font(.custom(AppSettings.Fonts.title, size: 24))
                                .fontWeight(.bold)
                            
                            Text("Set a specific, measurable goal to track your progress")
                                .font(.custom(AppSettings.Fonts.body, size: 16))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)
                        
                        // Goal Type Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Goal Type")
                                .font(.custom(AppSettings.Fonts.title, size: 18))
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(GoalType.allCases, id: \.self) { goalType in
                                    GoalTypeCard(
                                        goalType: goalType,
                                        isSelected: selectedGoalType == goalType
                                    ) {
                                        selectedGoalType = goalType
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Target Input
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Target")
                                .font(.custom(AppSettings.Fonts.title, size: 18))
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                TextField(placeholderForGoalType(selectedGoalType), text: $target)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.custom(AppSettings.Fonts.body, size: 16))
                                
                                Text(getTargetHint(selectedGoalType))
                                    .font(.custom(AppSettings.Fonts.body, size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Description Input
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Description (Optional)")
                                .font(.custom(AppSettings.Fonts.title, size: 18))
                                .fontWeight(.semibold)
                            
                            ZStack(alignment: .topLeading) {
                                if description.isEmpty {
                                    Text("Add more details about your goal...")
                                        .font(.custom(AppSettings.Fonts.body, size: 16))
                                        .foregroundColor(.secondary)
                                        .padding(.top, 8)
                                        .padding(.leading, 5)
                                }
                                
                                TextEditor(text: $description)
                                    .font(.custom(AppSettings.Fonts.body, size: 16))
                                    .frame(height: 100)
                                    .padding(4)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Create Button
                Button(action: {
                    createGoal()
                }) {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "plus.circle.fill")
                        }
                        Text(isCreating ? "Creating Goal..." : "Create Goal")
                    }
                    .font(.custom(AppSettings.Fonts.body, size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(target.isEmpty ? Color.gray : Color(AppSettings.Colors.primary))
                    )
                }
                .disabled(target.isEmpty || isCreating)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    if !isCreating {
                        isPresented = false
                    }
                }
                .disabled(isCreating)
            )
            .alert("Goal Creation Failed", isPresented: $showingErrorAlert) {
                Button("Try Again") {
                    createGoal()
                }
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func placeholderForGoalType(_ goalType: GoalType) -> String {
        switch goalType {
        case .weight_loss:
            return "e.g., Lose 10 pounds in 3 months"
        case .muscle_gain:
            return "e.g., Gain 5 pounds of muscle"
        case .endurance:
            return "e.g., Run a 5K under 25 minutes"
        case .strength:
            return "e.g., Bench press 150 lbs"
        case .general_fitness:
            return "e.g., Exercise 4 times per week"
        case .habit_building:
            return "e.g., Work out every morning"
        }
    }
    
    private func getTargetHint(_ goalType: GoalType) -> String {
        switch goalType {
        case .weight_loss:
            return "Be specific about weight and timeframe"
        case .muscle_gain:
            return "Specify muscle gain amount or muscle groups"
        case .endurance:
            return "Set distance, time, or performance targets"
        case .strength:
            return "Specify exercise and weight targets"
        case .general_fitness:
            return "Set frequency and activity goals"
        case .habit_building:
            return "Define your new fitness habit"
        }
    }
    
    private func createGoal() {
        guard let currentUser = authManager.currentUser else {
            errorMessage = "You must be logged in to create a goal."
            showingErrorAlert = true
            return
        }
        
        isCreating = true
        
        Task {
            do {
                let goalService = GoalService()
                let newGoal = try await goalService.createGoal(
                    userId: currentUser.id,
                    goalType: selectedGoalType,
                    target: target.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                await MainActor.run {
                    onGoalCreated(newGoal)
                    isCreating = false
                    isPresented = false
                }
                
            } catch {
                print("❌ Error creating goal: \(error)")
                
                await MainActor.run {
                    isCreating = false
                    errorMessage = "Failed to create your goal. Please check your internet connection and try again."
                    showingErrorAlert = true
                }
            }
        }
    }
}

struct GoalTypeCard: View {
    let goalType: GoalType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: goalType.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : Color(AppSettings.Colors.primary))
                
                Text(goalType.displayName)
                    .font(.custom(AppSettings.Fonts.body, size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : Color(AppSettings.Colors.text))
                    .multilineTextAlignment(.center)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(AppSettings.Colors.primary) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    CreateGoalView(isPresented: .constant(true), onGoalCreated: { _ in })
        .environmentObject(AuthenticationManager())
} 