import SwiftUI

struct ChallengeType: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
}

struct ChallengesView: View {
    @State private var selectedFilter: String = "All"
    @State private var searchText: String = ""
    @State private var showingNewChallengeSheet = false
    @State private var challengeTypes: [ChallengeType] = [
        ChallengeType(name: "All", icon: "list.bullet"),
        ChallengeType(name: "Personal", icon: "person.fill"),
        ChallengeType(name: "Group", icon: "person.3.fill"),
        ChallengeType(name: "Points", icon: "star.fill")
    ]
    
    @State private var challenges: [Challenge] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Challenge type filter
                filterView
                
                // Search bar
                searchBarView
                
                // Challenge list
                ScrollView {
                    VStack(spacing: 16) {
                        if filteredChallenges.isEmpty {
                            EmptyStateView(
                                imageName: "trophy.fill",
                                title: "No Active Challenges",
                                message: "Join a challenge to compete with others and earn points!"
                            )
                        } else {
                            ForEach(filteredChallenges) { challenge in
                                ChallengeCard(challenge: challenge)
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(AppSettings.Colors.background))
            }
            .navigationTitle("Challenges")
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
            .sheet(isPresented: $showingNewChallengeSheet) {
                NewChallengeView(isPresented: $showingNewChallengeSheet)
            }
            .onAppear {
                // Load sample challenges
                loadSampleChallenges()
            }
        }
    }
    
    private var filterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(challengeTypes) { type in
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
    private var filteredChallenges: [Challenge] {
        var result = challenges
        
        // Apply type filter
        if selectedFilter != "All" {
            result = result.filter { $0.challengeType.lowercased() == selectedFilter.lowercased() }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { 
                $0.title.lowercased().contains(searchText.lowercased()) ||
                $0.description.lowercased().contains(searchText.lowercased())
            }
        }
        
        return result
    }
    
    private func loadSampleChallenges() {
        let now = Date()
        let calendar = Calendar.current
        
        // Sample challenges data
        challenges = [
            Challenge(
                id: UUID(), 
                title: "5K Run Challenge", 
                description: "Complete a 5K run in less than 30 minutes", 
                challengeType: "Personal", 
                target: "5 kilometers", 
                pointsReward: 300, 
                startDate: now, 
                endDate: calendar.date(byAdding: .day, value: 7, to: now)!
            ),
            Challenge(
                id: UUID(), 
                title: "Weekly Group Run", 
                description: "Run with your team this week", 
                challengeType: "Group", 
                target: "10 kilometers total", 
                pointsReward: 500, 
                startDate: now, 
                endDate: calendar.date(byAdding: .day, value: 7, to: now)!
            ),
            Challenge(
                id: UUID(), 
                title: "30-Day Strength Challenge", 
                description: "Complete daily strength exercises for 30 days", 
                challengeType: "Personal", 
                target: "30 days streak", 
                pointsReward: 1000, 
                startDate: now, 
                endDate: calendar.date(byAdding: .day, value: 30, to: now)!
            )
        ]
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

struct NewChallengeView: View {
    @Binding var isPresented: Bool
    @State private var challengeTitle: String = ""
    @State private var challengeDescription: String = ""
    @State private var challengeType: String = "Personal"
    @State private var targetGoal: String = ""
    @State private var pointsReward: String = ""
    @State private var duration: Int = 7
    
    private let challengeTypes = ["Personal", "Group"]
    private let durations = [1, 3, 7, 14, 30]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Challenge Details")) {
                    TextField("Title", text: $challengeTitle)
                    TextField("Description", text: $challengeDescription)
                }
                
                Section(header: Text("Challenge Type")) {
                    Picker("Type", selection: $challengeType) {
                        ForEach(challengeTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
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
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                if challengeType == "Group" {
                    Section(header: Text("Invite Friends")) {
                        Button("Select Friends to Invite") {
                            // Friend selection action
                        }
                    }
                }
            }
            .navigationTitle("New Challenge")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Create") {
                    // Create challenge action
                    isPresented = false
                }
                .disabled(challengeTitle.isEmpty || challengeDescription.isEmpty || targetGoal.isEmpty || pointsReward.isEmpty)
            )
        }
    }
}

#Preview {
    ChallengesView()
} 