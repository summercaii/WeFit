import SwiftUI

struct ChallengesListView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var userChallenges: [ChallengeWithUserStatus] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingChallengeDetail = false
    @State private var selectedChallengeId: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView("Loading your challenges...")
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if let errorMessage = errorMessage {
                ErrorView(message: errorMessage)
            } else if userChallenges.isEmpty {
                EmptyStateView(
                    imageName: "trophy.fill",
                    title: "No Active Challenges",
                    message: "Join a challenge to compete with others and earn points!"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(userChallenges) { challengeWithStatus in
                        UserChallengeCard(challengeWithStatus: challengeWithStatus) {
                            selectedChallengeId = challengeWithStatus.challenge.id.uuidString
                            showingChallengeDetail = true
                        }
                    }
                }
            }
        }
        .padding()
        .task {
            await loadUserChallenges()
        }
        .refreshable {
            await loadUserChallenges()
        }
        .sheet(isPresented: $showingChallengeDetail) {
            ChallengeDetailView(challengeId: selectedChallengeId)
                .environmentObject(authManager)
        }
    }
    
    private func loadUserChallenges() async {
        guard let userId = authManager.currentUser?.id else {
            await MainActor.run {
                self.errorMessage = "User not authenticated"
                self.isLoading = false
            }
            return
        }
        
        print("🔍 ChallengesListView: Loading challenges for user ID: \(userId.uuidString)")
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let challengeService = ChallengeService()
            let allChallenges = try await challengeService.fetchChallengesWithUserStatus(userId: userId.uuidString)
            
            print("🔍 ChallengesListView: Fetched \(allChallenges.count) challenges with status")
            for challengeWithStatus in allChallenges {
                print("🔍   - \(challengeWithStatus.challenge.title): \(challengeWithStatus.userStatus.rawValue)")
            }
            
            // Filter to only show challenges the user has joined
            let filteredChallenges = allChallenges.filter { challengeWithStatus in
                switch challengeWithStatus.userStatus {
                case .joined, .active, .in_progress, .completed:
                    return true
                case .not_joined, .expired:
                    return false
                }
            }
            
            print("🔍 ChallengesListView: After filtering, showing \(filteredChallenges.count) challenges")
            for challengeWithStatus in filteredChallenges {
                print("🔍   - \(challengeWithStatus.challenge.title): \(challengeWithStatus.userStatus.rawValue)")
            }
            
            await MainActor.run {
                self.userChallenges = filteredChallenges
                self.isLoading = false
            }
        } catch {
            print("❌ ChallengesListView: Error loading challenges: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Failed to load challenges: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

struct UserChallengeCard: View {
    let challengeWithStatus: ChallengeWithUserStatus
    let onTap: () -> Void
    
    var challenge: Challenge {
        challengeWithStatus.challenge
    }
    
    var userStatus: ChallengeStatus {
        challengeWithStatus.userStatus
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: challenge.challengeType.icon)
                            .font(.title3)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(challenge.title)
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            
                            Text(challenge.challengeType.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Status Badge
                    Text(userStatus.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(statusTextColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusBackgroundColor)
                        .cornerRadius(8)
                }
                
                // Target and Points
                HStack {
                    if let target = challenge.target, !target.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(target)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("\(challenge.pointsReward) pts")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
                
                // Timeline
                HStack {
                    if challenge.daysRemaining > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("\(challenge.daysRemaining) days left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if challenge.isExpired {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text("Expired")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } else if userStatus == .completed {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("Completed")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                    
                    Text(challenge.formattedEndDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusTextColor: Color {
        switch userStatus {
        case .active, .joined, .in_progress:
            return .blue
        case .completed:
            return .green
        case .expired:
            return .red
        case .not_joined:
            return .gray
        }
    }
    
    private var statusBackgroundColor: Color {
        statusTextColor.opacity(0.15)
    }
}

#Preview {
    ChallengesListView()
        .environmentObject(AuthenticationManager())
} 