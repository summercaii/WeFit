import SwiftUI

struct Post: Identifiable {
    let id = UUID()
    let user: User
    let content: String
    let image: String? // Image name for demo purposes
    let timestamp: Date
    let workoutType: WorkoutType?
    let challengeId: UUID?
    var likes: Int
    var comments: [Comment]
}

struct Comment: Identifiable {
    let id = UUID()
    let user: User
    let content: String
    let timestamp: Date
}

struct SocialView: View {
    @State private var posts: [Post] = []
    @State private var selectedTab = 0
    @State private var showingNewPostSheet = false
    @State private var postText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Feed type tabs
                feedTabs
                
                // Post list
                ScrollView {
                    VStack(spacing: 16) {
                        if posts.isEmpty {
                            EmptyStateView(
                                imageName: "person.2.fill",
                                title: "Your Feed is Empty",
                                message: "Connect with friends to see their activities and challenges!"
                            )
                        } else {
                            ForEach(filteredPosts) { post in
                                PostCard(post: post)
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(AppSettings.Colors.background))
            }
            .navigationTitle("Community")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingNewPostSheet = true
                    }) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(Color(AppSettings.Colors.primary))
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: FindPartnersView()) {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(Color(AppSettings.Colors.primary))
                    }
                }
            }
            .sheet(isPresented: $showingNewPostSheet) {
                NewPostView(isPresented: $showingNewPostSheet, onPost: { post in
                    // Add new post to feed
                    posts.insert(post, at: 0)
                })
            }
            .onAppear {
                // Load sample posts
                loadSamplePosts()
            }
        }
    }
    
    private var feedTabs: some View {
        HStack(spacing: 0) {
            FeedTabButton(title: "All", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            
            FeedTabButton(title: "Friends", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            
            FeedTabButton(title: "Challenges", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
        }
        .padding(.vertical, 8)
        .background(Color.white)
    }
    
    private var filteredPosts: [Post] {
        switch selectedTab {
        case 1:
            // Friends tab - could filter by friends in a real app
            return posts
        case 2:
            // Challenges tab - filter posts related to challenges
            return posts.filter { $0.challengeId != nil }
        default:
            // All posts
            return posts
        }
    }
    
    private func loadSamplePosts() {
        // Sample users
        let user1 = User(id: UUID(), username: "Emma", email: "emma@example.com", created_at: Date(), totalWorkouts: 45, completedChallenges: 12, totalPoints: 3250)
        let user2 = User(id: UUID(), username: "Michael", email: "michael@example.com", created_at: Date(), totalWorkouts: 32, completedChallenges: 8, totalPoints: 2800)
        let user3 = User(id: UUID(), username: "Sophia", email: "sophia@example.com", created_at: Date(), totalWorkouts: 22, completedChallenges: 5, totalPoints: 1500)
        
        // Sample posts
        posts = [
            Post(
                user: user2,
                content: "Just completed my morning 5K run! Feeling great and ready for the day. Who's up for a challenge this weekend?",
                image: nil,
                timestamp: Date().addingTimeInterval(-3600),
                workoutType: .running,
                challengeId: nil,
                likes: 12,
                comments: [
                    Comment(user: user3, content: "Great job! I'll join you this weekend.", timestamp: Date().addingTimeInterval(-1800))
                ]
            ),
            Post(
                user: user3,
                content: "Joined the 30-day strength challenge! Who else is in?",
                image: nil,
                timestamp: Date().addingTimeInterval(-86400),
                workoutType: .weightlifting,
                challengeId: UUID(),
                likes: 8,
                comments: []
            ),
            Post(
                user: user1,
                content: "New personal best on my deadlift today! 💪",
                image: nil,
                timestamp: Date().addingTimeInterval(-172800),
                workoutType: .weightlifting,
                challengeId: nil,
                likes: 24,
                comments: [
                    Comment(user: user2, content: "Awesome! What's your new PR?", timestamp: Date().addingTimeInterval(-172000)),
                    Comment(user: user3, content: "Congrats! Keep up the great work!", timestamp: Date().addingTimeInterval(-171000))
                ]
            )
        ]
    }
}

// MARK: - Supporting Views

struct FeedTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.custom(AppSettings.Fonts.body, size: 16))
                    .foregroundColor(isSelected ? Color(AppSettings.Colors.primary) : .secondary)
                
                Rectangle()
                    .fill(isSelected ? Color(AppSettings.Colors.primary) : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct PostCard: View {
    @State private var showingComments = false
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info and timestamp
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Color(AppSettings.Colors.primary))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.user.username)
                        .font(.custom(AppSettings.Fonts.title, size: 16))
                    
                    Text(timeAgo(from: post.timestamp))
                        .font(.custom(AppSettings.Fonts.body, size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let workoutType = post.workoutType {
                    StatusBadge(status: workoutType.rawValue.capitalized)
                } else if post.challengeId != nil {
                    StatusBadge(status: "Challenge")
                }
            }
            
            // Post content
            Text(post.content)
                .font(.custom(AppSettings.Fonts.body, size: 16))
                .padding(.vertical, 4)
            
            // Post image if available
            if let _ = post.image {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    )
            }
            
            Divider()
            
            // Like and comment actions
            HStack {
                Button(action: {
                    // Like action
                }) {
                    HStack {
                        Image(systemName: "heart")
                            .foregroundColor(Color(AppSettings.Colors.primary))
                        Text("\(post.likes)")
                            .font(.custom(AppSettings.Fonts.body, size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    showingComments.toggle()
                }) {
                    HStack {
                        Image(systemName: "bubble.left")
                            .foregroundColor(Color(AppSettings.Colors.primary))
                        Text("\(post.comments.count)")
                            .font(.custom(AppSettings.Fonts.body, size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    // Share action
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(Color(AppSettings.Colors.primary))
                }
            }
            .padding(.top, 4)
            
            // Comments section if expanded
            if showingComments && !post.comments.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    ForEach(post.comments) { comment in
                        CommentView(comment: comment)
                    }
                    
                    // Add comment button
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        
                        Text("Add a comment...")
                            .font(.custom(AppSettings.Fonts.body, size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            return "\(day)d ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        } else {
            return "Just now"
        }
    }
    
    private func iconForWorkoutType(_ type: WorkoutType) -> String {
        switch type {
        case .running:
            return "figure.run"
        case .weightlifting:
            return "figure.strengthtraining.traditional"
        case .basketball:
            return "basketball.fill"
        }
    }
}

struct CommentView: View {
    let comment: Comment
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(Color(AppSettings.Colors.primary))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.user.username)
                        .font(.custom(AppSettings.Fonts.title, size: 14))
                        .foregroundColor(Color(AppSettings.Colors.text))
                    
                    Spacer()
                    
                    Text(timeAgo(from: comment.timestamp))
                        .font(.custom(AppSettings.Fonts.body, size: 10))
                        .foregroundColor(.secondary)
                }
                
                Text(comment.content)
                    .font(.custom(AppSettings.Fonts.body, size: 14))
                    .foregroundColor(Color(AppSettings.Colors.text))
            }
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            return "\(day)d ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        } else {
            return "Just now"
        }
    }
}

struct NewPostView: View {
    @Binding var isPresented: Bool
    let onPost: (Post) -> Void
    @State private var postText = ""
    @State private var selectedWorkoutType: WorkoutType?
    @State private var selectedChallenge: UUID?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Text editor
                ZStack(alignment: .topLeading) {
                    if postText.isEmpty {
                        Text("What's on your mind?")
                            .font(.custom(AppSettings.Fonts.body, size: 16))
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                    
                    TextEditor(text: $postText)
                        .font(.custom(AppSettings.Fonts.body, size: 16))
                        .padding(4)
                        .frame(height: 150)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                
                // Tag options
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tag (optional)")
                        .font(.custom(AppSettings.Fonts.body, size: 14))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        ForEach(WorkoutType.allCases, id: \.self) { workoutType in
                            TagButton(
                                title: workoutType.rawValue.capitalized,
                                isSelected: selectedWorkoutType == workoutType,
                                action: {
                                    if selectedWorkoutType == workoutType {
                                        selectedWorkoutType = nil
                                    } else {
                                        selectedWorkoutType = workoutType
                                        selectedChallenge = nil
                                    }
                                }
                            )
                        }
                        
                        TagButton(
                            title: "Challenge",
                            isSelected: selectedChallenge != nil,
                            action: {
                                if selectedChallenge != nil {
                                    selectedChallenge = nil
                                } else {
                                    selectedChallenge = UUID() // Dummy challenge ID
                                    selectedWorkoutType = nil
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Post")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Post") {
                    createPost()
                    isPresented = false
                }
                .disabled(postText.isEmpty)
            )
        }
    }
    
    private func createPost() {
        // Create a dummy user for demo
        let currentUser = User(id: UUID(), username: "Emma", email: "emma@example.com", created_at: Date(), totalWorkouts: 45, completedChallenges: 12, totalPoints: 3250)
        
        // Create and return a new post
        let newPost = Post(
            user: currentUser,
            content: postText,
            image: nil,
            timestamp: Date(),
            workoutType: selectedWorkoutType,
            challengeId: selectedChallenge,
            likes: 0,
            comments: []
        )
        
        onPost(newPost)
    }
}

struct TagButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom(AppSettings.Fonts.body, size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color(AppSettings.Colors.primary) : Color.clear)
                .foregroundColor(isSelected ? .white : .secondary)
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

struct FindPartnersView: View {
    @State private var recommendedPartners: [User] = []
    @State private var searchText = ""
    
    var body: some View {
        VStack {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search by name or goals...", text: $searchText)
                    .font(.custom(AppSettings.Fonts.body, size: 16))
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Recommended partners
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recommended Partners")
                        .font(.custom(AppSettings.Fonts.title, size: 20))
                        .padding(.horizontal)
                    
                    if recommendedPartners.isEmpty {
                        EmptyStateView(
                            imageName: "person.2.fill",
                            title: "Finding Partners",
                            message: "We're matching you with accountability partners based on your goals"
                        )
                    } else {
                        ForEach(filteredPartners) { partner in
                            PartnerCard(user: partner)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Find Partners")
        .onAppear {
            loadRecommendedPartners()
        }
    }
    
    private var filteredPartners: [User] {
        if searchText.isEmpty {
            return recommendedPartners
        } else {
            return recommendedPartners.filter {
                $0.username.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    private func loadRecommendedPartners() {
        // Sample data for demo purposes
        recommendedPartners = [
            User(id: UUID(), username: "James", email: "james@example.com", created_at: Date(), totalWorkouts: 32, completedChallenges: 7, totalPoints: 2100),
            User(id: UUID(), username: "Olivia", email: "olivia@example.com", created_at: Date(), totalWorkouts: 45, completedChallenges: 12, totalPoints: 3000),
            User(id: UUID(), username: "Noah", email: "noah@example.com", created_at: Date(), totalWorkouts: 28, completedChallenges: 5, totalPoints: 1800)
        ]
    }
}

struct PartnerCard: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile image
            ZStack {
                Circle()
                    .fill(Color(AppSettings.Colors.primary).opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 30))
                    .foregroundColor(Color(AppSettings.Colors.primary))
            }
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.username)
                    .font(.custom(AppSettings.Fonts.title, size: 16))
                
                Text("\(user.totalWorkouts) workouts • \(user.completedChallenges) challenges")
                    .font(.custom(AppSettings.Fonts.body, size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Connect button
            Button(action: {
                // Request partner action
            }) {
                Text("Connect")
                    .font(.custom(AppSettings.Fonts.body, size: 14))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(AppSettings.Colors.primary))
                    .foregroundColor(.white)
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    SocialView()
} 
