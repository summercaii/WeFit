import SwiftUI

struct ChallengeDetailView: View {
    let challengeId: String
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var challengeWithStatus: ChallengeWithUserStatus?
    @State private var participants: [LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingJoinConfirmation = false
    @State private var showingCompleteConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Loading challenge details...")
                            .padding()
                    } else if let errorMessage = errorMessage {
                        ErrorView(message: errorMessage)
                    } else if let challengeWithStatus = challengeWithStatus {
                        ChallengeDetailContent(challengeWithStatus: challengeWithStatus, participants: participants)
                    }
                }
                .padding()
            }
            .navigationTitle("Challenge Details")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let challengeWithStatus = challengeWithStatus {
                    actionButtonView(for: challengeWithStatus)
                }
            }
        }
        .task {
            await loadChallengeDetails()
        }
        .alert("Join Challenge", isPresented: $showingJoinConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Join") {
                Task { await joinChallenge() }
            }
        } message: {
            Text("Are you sure you want to join this challenge?")
        }
        .alert("Complete Challenge", isPresented: $showingCompleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Complete") {
                Task { await completeChallenge() }
            }
        } message: {
            Text("Mark this challenge as completed?")
        }
    }
    
    private func actionButtonView(for challengeWithStatus: ChallengeWithUserStatus) -> some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 16) {
                switch challengeWithStatus.userStatus {
                case .not_joined:
                    if !challengeWithStatus.challenge.isExpired {
                        Button(action: {
                            showingJoinConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Join Challenge")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                case .joined, .active, .in_progress:
                    Button(action: {
                        showingCompleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Mark Complete")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                case .completed:
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Completed")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.3))
                    .foregroundColor(.green)
                    .cornerRadius(12)
                case .expired:
                    HStack {
                        Image(systemName: "clock.fill")
                        Text("Expired")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.3))
                    .foregroundColor(.red)
                    .cornerRadius(12)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    private func loadChallengeDetails() async {
        guard let userId = authManager.currentUser?.id else {
            await MainActor.run {
                self.errorMessage = "User not authenticated"
                self.isLoading = false
            }
            return
        }
        
        do {
            let challengeService = ChallengeService()
            let challengesWithStatus = try await challengeService.fetchChallengesWithUserStatus(userId: userId.uuidString)
            let challengeWithStatus = challengesWithStatus.first { $0.challenge.id.uuidString == challengeId }
            
            await MainActor.run {
                self.challengeWithStatus = challengeWithStatus
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load challenge details: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func joinChallenge() async {
        guard let userId = authManager.currentUser?.id else { return }
        
        do {
            let challengeService = ChallengeService()
            try await challengeService.joinChallenge(challengeId: challengeId, userId: userId.uuidString)
            
            // Reload challenge details to refresh status
            await loadChallengeDetails()
        } catch {
            // Always reload challenge details to refresh status, even on error
            await loadChallengeDetails()
            
            await MainActor.run {
                self.errorMessage = "Failed to join challenge: \(error.localizedDescription)"
            }
        }
    }
    
    private func completeChallenge() async {
        guard let userId = authManager.currentUser?.id else { return }
        
        do {
            let challengeService = ChallengeService()
            try await challengeService.completeChallenge(challengeId: challengeId, userId: userId.uuidString)
            
            // Reload challenge details
            await loadChallengeDetails()
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to complete challenge: \(error.localizedDescription)"
            }
        }
    }
}

struct ChallengeDetailContent: View {
    let challengeWithStatus: ChallengeWithUserStatus
    let participants: [LeaderboardEntry]
    
    var challenge: Challenge {
        challengeWithStatus.challenge
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header Section
            ChallengeHeaderSection(challenge: challenge, userStatus: challengeWithStatus.userStatus)
            
            // Description Section
            if let description = challenge.description, !description.isEmpty {
                ChallengeDescriptionSection(description: description)
            }
            
            // Details Section
            ChallengeDetailsSection(challenge: challenge)
            
            // Status Section
            ChallengeStatusSection(challenge: challenge, userStatus: challengeWithStatus.userStatus)
            
            // Participants Section (if group challenge)
            if challenge.challengeType == .group {
                ChallengeParticipantsSection(participants: participants)
            }
        }
    }
}

// MARK: - Challenge Detail Sections

struct ChallengeHeaderSection: View {
    let challenge: Challenge
    let userStatus: ChallengeStatus
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: challenge.challengeType.icon)
                    .font(.system(size: 40))
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading) {
                    Text(challenge.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(challenge.challengeType.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text("\(challenge.pointsReward)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Status Badge
            HStack {
                Image(systemName: statusIcon(for: userStatus))
                Text(userStatus.displayName)
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(statusColor(for: userStatus))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusColor(for: userStatus).opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func statusIcon(for status: ChallengeStatus) -> String {
        switch status {
        case .active, .joined, .in_progress:
            return "play.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .expired:
            return "clock.fill"
        case .not_joined:
            return "circle"
        }
    }
    
    private func statusColor(for status: ChallengeStatus) -> Color {
        switch status {
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
}

struct ChallengeDescriptionSection: View {
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct ChallengeDetailsSection: View {
    let challenge: Challenge
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Challenge Details")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                if let target = challenge.target, !target.isEmpty {
                    DetailRow(title: "Target", value: target, icon: "target")
                }
                
                DetailRow(title: "Reward", value: "\(challenge.pointsReward) points", icon: "star.fill")
                
                if let endDate = challenge.end_date {
                    DetailRow(title: "Deadline", value: challenge.formattedEndDate, icon: "calendar")
                    
                    if challenge.daysRemaining > 0 {
                        DetailRow(title: "Days Remaining", value: "\(challenge.daysRemaining)", icon: "clock")
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct ChallengeStatusSection: View {
    let challenge: Challenge
    let userStatus: ChallengeStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Status")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(userStatus.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                if challenge.isExpired {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("This challenge has expired")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct ChallengeParticipantsSection: View {
    let participants: [LeaderboardEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Participants")
                .font(.headline)
                .foregroundColor(.primary)
            
            if participants.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.3")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("No participants yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Be the first to join this challenge!")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(participants) { participant in
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(participant.username)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("\(participant.formattedPoints) points")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    ChallengeDetailView(challengeId: "sample-id")
        .environmentObject(AuthenticationManager())
} 