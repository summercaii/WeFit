import SwiftUI

struct FilterType: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
}

struct ChallengesView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedFilter: String = "All"
    @State private var searchText: String = ""
    @State private var showingNewChallengeSheet = false
    @State private var showingLeaderboard = false
    @State private var showingChallengeDetail = false
    @State private var selectedChallengeId: String = ""
    @State private var filterTypes: [FilterType] = [
        FilterType(name: "All", icon: "list.bullet"),
        FilterType(name: "Available", icon: "plus.circle")
    ]
    
    @State private var challengesWithStatus: [ChallengeWithUserStatus] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var loadingTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with Leaderboard button
                headerView
                
                // Challenge type filter
                filterView
                
                // Search bar
                searchBarView
                
                // Challenge list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if isLoading {
                            ProgressView("Loading challenges...")
                                .padding()
                        } else if let errorMessage = errorMessage {
                            ErrorView(message: errorMessage)
                        } else if filteredChallenges.isEmpty {
                            EmptyStateView(
                                imageName: "trophy.fill",
                                title: "No Group Challenges Found",
                                message: searchText.isEmpty ? "Create a group challenge to get started!" : "No group challenges match your search."
                            )
                        } else {
                            ForEach(filteredChallenges) { challengeWithStatus in
                                ChallengeCard(challengeWithStatus: challengeWithStatus) {
                                    selectedChallengeId = challengeWithStatus.challenge.id.uuidString
                                    showingChallengeDetail = true
                                }
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(AppSettings.Colors.background))
                .refreshable {
                    await loadChallenges()
                }
            }
            .navigationTitle("Group Challenges")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingNewChallengeSheet = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(Color(AppSettings.Colors.primary))
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewChallengeSheet) {
            NewChallengeView(isPresented: $showingNewChallengeSheet) {
                await loadChallenges()
            }
            .environmentObject(authManager)
        }
        .sheet(isPresented: $showingLeaderboard) {
            LeaderboardView()
        }
        .sheet(isPresented: $showingChallengeDetail) {
            ChallengeDetailView(challengeId: selectedChallengeId)
                .environmentObject(authManager)
        }
        .task {
            await loadChallenges()
        }
        .onDisappear {
            loadingTask?.cancel()
        }
    }
    
    private var headerView: some View {
        HStack {
            // Text("Group Challenges")
            //     .font(.largeTitle)
            //     .fontWeight(.bold)
            
            Spacer()
            
            Button(action: {
                showingLeaderboard = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                    Text("Leaderboard")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange)
                .cornerRadius(20)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .background(Color(.systemBackground))
    }
    
    private var filterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(filterTypes) { type in
                    FilterButton(
                        title: type.name,
                        icon: type.icon,
                        isSelected: selectedFilter == type.name
                    ) {
                        selectedFilter = type.name
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color.white)
    }
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .padding(.leading, 8)
            
            TextField("Search challenges...", text: $searchText)
                .padding(8)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .padding(.trailing, 8)
            }
        }
        .background(Color.white.opacity(0.1))
        .background(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // Filtered challenges based on selected filter and search text
    private var filteredChallenges: [ChallengeWithUserStatus] {
        var result = challengesWithStatus
        
        // Apply type filter
        switch selectedFilter {
        case "All":
            // Show all challenges
            break
        case "Available":
            result = result.filter { $0.userStatus == .not_joined && !$0.challenge.isExpired }
        default:
            break
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { 
                $0.challenge.title.lowercased().contains(searchText.lowercased()) ||
                ($0.challenge.description?.lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
        
        return result
    }
    
    private func loadChallenges() async {
        // Cancel any existing loading task
        loadingTask?.cancel()
        
        // Create a new task for loading
        loadingTask = Task {
            guard let userId = authManager.currentUser?.id else {
                await setError("User not authenticated")
                return
            }
            
            print("🔍 ChallengesView: Loading challenges for user ID: \(userId.uuidString)")
            
            await setLoading(true)
            
            do {
                let challengeService = ChallengeService()
                let challenges = try await challengeService.fetchChallengesWithUserStatus(userId: userId.uuidString)
                
                print("🔍 ChallengesView: Fetched \(challenges.count) challenges with status")
                for challengeWithStatus in challenges {
                    print("🔍   - \(challengeWithStatus.challenge.title): \(challengeWithStatus.userStatus.rawValue)")
                }
                
                // Check if task was cancelled before updating UI
                guard !Task.isCancelled else {
                    print("⚠️ ChallengesView: Load task was cancelled")
                    return
                }
                
                await MainActor.run {
                    self.challengesWithStatus = challenges
                    self.isLoading = false
                    self.errorMessage = nil
                }
            } catch {
                // Check if task was cancelled
                guard !Task.isCancelled else {
                    print("⚠️ ChallengesView: Load task was cancelled during error handling")
                    return
                }
                
                // Only show error if it's not a cancellation error
                if (error as NSError).code != NSURLErrorCancelled {
                    await setError("Failed to load challenges: \(error.localizedDescription)")
                } else {
                    print("⚠️ ChallengesView: Request was cancelled, ignoring error")
                    await setLoading(false)
                }
            }
        }
        
        await loadingTask?.value
    }
    
    @MainActor
    private func setLoading(_ loading: Bool) {
        isLoading = loading
        if loading {
            errorMessage = nil
        }
    }
    
    @MainActor 
    private func setError(_ message: String) {
        errorMessage = message
        isLoading = false
    }
}

// MARK: - Supporting Views

struct FilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                
                Text(title)
                    .font(.custom(AppSettings.Fonts.body, size: 14))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color(AppSettings.Colors.primary) : Color.clear)
            .foregroundColor(isSelected ? .white : Color.secondary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct ChallengeCard: View {
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
                // Header with status
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: challenge.challengeType.icon)
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(challenge.title)
                                .font(.headline)
                                .fontWeight(.semibold)
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
                
                // Description
                if let description = challenge.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Challenge details
                HStack(spacing: 16) {
                    if let target = challenge.target, !target.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(target)
                                .font(.caption)
                                .foregroundColor(.secondary)
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
            .shadow(radius: 2)
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

struct NewChallengeView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Binding var isPresented: Bool
    let onChallengeCreated: () async -> Void
    @State private var challengeTitle: String = ""
    @State private var challengeDescription: String = ""
    @State private var challengeType: ChallengeType = .group
    @State private var targetGoal: String = ""
    @State private var pointsReward: String = ""
    @State private var duration: Int = 7
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    private let durations = [1, 3, 7, 14, 30]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Challenge Details")) {
                    TextField("Title", text: $challengeTitle)
                    TextField("Description", text: $challengeDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("Goals & Rewards")) {
                    TextField("Target (e.g., 5 kilometers)", text: $targetGoal)
                    TextField("Points Reward", text: $pointsReward)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Duration")) {
                    Picker("Duration", selection: $duration) {
                        ForEach(durations, id: \.self) { days in
                            Text("\(days) \(days == 1 ? "day" : "days")").tag(days)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Group Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task { await createChallenge() }
                    }
                    .disabled(isCreating || !isFormValid)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !challengeTitle.isEmpty && 
        !challengeDescription.isEmpty && 
        !targetGoal.isEmpty && 
        !pointsReward.isEmpty &&
        Int(pointsReward) != nil
    }
    
    private func createChallenge() async {
        guard let pointsInt = Int(pointsReward) else {
            errorMessage = "Points reward must be a valid number"
            return
        }
        
        await MainActor.run {
            self.isCreating = true
            self.errorMessage = nil
        }
        
        do {
            let challengeService = ChallengeService()
            _ = try await challengeService.createChallenge(
                title: challengeTitle,
                description: challengeDescription,
                challengeType: challengeType,
                target: targetGoal,
                pointsReward: pointsInt,
                duration: duration
            )
            
            await onChallengeCreated()
            
            await MainActor.run {
                self.isPresented = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create challenge: \(error.localizedDescription)"
                self.isCreating = false
            }
        }
    }
}

#Preview {
    ChallengesView()
        .environmentObject(AuthenticationManager())
} 