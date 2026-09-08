import SwiftUI

struct RunningWorkoutView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var hours: Int = 0
    @State private var minutes: Int = 30
    @State private var seconds: Int = 0
    @State private var distance: Double = 5.0
    @State private var splits: Double = 0.0
    @State private var isSaving = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Form content
                VStack(alignment: .leading, spacing: 24) {
                    // Duration section
                    formSection(title: "Duration") {
                        HStack(spacing: 10) {
                            // Hours
                            timePickerField(value: $hours, range: 0...24, label: "hr")
                            
                            Text(":")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            // Minutes
                            timePickerField(value: $minutes, range: 0...59, label: "min")
                            
                            Text(":")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            // Seconds
                            timePickerField(value: $seconds, range: 0...59, label: "sec")
                        }
                    }
                    
                    // Distance section
                    formSection(title: "Distance (km)") {
                        HStack {
                            TextField("", value: $distance, format: .number)
                                .keyboardType(.decimalPad)
                                .font(.custom(AppSettings.Fonts.body, size: 18))
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                        }
                    }
                    
                    // Average pace section (auto-calculated)
                    formSection(title: "Average Pace (min/km)") {
                        Text(calculatePace())
                            .font(.custom(AppSettings.Fonts.body, size: 18))
                            .foregroundColor(Color(AppSettings.Colors.text))
                    }
                    
                    // Splits section
                    formSection(title: "Number of Splits") {
                        HStack {
                            TextField("Optional", value: $splits, format: .number)
                                .keyboardType(.decimalPad)
                                .font(.custom(AppSettings.Fonts.body, size: 18))
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                        }
                    }
                }
                .padding()
                
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
                .disabled(isSaving)
            }
        }
        .navigationTitle("Running Workout")
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
    
    private func timePickerField(value: Binding<Int>, range: ClosedRange<Int>, label: String) -> some View {
        VStack {
            Picker("", selection: value) {
                ForEach(range, id: \.self) { val in
                    Text("\(val)").tag(val)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(width: 60, height: 100)
            .clipped()
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom(AppSettings.Fonts.title, size: 16))
                .foregroundColor(Color(AppSettings.Colors.text))
            
            content()
        }
    }
    
    private func calculatePace() -> String {
        let totalMinutes = hours * 60 + minutes + seconds / 60
        
        if distance <= 0 || totalMinutes <= 0 {
            return "0:00"
        }
        
        let paceInMinutes = Double(totalMinutes) / distance
        let paceMinutes = Int(paceInMinutes)
        let paceSeconds = Int((paceInMinutes - Double(paceMinutes)) * 60)
        
        return "\(paceMinutes):\(String(format: "%02d", paceSeconds))"
    }
    
    private func saveWorkout() {
        guard let userId = authManager.currentUser?.id else {
            alertMessage = "Error: You must be logged in to save a workout"
            showingAlert = true
            return
        }
        
        // Validate input
        if hours == 0 && minutes == 0 && seconds == 0 {
            alertMessage = "Please enter a workout duration"
            showingAlert = true
            return
        }
        
        if distance <= 0 {
            alertMessage = "Please enter a valid distance"
            showingAlert = true
            return
        }
        
        isSaving = true
        
        let totalDurationSeconds = (hours * 3600) + (minutes * 60) + seconds
        
        Task {
            do {
                let workoutId = UUID()
                
                // Create main workout entry
                let workout = Workout(
                    id: workoutId,
                    user_id: userId,
                    workout_date: Date(),
                    workout_type: .running,
                    points: calculatePoints(),
                    created_at: Date()
                )
                
                // Create running workout details
                struct RunningWorkoutDetails: Encodable {
                    let workout_id: String
                    let duration: Int
                    let distance: Double
                    let splits: [Double]?  // Changed to array - might be split times per km
                }
                
                // Convert splits to array if we have splits data
                var splitsArray: [Double]? = nil
                if splits > 0 {
                    // Create dummy split times based on number of splits
                    // In reality, you'd want to track actual split times
                    let avgPaceSeconds = Double(totalDurationSeconds) / distance
                    splitsArray = Array(repeating: avgPaceSeconds, count: Int(splits))
                }
                
                let details = RunningWorkoutDetails(
                    workout_id: workoutId.uuidString,
                    duration: totalDurationSeconds,
                    distance: distance,
                    splits: splitsArray
                )
                
                print("🏃 Saving running workout with ID: \(workoutId.uuidString)")
                print("📊 Details: duration=\(totalDurationSeconds)s, distance=\(distance)km, splits=\(String(describing: splitsArray))")
                
                let workoutService = WorkoutService()
                
                // Save main workout first
                print("💾 Saving main workout...")
                try await workoutService.saveWorkout(workout: workout)
                print("✅ Main workout saved successfully!")
                
                // Save running details
                print("💾 Saving running details...")
                try await workoutService.saveRunningWorkoutDetails(details: details)
                print("✅ Running details saved successfully!")
                
                // Refresh user profile to update stats
                await authManager.refreshUserProfile()
                
                await MainActor.run {
                    isSaving = false
                    alertMessage = "Success! Your running workout has been saved."
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
        // Points formula: 10 points per km, bonus for speed
        let basePoints = distance * 10
        
        // Pace bonus: faster pace gets more points
        let totalMinutes = Double(hours * 60 + minutes) + Double(seconds) / 60
        let paceMinPerKm = totalMinutes / distance
        
        // Bonus points for faster pace (< 5:00 min/km)
        var paceBonus = 0.0
        if paceMinPerKm < 5 {
            paceBonus = (5 - paceMinPerKm) * 20
        }
        
        return basePoints + paceBonus
    }
}

#Preview {
    NavigationView {
        RunningWorkoutView()
            .environmentObject(AuthenticationManager())
    }
} 