import SwiftUI
import PhotosUI
import AVFoundation
import AVKit

enum MediaType: String, CaseIterable {
    case image = "image"
    case video = "video"
}

struct PostMedia {
    let url: String
    let type: MediaType
    let thumbnailUrl: String? // For video thumbnails
}

struct Post: Identifiable {
    let id = UUID()
    let user: User
    let content: String
    let image: String? // Legacy - keeping for compatibility
    let media: PostMedia? // New media support
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
    @EnvironmentObject var authManager: AuthenticationManager
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
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        print("🔄 Manual refresh requested")
                        loadSamplePosts()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Color(AppSettings.Colors.primary))
                    }
                }
            }
            .sheet(isPresented: $showingNewPostSheet) {
                NewPostView(isPresented: $showingNewPostSheet, onPost: { post in
                    // Add new post to feed
                    posts.insert(post, at: 0)
                })
                .environmentObject(authManager)
            }
            .onAppear {
                print("🔍 SocialView: View appeared, checking authentication...")
                Task {
                    // Verify authentication session
                    let isSessionValid = await authManager.verifyAuthenticationStatus()
                    if isSessionValid {
                        print("✅ SocialView: Session valid, loading posts...")
                        loadSamplePosts()
                    } else {
                        print("⚠️ SocialView: Session invalid, user needs to re-authenticate")
                        await MainActor.run {
                            authManager.isAuthenticated = false
                            authManager.currentUser = nil
                        }
                    }
                } 
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
        // Try to fetch posts from the database
        print("🔍 SocialView: Starting to load posts...")
        Task {
            do {
                let postService = PostService()
                print("📡 SocialView: Making database request for posts...")
                let fetchedPosts = try await postService.fetchPosts()
                print("✅ SocialView: Successfully fetched \(fetchedPosts.count) posts from database")
                
                await MainActor.run {
                    if !fetchedPosts.isEmpty {
                        print("🎯 SocialView: Updating UI with \(fetchedPosts.count) real posts")
                        self.posts = fetchedPosts
                    } else {
                        print("⚠️ SocialView: No posts found in database, falling back to sample data")
                        // Fallback to sample data if no posts in database
                        createSamplePosts()
                    }
                }
            } catch {
                print("❌ SocialView: Error fetching posts: \(error)")
                print("📋 SocialView: Error details: \(error.localizedDescription)")
                
                // Fallback to sample data on error
                await MainActor.run {
                    print("🔄 SocialView: Using sample data due to fetch error")
                    createSamplePosts()
                }
            }
        }
    }
    
    // Create sample posts for when the database is empty
    private func createSamplePosts() {
        // Sample users
        let user1 = authManager.currentUser ?? User(id: UUID(), username: "Emma", email: "emma@example.com", created_at: Date(), totalWorkouts: 45, completedChallenges: 12, totalPoints: 3250)
        let user2 = User(id: UUID(), username: "Michael", email: "michael@example.com", created_at: Date(), totalWorkouts: 32, completedChallenges: 8, totalPoints: 2800)
        let user3 = User(id: UUID(), username: "Sophia", email: "sophia@example.com", created_at: Date(), totalWorkouts: 22, completedChallenges: 5, totalPoints: 1500)
        
        // Sample posts
        posts = [
            Post(
                user: user2,
                content: "Just completed my morning 5K run! Feeling great and ready for the day. Who's up for a challenge this weekend?",
                image: nil,
                media: nil,
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
                media: nil,
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
                media: nil,
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
    @State private var showingVideoPlayer = false
    @State private var videoPlayer: AVPlayer?
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
            
            // Media display (images and videos)
            if let media = post.media {
                switch media.type {
                case .image:
                    AsyncImage(url: URL(string: media.url)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .overlay(
                                ProgressView()
                            )
                    }
                    .frame(maxHeight: 300)
                    .cornerRadius(10)
                    .clipped()
                    
                case .video:
                    ZStack {
                        // Video thumbnail or placeholder
                        if let thumbnailURL = media.thumbnailUrl,
                           let url = URL(string: thumbnailURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 200)
                                    .clipped()
                                    .cornerRadius(10)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.black.opacity(0.8))
                                    .frame(height: 200)
                                    .overlay(
                                        ProgressView()
                                            .tint(.white)
                                    )
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.8))
                                .frame(height: 200)
                        }
                        
                        // Play button overlay
                        VStack {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                                .shadow(radius: 10)
                            Text("Tap to Play")
                                .font(.custom(AppSettings.Fonts.body, size: 14))
                                .foregroundColor(.white)
                                .shadow(radius: 5)
                        }
                    }
                    .onTapGesture {
                        if let url = URL(string: media.url) {
                            print("🎥 Playing video in-app: \(media.url)")
                            videoPlayer = AVPlayer(url: url)
                            showingVideoPlayer = true
                        } else {
                            print("❌ Invalid video URL: \(media.url)")
                        }
                    }
                }
            }
            // Legacy image support (keeping for backward compatibility)
            else if let _ = post.image {
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
        .sheet(isPresented: $showingVideoPlayer) {
            if let player = videoPlayer {
                VideoPlayerView(player: player, isPresented: $showingVideoPlayer)
                    .presentationBackground(.black)
                    .presentationDragIndicator(.hidden)
            }
        }
        .onDisappear {
            // Clean up video player
            videoPlayer?.pause()
            videoPlayer = nil
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
    @EnvironmentObject var authManager: AuthenticationManager
    @Binding var isPresented: Bool
    let onPost: (Post) -> Void
    @State private var postText = ""
    @State private var selectedWorkoutType: WorkoutType?
    @State private var selectedChallenge: UUID?
    @State private var isPosting = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    // Media picker states
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedVideoURL: URL?
    @State private var selectedMediaType: MediaType?
    @State private var videoThumbnail: UIImage?
    @State private var showingMediaPicker = false
    
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
                        .disabled(isPosting)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                
                // Media attachment section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Attach Media")
                            .font(.custom(AppSettings.Fonts.body, size: 14))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if selectedImageData != nil || selectedVideoURL != nil {
                            Button("Remove") {
                                // Clean up temporary video file
                                if let videoURL = selectedVideoURL {
                                    try? FileManager.default.removeItem(at: videoURL)
                                }
                                selectedImageData = nil
                                selectedVideoURL = nil
                                selectedPhoto = nil
                                selectedMediaType = nil
                                videoThumbnail = nil
                            }
                            .font(.custom(AppSettings.Fonts.body, size: 12))
                            .foregroundColor(.red)
                        }
                    }
                    
                    // Media preview
                    if let imageData = selectedImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(10)
                            .clipped()
                    } else if let videoURL = selectedVideoURL {
                        ZStack {
                            // Video thumbnail or placeholder
                            if let thumbnail = videoThumbnail {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 200)
                                    .clipped()
                                    .cornerRadius(10)
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.black.opacity(0.8))
                                    .frame(height: 200)
                            }
                            
                            // Play button overlay
                            VStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                                    .shadow(radius: 10)
                                
                                Text("Video Preview")
                                    .font(.custom(AppSettings.Fonts.body, size: 14))
                                    .foregroundColor(.white)
                                    .shadow(radius: 5)
                            }
                        }
                    }
                    
                    // Media picker buttons
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            HStack {
                                Image(systemName: "photo")
                                Text("Photo")
                            }
                            .font(.custom(AppSettings.Fonts.body, size: 14))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                        .disabled(isPosting || selectedImageData != nil || selectedVideoURL != nil)
                        
                        PhotosPicker(selection: $selectedPhoto, matching: .videos) {
                            HStack {
                                Image(systemName: "video")
                                Text("Video")
                            }
                            .font(.custom(AppSettings.Fonts.body, size: 14))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.purple.opacity(0.1))
                            .foregroundColor(.purple)
                            .cornerRadius(8)
                        }
                        .disabled(isPosting || selectedImageData != nil || selectedVideoURL != nil)
                        
                        Spacer()
                    }
                }
                .padding(.horizontal)
                
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
                
                // Loading indicator
                if isPosting {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Posting...")
                            .font(.custom(AppSettings.Fonts.body, size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .padding()
            .navigationTitle("New Post")
            .navigationBarItems(
                leading: Button("Cancel") {
                    if !isPosting {
                        isPresented = false
                    }
                }
                .disabled(isPosting),
                trailing: Button("Post") {
                    createPost()
                }
                .disabled(postText.isEmpty || isPosting)
            )
            .alert("Post Failed", isPresented: $showingErrorAlert) {
                Button("Try Again") {
                    createPost()
                }
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }
            } message: {
                Text(errorMessage)
            }
        }
        .onDisappear {
            cleanupTemporaryFiles()
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let newValue = newValue {
                    do {
                        // Determine media type based on content type
                        if let contentType = newValue.supportedContentTypes.first {
                            if contentType.conforms(to: .image) {
                                selectedMediaType = .image
                                if let data = try await newValue.loadTransferable(type: Data.self) {
                                    selectedImageData = data
                                    selectedVideoURL = nil
                                    print("✅ Image loaded successfully: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
                                }
                            } else if contentType.conforms(to: .movie) {
                                selectedMediaType = .video
                                // For videos, load as Data first, then create temporary URL
                                if let data = try await newValue.loadTransferable(type: Data.self) {
                                    // Create temporary file for video
                                    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                                        .appendingPathComponent(UUID().uuidString)
                                        .appendingPathExtension("mov")
                                    
                                    try data.write(to: tempURL)
                                    selectedVideoURL = tempURL
                                    selectedImageData = nil
                                    print("✅ Video loaded successfully: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
                                    print("🎥 Video saved to temporary URL: \(tempURL.lastPathComponent)")
                                    
                                    // Generate thumbnail for video preview
                                    print("🔄 Generating video thumbnail...")
                                    if let thumbnail = await generateVideoThumbnail(from: tempURL) {
                                        await MainActor.run {
                                            videoThumbnail = thumbnail
                                            print("✅ Video thumbnail generated successfully")
                                        }
                                    }
                                }
                            }
                        }
                    } catch {
                        print("❌ Error loading selected media: \(error)")
                        // Reset states on error
                        selectedImageData = nil
                        selectedVideoURL = nil
                        selectedMediaType = nil
                    }
                }
            }
        }
    }
    
    // Generate thumbnail from video URL
    private func generateVideoThumbnail(from url: URL) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 300, height: 300)
            
            let time = CMTime(seconds: 1.0, preferredTimescale: 600)
            
            imageGenerator.generateCGImageAsynchronously(for: time) { cgImage, _, error in
                if let cgImage = cgImage {
                    let thumbnail = UIImage(cgImage: cgImage)
                    continuation.resume(returning: thumbnail)
                } else {
                    print("❌ Failed to generate video thumbnail: \(error?.localizedDescription ?? "Unknown error")")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // Clean up temporary files when view disappears
    private func cleanupTemporaryFiles() {
        if let videoURL = selectedVideoURL {
            try? FileManager.default.removeItem(at: videoURL)
            print("🗑️ Cleaned up temporary video file on view disappear")
        }
    }
    
    private func createPost() {
        guard let currentUser = authManager.currentUser else {
            errorMessage = "You must be logged in to create a post."
            showingErrorAlert = true
            return
        }
        
        isPosting = true
        
        // Verify authentication session before attempting to create post
        Task {
            do {
                // Check if session is valid first
                print("🔍 SocialView: Verifying authentication session...")
                let isSessionValid = await authManager.verifyAuthenticationStatus()
                print("🔍 Auth verification: Session valid = \(isSessionValid), User ID = \(currentUser.id)")
                
                if !isSessionValid {
                    await MainActor.run {
                        isPosting = false
                        errorMessage = "Your session has expired. Please sign out and log back in."
                        showingErrorAlert = true
                    }
                    return
                }
                
                print("✅ SocialView: Session verified, creating post...")
                let postService = PostService()
                
                // Use the new URL-based method for proper video compression
                var mediaURL: URL? = nil
                var mediaType: MediaType? = nil
                
                if let imageData = selectedImageData,
                   selectedMediaType == .image {
                    // For images, create a temporary file URL
                    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("jpg")
                    try imageData.write(to: tempURL)
                    mediaURL = tempURL
                    mediaType = .image
                } else if let videoURL = selectedVideoURL,
                          selectedMediaType == .video {
                    mediaURL = videoURL
                    mediaType = .video
                }
                
                let result = try await postService.savePost(
                    userId: currentUser.id,
                    content: postText,
                    workoutType: selectedWorkoutType?.rawValue,
                    mediaURL: mediaURL,
                    mediaType: mediaType
                )
                
                let postId = result.postId
                let uploadedMediaURL = result.uploadedMediaURL
                let thumbnailURL = result.thumbnailURL
                
                print("✅ Post successfully saved to database with ID: \(postId)")
                if let mediaURL = uploadedMediaURL {
                    print("🎥 Media uploaded to: \(mediaURL)")
                }
                
                // Clean up temporary file if created
                if selectedMediaType == .image,
                   let tempURL = mediaURL {
                    try? FileManager.default.removeItem(at: tempURL)
                } else if selectedMediaType == .video,
                          let videoURL = selectedVideoURL {
                    // Clean up the temporary video file
                    try? FileManager.default.removeItem(at: videoURL)
                    print("🗑️ Cleaned up temporary video file")
                }
                
                // Create media object for UI using the actual uploaded URLs
                var postMedia: PostMedia? = nil
                if let uploadedURL = uploadedMediaURL,
                   let mediaType = selectedMediaType {
                    postMedia = PostMedia(
                        url: uploadedURL,
                        type: mediaType,
                        thumbnailUrl: thumbnailURL
                    )
                }
                
                // Only create and show the post in UI after successful database save
                await MainActor.run {
                    let newPost = Post(
                        user: currentUser,
                        content: postText,
                        image: nil,
                        media: postMedia,
                        timestamp: Date(),
                        workoutType: selectedWorkoutType,
                        challengeId: selectedChallenge,
                        likes: 0,
                        comments: []
                    )
                    
                    onPost(newPost)
                    isPosting = false
                    isPresented = false
                }
                
            } catch {
                print("❌ Error saving post to database: \(error)")
                
                // Show user-friendly error message
                await MainActor.run {
                    isPosting = false
                    errorMessage = "Failed to create your post. Please check your internet connection and try again."
                    showingErrorAlert = true
                }
            }
        }
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

struct VideoPlayerView: View {
    let player: AVPlayer
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VideoPlayer(player: player)
                .onAppear {
                    // Configure audio session for video playback
                    do {
                        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
                        try AVAudioSession.sharedInstance().setActive(true)
                    } catch {
                        print("❌ Failed to configure audio session: \(error)")
                    }
                    
                    player.play()
                    print("▶️ Video player started with audio enabled")
                }
                .onDisappear {
                    player.pause()
                    print("⏸️ Video player stopped")
                }
        }
        .onTapGesture {
            // Allow tap to dismiss - this is a common pattern
            isPresented = false
        }
        .statusBarHidden()
    }
}

#Preview {
    SocialView()
} 
