import SwiftUI

struct Exercise: Identifiable {
    let id = UUID()
    var name: String = ""
    var sets: Int = 3
    var reps: Int = 10
    var weight: Double = 0.0
    
    var isValid: Bool {
        !name.isEmpty && sets > 0 && reps > 0
    }
    
    var displayText: String {
        "\(name): \(sets) sets × \(reps) reps @ \(weight > 0 ? String(format: "%.1f", weight) : "-") kg"
    }
}

struct WeightliftingWorkoutView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var workoutName: String = ""
    @State private var exercises: [Exercise] = [Exercise()]
    @State private var isSaving = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Workout name
                VStack(alignment: .leading, spacing: 10) {
                    Text("Workout Name")
                        .font(.custom(AppSettings.Fonts.title, size: 16))
                        .foregroundColor(Color(AppSettings.Colors.text))
                    
                    TextField("e.g., Upper Body, Leg Day, etc.", text: $workoutName)
                        .font(.custom(AppSettings.Fonts.body, size: 16))
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Exercises
                VStack(alignment: .leading, spacing: 10) {
                    Text("Exercises")
                        .font(.custom(AppSettings.Fonts.title, size: 20))
                        .foregroundColor(Color(AppSettings.Colors.text))
                        .padding(.horizontal)
                    
                    ForEach(exercises.indices, id: \.self) { index in
                        exerciseView(index: index)
                    }
                    
                    // Add exercise button
                    Button(action: addExercise) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Exercise")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(Color(AppSettings.Colors.primary))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(AppSettings.Colors.primary), lineWidth: 2)
                                .background(Color(AppSettings.Colors.primary).opacity(0.05))
                        )
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                // Summary
                if !exercises.isEmpty {
                    workoutSummary
                }
                
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
                .disabled(isSaving || !isWorkoutValid)
            }
            .padding(.vertical)
        }
        .navigationTitle("Weightlifting Workout")
        .navigationBarBackButtonHidden(false)
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
    
    private var isWorkoutValid: Bool {
        !workoutName.isEmpty && !exercises.isEmpty && exercises.allSatisfy { $0.isValid }
    }
    
    private var workoutSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Summary")
                .font(.custom(AppSettings.Fonts.title, size: 16))
                .foregroundColor(Color(AppSettings.Colors.text))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Total Sets:")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(exercises.reduce(0) { $0 + $1.sets })")
                        .foregroundColor(Color(AppSettings.Colors.text))
                }
                
                Divider()
                
                HStack {
                    Text("Total Exercises:")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(exercises.count)")
                        .foregroundColor(Color(AppSettings.Colors.text))
                }
                
                Divider()
                
                HStack {
                    Text("Estimated Points:")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(calculatePoints()))")
                        .foregroundColor(Color(AppSettings.Colors.primary))
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private func exerciseView(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Exercise \(index + 1)")
                    .font(.custom(AppSettings.Fonts.title, size: 16))
                    .foregroundColor(Color(AppSettings.Colors.text))
                
                Spacer()
                
                if exercises.count > 1 {
                    Button(action: {
                        removeExercise(at: index)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Exercise name
            TextField("Exercise Name", text: $exercises[index].name)
                .font(.custom(AppSettings.Fonts.body, size: 16))
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            
            // Sets, reps, weight
            HStack(spacing: 12) {
                // Sets
                numberField(
                    title: "Sets",
                    value: $exercises[index].sets,
                    range: 1...10
                )
                
                // Reps
                numberField(
                    title: "Reps",
                    value: $exercises[index].reps,
                    range: 1...100
                )
                
                // Weight (kg)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weight (kg)")
                        .font(.custom(AppSettings.Fonts.body, size: 14))
                        .foregroundColor(.secondary)
                    
                    TextField("Optional", value: $exercises[index].weight, format: .number)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private func numberField(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom(AppSettings.Fonts.body, size: 14))
                .foregroundColor(.secondary)
            
            HStack {
                Button(action: {
                    if value.wrappedValue > range.lowerBound {
                        value.wrappedValue -= 1
                    }
                }) {
                    Image(systemName: "minus")
                        .foregroundColor(Color(AppSettings.Colors.primary))
                }
                
                Spacer()
                
                Text("\(value.wrappedValue)")
                    .font(.custom(AppSettings.Fonts.body, size: 16))
                
                Spacer()
                
                Button(action: {
                    if value.wrappedValue < range.upperBound {
                        value.wrappedValue += 1
                    }
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(Color(AppSettings.Colors.primary))
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
    
    private func addExercise() {
        withAnimation {
            exercises.append(Exercise())
        }
    }
    
    private func removeExercise(at index: Int) {
        withAnimation {
            exercises.remove(at: index)
        }
    }
    
    private func saveWorkout() {
        guard let userId = authManager.currentUser?.id else {
            alertMessage = "Error: You must be logged in to save a workout"
            showingAlert = true
            return
        }
        
        // Validate input
        if workoutName.isEmpty {
            alertMessage = "Please enter a workout name"
            showingAlert = true
            return
        }
        
        if exercises.isEmpty {
            alertMessage = "Please add at least one exercise"
            showingAlert = true
            return
        }
        
        if !exercises.allSatisfy({ $0.isValid }) {
            alertMessage = "Please fill in all exercise details"
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
                    workout_type: .weightlifting,
                    points: calculatePoints(),
                    created_at: Date()
                )
                
                // Create weightlifting workout details
                struct WeightliftingWorkoutDetails: Encodable {
                    let workout_id: String
                    let workout_name: String
                    let sets: Int
                    let reps: [Int]     // Array of reps for each exercise
                    let weight: [Double] // Array of weights for each exercise
                }
                
                // Create arrays for reps and weights for each exercise
                let repsArray = exercises.map { $0.reps }
                let weightsArray = exercises.map { $0.weight }
                let totalSets = exercises.reduce(0) { $0 + $1.sets }
                
                let details = WeightliftingWorkoutDetails(
                    workout_id: workoutId.uuidString,
                    workout_name: workoutName,
                    sets: totalSets,
                    reps: repsArray,
                    weight: weightsArray
                )
                
                print("🏋️ Saving workout with ID: \(workoutId.uuidString)")
                print("📊 Details: sets=\(totalSets), reps=\(repsArray), weights=\(weightsArray)")
                
                // Save all the info
                let workoutService = WorkoutService()
                
                // Save main workout first
                print("💾 Saving main workout...")
                try await workoutService.saveWorkout(workout: workout)
                print("✅ Main workout saved successfully!")
                
                // Save weightlifting details
                print("💾 Saving weightlifting details...")
                try await workoutService.saveWeightliftingWorkoutDetails(details: details)
                print("✅ Weightlifting details saved successfully!")
                
                // Refresh user profile to update stats
                await authManager.refreshUserProfile()
                
                await MainActor.run {
                    isSaving = false
                    alertMessage = "Success! Your weightlifting workout has been saved."
                    showingAlert = true
                }
            } catch {
                print("❌ Error saving workout: \(error)")
                print("❌ Error type: \(type(of: error))")
                if let nsError = error as NSError? {
                    print("❌ NSError domain: \(nsError.domain)")
                    print("❌ NSError code: \(nsError.code)")
                    print("❌ NSError userInfo: \(nsError.userInfo)")
                }
                await MainActor.run {
                    isSaving = false
                    alertMessage = "Error saving workout: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func calculatePoints() -> Double {
        // Points formula based on volume (sets × reps × weight)
        var totalPoints = 0.0
        
        for exercise in exercises {
            let exerciseVolume = Double(exercise.sets * exercise.reps) * max(1.0, exercise.weight)
            
            // Points scaled by volume
            let exercisePoints = exerciseVolume * 0.1
            
            totalPoints += exercisePoints
        }
        
        // Additional points for multiple exercises
        let exerciseCountBonus = Double(exercises.count - 1) * 5
        
        return max(20, totalPoints + exerciseCountBonus) // Minimum 20 points for completing a workout
    }
}

#Preview {
    NavigationView {
        WeightliftingWorkoutView()
            .environmentObject(AuthenticationManager())
    }
} 