import SwiftUI

struct WorkoutSelectionView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Choose Your Workout")
                    .font(.custom(AppSettings.Fonts.title, size: 24))
                    .padding(.top)
                
                // Workout types
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(WorkoutType.allCases, id: \.self) { workoutType in
                            navigationLinkForWorkoutType(workoutType)
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitle("New Workout", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    @ViewBuilder
    private func navigationLinkForWorkoutType(_ workoutType: WorkoutType) -> some View {
        switch workoutType {
        case .running:
            NavigationLink(destination: RunningWorkoutView().environmentObject(authManager)) {
                workoutTypeCard(
                    title: "Running",
                    description: "Track your time, distance, and pace",
                    icon: "figure.run",
                    color: .blue
                )
            }
            
        case .weightlifting:
            NavigationLink(destination: WeightliftingWorkoutView().environmentObject(authManager)) {
                workoutTypeCard(
                    title: "Weightlifting",
                    description: "Log sets, reps, and weight for each exercise",
                    icon: "figure.strengthtraining.traditional",
                    color: .orange
                )
            }
            
        case .basketball:
            NavigationLink(destination: BasketballWorkoutView().environmentObject(authManager)) {
                workoutTypeCard(
                    title: "Basketball",
                    description: "Track shots and shooting percentages",
                    icon: "basketball.fill",
                    color: .red
                )
            }
        }
    }
    
    private func workoutTypeCard(title: String, description: String, icon: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)
                .frame(width: 60, height: 60)
                .background(color.opacity(0.1))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom(AppSettings.Fonts.title, size: 18))
                    .foregroundColor(Color(AppSettings.Colors.text))
                
                Text(description)
                    .font(.custom(AppSettings.Fonts.body, size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    WorkoutSelectionView()
        .environmentObject(AuthenticationManager())
} 