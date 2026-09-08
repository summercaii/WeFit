import SwiftUI

struct LeaderboardView: View {
    @State private var leaderboard: [LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedPeriod = "All Time"
    
    private let periods = ["All Time", "This Month", "This Week"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Period Selector
                periodSelectorView
                
                // Challenge Points Header
                VStack(spacing: 8) {
                    Text("Challenge Leaderboard")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Rankings based on Group Challenge points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Leaderboard Content
                if isLoading {
                    Spacer()
                    ProgressView("Loading leaderboard...")
                    Spacer()
                } else if let errorMessage = errorMessage {
                    Spacer()
                    ErrorView(message: errorMessage)
                    Spacer()
                } else if leaderboard.isEmpty {
                    Spacer()
                    EmptyLeaderboardView()
                    Spacer()
                } else {
                    leaderboardContent
                }
            }
            .navigationTitle("Challenge Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
        }
        .task {
            await loadLeaderboard()
        }
        .refreshable {
            await loadLeaderboard()
        }
    }
    
    private var periodSelectorView: some View {
        VStack(spacing: 0) {
            Picker("Period", selection: $selectedPeriod) {
                ForEach(periods, id: \.self) { period in
                    Text(period).tag(period)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
        }
    }
    
    private var leaderboardContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Top 3 Podium
                if leaderboard.count >= 3 {
                    PodiumView(topThree: Array(leaderboard.prefix(3)))
                        .padding(.top)
                }
                
                // Full Rankings
                VStack(spacing: 12) {
                    Text("Full Rankings")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    ForEach(Array(leaderboard.enumerated()), id: \.element.id) { index, entry in
                        LeaderboardRowView(entry: entry, rank: index + 1)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }
    
    private func loadLeaderboard() async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let challengeService = ChallengeService()
            let entries = try await challengeService.fetchLeaderboard(limit: 50)
            
            await MainActor.run {
                self.leaderboard = entries
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load leaderboard: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

// MARK: - Podium View

struct PodiumView: View {
    let topThree: [LeaderboardEntry]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🏆 Top Performers")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack(alignment: .bottom, spacing: 16) {
                // Second Place
                if topThree.count > 1 {
                    PodiumPositionView(
                        entry: topThree[1],
                        position: 2,
                        height: 80,
                        color: .gray
                    )
                }
                
                // First Place
                PodiumPositionView(
                    entry: topThree[0],
                    position: 1,
                    height: 100,
                    color: .yellow
                )
                
                // Third Place
                if topThree.count > 2 {
                    PodiumPositionView(
                        entry: topThree[2],
                        position: 3,
                        height: 60,
                        color: .orange
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 4)
        .padding(.horizontal)
    }
}

struct PodiumPositionView: View {
    let entry: LeaderboardEntry
    let position: Int
    let height: CGFloat
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            // User Avatar and Info
            VStack(spacing: 8) {
                // Medal/Crown Icon
                Group {
                    if position == 1 {
                        Image(systemName: "crown.fill")
                            .font(.title)
                            .foregroundColor(.yellow)
                    } else {
                        Image(systemName: "medal.fill")
                            .font(.title)
                            .foregroundColor(color)
                    }
                }
                
                // User Avatar
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                // Username
                Text(entry.username)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                // Points
                Text("\(entry.formattedPoints)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            
            // Podium Base
            Rectangle()
                .fill(color.opacity(0.3))
                .frame(height: height)
                .cornerRadius(8, corners: [.topLeft, .topRight])
                .overlay(
                    Text("\(position)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                )
        }
        .frame(width: 80)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    let rank: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Text("\(rank)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(rankColor)
            }
            
            // User Info
            HStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.username)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text("\(entry.completed_challenges) challenges completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Points
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.formattedPoints)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("challenge pts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1:
            return .yellow
        case 2:
            return .gray
        case 3:
            return .orange
        default:
            return .blue
        }
    }
}

// MARK: - Empty State

struct EmptyLeaderboardView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Rankings Yet")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Complete challenges to appear on the leaderboard!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                // Navigate to challenges or refresh
            }) {
                Text("View Challenges")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

#Preview {
    LeaderboardView()
} 