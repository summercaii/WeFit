import SwiftUI

struct BasketballWorkoutView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager
    
    // Shot tracking
    @State private var shotsAttemptedInside: Int = 0
    @State private var shotsMadeInside: Int = 0
    @State private var shotsAttemptedWing: Int = 0
    @State private var shotsMadeWing: Int = 0
    @State private var shotsAttemptedShoulder: Int = 0
    @State private var shotsMadeShoulder: Int = 0
    @State private var shotsAttemptedCorner: Int = 0
    @State private var shotsMadeCorner: Int = 0
    
    @State private var isSaving = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // Computed properties
    private var totalShotsAttempted: Int {
        shotsAttemptedInside + shotsAttemptedWing + shotsAttemptedShoulder + shotsAttemptedCorner
    }
    
    private var totalShotsMade: Int {
        shotsMadeInside + shotsMadeWing + shotsMadeShoulder + shotsMadeCorner
    }
    
    private var shootingPercentage: String {
        if totalShotsAttempted == 0 {
            return "0%"
        }
        
        let percentage = Double(totalShotsMade) / Double(totalShotsAttempted) * 100
        return String(format: "%.1f%%", percentage)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overall stats summary
                summarySection
                
                // Shot input form sections
                shotTypeSection(
                    title: "Inside Shots",
                    description: "Shots taken inside the paint",
                    attempted: $shotsAttemptedInside,
                    made: $shotsMadeInside
                )
                
                shotTypeSection(
                    title: "Wing Shots",
                    description: "Mid-range shots from the wing",
                    attempted: $shotsAttemptedWing,
                    made: $shotsMadeWing
                )
                
                shotTypeSection(
                    title: "Shoulder Shots",
                    description: "3-point shots from the shoulder (top)",
                    attempted: $shotsAttemptedShoulder,
                    made: $shotsMadeShoulder
                )
                
                shotTypeSection(
                    title: "Corner Shots",
                    description: "3-point shots from the corner",
                    attempted: $shotsAttemptedCorner,
                    made: $shotsMadeCorner
                )
                
                // Save button
                Button(action: saveWorkout) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Save Workout")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(AppSettings.Colors.primary))
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom)
                .disabled(isSaving || totalShotsAttempted == 0)
            }
            .padding(.vertical)
        }
        .navigationTitle("Basketball Workout")
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertMessage.contains("Success") ? "Success" : "Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if alertMessage.contains("Success") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            )
        }
    }
    
    // Summary section
    private var summarySection: some View {
        VStack(spacing: 16) {
            Text("Shooting Summary")
                .font(.custom(AppSettings.Fonts.title, size: 20))
                .foregroundColor(Color(AppSettings.Colors.text))
            
            HStack(spacing: 40) {
                statItem(title: "Total Attempts", value: "\(totalShotsAttempted)")
                statItem(title: "Made", value: "\(totalShotsMade)")
                statItem(title: "Percentage", value: shootingPercentage)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    // Stats display helper
    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom(AppSettings.Fonts.title, size: 24))
                .foregroundColor(Color(AppSettings.Colors.primary))
            
            Text(title)
                .font(.custom(AppSettings.Fonts.body, size: 14))
                .foregroundColor(.secondary)
        }
    }
    
    // Shot type section
    private func shotTypeSection(title: String, description: String, attempted: Binding<Int>, made: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom(AppSettings.Fonts.title, size: 18))
                    .foregroundColor(Color(AppSettings.Colors.text))
                
                Text(description)
                    .font(.custom(AppSettings.Fonts.body, size: 14))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                // Attempted
                counterInput(
                    title: "Attempted",
                    value: attempted,
                    backgroundColor: Color(UIColor.secondarySystemBackground)
                )
                
                // Made
                counterInput(
                    title: "Made",
                    value: made,
                    backgroundColor: Color(AppSettings.Colors.primary).opacity(0.1),
                    validateValue: { made in
                        // Made shots can't exceed attempted shots
                        return made <= attempted.wrappedValue
                    }
                )
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    // Counter input
    private func counterInput(
        title: String,
        value: Binding<Int>,
        backgroundColor: Color,
        validateValue: ((Int) -> Bool)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom(AppSettings.Fonts.body, size: 14))
                .foregroundColor(.secondary)
            
            HStack {
                Button(action: {
                    if value.wrappedValue > 0 {
                        value.wrappedValue -= 1
                    }
                }) {
                    Image(systemName: "minus")
                        .foregroundColor(Color(AppSettings.Colors.primary))
                }
                
                Spacer()
                
                Text("\(value.wrappedValue)")
                    .font(.custom(AppSettings.Fonts.title, size: 20))
                    .foregroundColor(Color(AppSettings.Colors.text))
                
                Spacer()
                
                Button(action: {
                    let newValue = value.wrappedValue + 1
                    if validateValue?(newValue) ?? true {
                        value.wrappedValue = newValue
                    }
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(Color(AppSettings.Colors.primary))
                }
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func saveWorkout() {
        guard let userId = authManager.currentUser?.id else {
            alertMessage = "Error: You must be logged in to save a workout"
            showingAlert = true
            return
        }
        
        // Validate input
        if totalShotsAttempted == 0 {
            alertMessage = "Please enter at least one shot attempt"
            showingAlert = true
            return
        }
        
        isSaving = true
        
        Task {
            do {
                let workoutId = UUID()
                
                // Create main workout entry
                let workout = Workout(
                    id: workoutId,
                    user_id: userId,
                    workout_date: Date(),
                    workout_type: .basketball,
                    points: calculatePoints(),
                    created_at: Date()
                )
                
                // Create basketball workout details
                struct BasketballWorkoutDetails: Encodable {
                    let workout_id: String
                    let shots_attempted_inside: Int
                    let shots_made_inside: Int
                    let shots_attempted_wing: Int
                    let shots_made_wing: Int
                    let shots_attempted_shoulder: Int
                    let shots_made_shoulder: Int
                    let shots_attempted_corner: Int
                    let shots_made_corner: Int
                    let total_shots_attempted: Int
                    let total_shots_made: Int
                }
                
                let details = BasketballWorkoutDetails(
                    workout_id: workoutId.uuidString,
                    shots_attempted_inside: shotsAttemptedInside,
                    shots_made_inside: shotsMadeInside,
                    shots_attempted_wing: shotsAttemptedWing,
                    shots_made_wing: shotsMadeWing,
                    shots_attempted_shoulder: shotsAttemptedShoulder,
                    shots_made_shoulder: shotsMadeShoulder,
                    shots_attempted_corner: shotsAttemptedCorner,
                    shots_made_corner: shotsMadeCorner,
                    total_shots_attempted: totalShotsAttempted,
                    total_shots_made: totalShotsMade
                )
                
                let workoutService = WorkoutService()
                try await workoutService.saveWorkout(workout: workout)
                try await workoutService.saveBasketballWorkoutDetails(details: details)
                
                // Refresh user profile to update stats
                await authManager.refreshUserProfile()
                
                await MainActor.run {
                    isSaving = false
                    alertMessage = "Success! Your basketball workout has been saved."
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    alertMessage = "Error saving workout: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func calculatePoints() -> Double {
        // Points formula: base points for attempts + bonus for accuracy
        let basePoints = Double(totalShotsAttempted) * 2
        
        // Accuracy bonus
        let accuracyBonus: Double
        if totalShotsAttempted > 0 {
            let accuracy = Double(totalShotsMade) / Double(totalShotsAttempted)
            accuracyBonus = accuracy * 100 // Award up to 100 extra points for perfect shooting
        } else {
            accuracyBonus = 0
        }
        
        // Volume bonus for significant workouts
        let volumeBonus = totalShotsAttempted >= 50 ? 20.0 : 0.0
        
        return basePoints + accuracyBonus + volumeBonus
    }
}

#Preview {
    NavigationView {
        BasketballWorkoutView()
            .environmentObject(AuthenticationManager())
    }
} 