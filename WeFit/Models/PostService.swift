import Foundation
import Supabase

// Database model for posts
struct DatabasePost: Codable {
    let id: String
    let user_id: String
    let content: String
    let workout_id: String?
    let workout_type: String?
    let created_at: String
}

class PostService {
    // Reference to your Supabase client
    private let client = DatabaseManager.client
    private let userService = UserService()
    
    // Fetch posts from the database
    func fetchPosts(limit: Int = 20) async throws -> [Post] {
        let response = try await client
            .from("posts")
            .select("*, users(*), workouts(*)")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
        
        // Define nested structures to match the joined data from Supabase
        struct JoinedPostData: Decodable {
            let id: String
            let user_id: String
            let content: String
            let created_at: String
            let workout_id: String?
            let workout_type: String?
            let users: UserData
            let workouts: WorkoutData?
            
            struct UserData: Decodable {
                let id: String
                let username: String
                let email: String
                let created_at: String
            }
            
            struct WorkoutData: Decodable {
                let id: String
                let workout_type: String
            }
        }
        
        // Setup date formatter for decoding
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        
        // Decode the response
        let decoder = JSONDecoder()
        let joinedPosts = try decoder.decode([JoinedPostData].self, from: response.data)
        
        // Convert to app's Post model
        var posts: [Post] = []
        for joinedPost in joinedPosts {
            // Create User from the joined data
            let userId = UUID(uuidString: joinedPost.user_id) ?? UUID()
            let user = User(
                id: userId,
                username: joinedPost.users.username,
                email: joinedPost.users.email,
                created_at: dateFormatter.date(from: joinedPost.users.created_at) ?? Date()
            )
            
            // Determine workout type if available
            var workoutType: WorkoutType? = nil
            var challengeId: UUID? = nil
            
            // First check if we have a workout type directly on the post
            if let workoutTypeString = joinedPost.workout_type {
                workoutType = WorkoutType(rawValue: workoutTypeString)
            }
            // Fall back to linked workout if available
            else if let workoutData = joinedPost.workouts {
                workoutType = WorkoutType(rawValue: workoutData.workout_type)
            }
            
            // Create the post
            let post = Post(
                user: user,
                content: joinedPost.content,
                image: nil, // No image support in current DB schema
                timestamp: dateFormatter.date(from: joinedPost.created_at) ?? Date(),
                workoutType: workoutType,
                challengeId: challengeId, // No challenge support in current DB schema
                likes: 0, // No likes support in current DB schema
                comments: [] // Comments would require another join
            )
            
            posts.append(post)
        }
        
        return posts
    }
    
    // Save a post to the database
    func savePost(userId: UUID, content: String, workoutId: UUID? = nil, workoutType: String? = nil) async throws -> UUID {
        let postId = UUID()
        let now = Date()
        
        // Create an encodable struct for the post
        struct EncodablePost: Encodable {
            let id: String
            let user_id: String
            let content: String
            let created_at: String
            let workout_id: String?
            let workout_type: String?
        }
        
        let encodablePost = EncodablePost(
            id: postId.uuidString,
            user_id: userId.uuidString,
            content: content,
            created_at: ISO8601DateFormatter().string(from: now),
            workout_id: workoutId?.uuidString,
            workout_type: workoutType
        )
        
        _ = try await client
            .from("posts")
            .insert([encodablePost])
            .execute()
        
        return postId
    }
} 