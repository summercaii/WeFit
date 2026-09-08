import SwiftUI

struct Challenge: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let challengeType: String
    let target: String
    let pointsReward: Int
    let startDate: Date
    let endDate: Date
}

struct ChallengesListView: View {
    @State private var challenges: [Challenge] = []
    
    var body: some View {
        VStack(spacing: 16) {
            if challenges.isEmpty {
                EmptyStateView(
                    imageName: "trophy.fill",
                    title: "No Active Challenges",
                    message: "Join a challenge to compete with others and earn points!"
                )
            } else {
                ForEach(challenges) { challenge in
                    ChallengeCard(challenge: challenge)
                }
            }
        }
        .padding()
    }
}

struct ChallengeCard: View {
    let challenge: Challenge
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(challenge.title)
                    .font(.headline)
                Spacer()
                Text("\(challenge.pointsReward) pts")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            
            Text(challenge.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text(challenge.challengeType)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                
                Spacer()
                
                Text("\(challenge.endDate.formatted(.dateTime.month().day()))")
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