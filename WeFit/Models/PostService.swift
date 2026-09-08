import Foundation
import Supabase
import UIKit
import AVFoundation

// Database model for posts
struct DatabasePost: Codable {
    let id: String
    let user_id: String
    let content: String
    let workout_id: String?
    let workout_type: String?
    let created_at: String
    let media_url: String?
    let media_type: String?
    let thumbnail_url: String?
}

class PostService {
    // Reference to your Supabase client
    private let client = DatabaseManager.client
    private let userService = UserService()
    
    // MARK: - Media Compression
    
    // Compress video to reduce file size
    private func compressVideo(url: URL) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            // Create temporary output URL
            let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            
            // Create asset and export session
            let asset = AVAsset(url: url)
            guard let exportSession = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetMediumQuality
            ) else {
                continuation.resume(throwing: NSError(
                    domain: "VideoCompressionError",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not create export session"]
                ))
                return
            }
            
            // Configure export settings
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            exportSession.shouldOptimizeForNetworkUse = true
            
            // Start compression
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    do {
                        let compressedData = try Data(contentsOf: outputURL)
                        
                        // Clean up temporary file
                        try? FileManager.default.removeItem(at: outputURL)
                        
                        print("✅ Video compressed: Original size unknown -> Compressed size: \(ByteCountFormatter.string(fromByteCount: Int64(compressedData.count), countStyle: .file))")
                        
                        continuation.resume(returning: compressedData)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                    
                case .failed:
                    continuation.resume(throwing: exportSession.error ?? NSError(
                        domain: "VideoCompressionError",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Video compression failed"]
                    ))
                    
                case .cancelled:
                    continuation.resume(throwing: NSError(
                        domain: "VideoCompressionError",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Video compression was cancelled"]
                    ))
                    
                default:
                    continuation.resume(throwing: NSError(
                        domain: "VideoCompressionError",
                        code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown compression status"]
                    ))
                }
            }
        }
    }
    
    // Compress image to reduce file size
    private func compressImage(data: Data, maxSizeBytes: Int = 5 * 1024 * 1024) -> Data {
        guard let image = UIImage(data: data) else { return data }
        
        // Start with high quality and reduce if needed
        var compressionQuality: CGFloat = 0.8
        var compressedData = data
        
        // Resize image if it's too large
        let maxDimension: CGFloat = 1920 // 1080p max
        let resizedImage: UIImage
        
        if max(image.size.width, image.size.height) > maxDimension {
            let ratio = maxDimension / max(image.size.width, image.size.height)
            let newSize = CGSize(
                width: image.size.width * ratio,
                height: image.size.height * ratio
            )
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        } else {
            resizedImage = image
        }
        
        // Compress until under size limit
        repeat {
            if let jpegData = resizedImage.jpegData(compressionQuality: compressionQuality) {
                compressedData = jpegData
            }
            compressionQuality -= 0.1
        } while compressedData.count > maxSizeBytes && compressionQuality > 0.1
        
        print("✅ Image compressed: Original size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)) -> Compressed size: \(ByteCountFormatter.string(fromByteCount: Int64(compressedData.count), countStyle: .file))")
        
        return compressedData
    }
    
    // MARK: - Post Methods
    
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
            let media_url: String?
            let media_type: String?
            let thumbnail_url: String?
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
        
        // Create flexible date decoder that handles multiple formats
        func decodeDate(from dateString: String) -> Date {
            // Format 1: With microseconds (e.g., "2025-05-20T06:43:15.966212+00:00")
            let fullFormatter = DateFormatter()
            fullFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
            
            if let date = fullFormatter.date(from: dateString) {
                return date
            }
            
            // Format 2: Without microseconds (e.g., "2025-06-01T20:51:44+00:00")
            let simpleFormatter = DateFormatter()
            simpleFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            
            if let date = simpleFormatter.date(from: dateString) {
                return date
            }
            
            // Format 3: ISO8601 fallback
            if let date = ISO8601DateFormatter().date(from: dateString) {
                return date
            }
            
            // If all formats fail, return current date
            print("Warning: Could not parse date string: \(dateString)")
            return Date()
        }
        
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
                created_at: decodeDate(from: joinedPost.users.created_at)
            )
            
            // Determine workout type from post data or linked workout
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
            
            // Create media object if media data exists
            var media: PostMedia? = nil
            if let mediaUrl = joinedPost.media_url,
               let mediaTypeString = joinedPost.media_type,
               let mediaType = MediaType(rawValue: mediaTypeString) {
                media = PostMedia(
                    url: mediaUrl,
                    type: mediaType,
                    thumbnailUrl: joinedPost.thumbnail_url
                )
            }
            
            // Create the post
            let post = Post(
                user: user,
                content: joinedPost.content,
                image: nil, // Legacy field
                media: media, // New media support
                timestamp: decodeDate(from: joinedPost.created_at),
                workoutType: workoutType,
                challengeId: challengeId, // No challenge support in current DB schema
                likes: 0, // No likes support in current DB schema
                comments: [] // Comments would require another join
            )
            
            posts.append(post)
        }
        
        return posts
    }
    
    // Upload media to Supabase Storage
    func uploadMedia(_ imageData: Data, fileName: String, mediaType: MediaType) async throws -> (String, String?) {
        // Upload to Supabase Storage - the upload method expects Data directly
        _ = try await client.storage
            .from("post-media")
            .upload(
                path: fileName,
                file: imageData,
                options: FileOptions(
                    contentType: mediaType == .image ? "image/jpeg" : "video/mp4"
                )
            )
        
        // Get public URL - createSignedURL returns a URL object, convert to string
        let signedURL = try await client.storage
            .from("post-media")
            .createSignedURL(path: fileName, expiresIn: 31536000) // 1 year
        
        let mediaUrl = signedURL.absoluteString
        
        // For videos, we might want to generate a thumbnail
        // For now, return nil for thumbnail URL
        var thumbnailUrl: String? = nil
        
        if mediaType == .video {
            // TODO: Implement video thumbnail generation
            // For now, we'll use a placeholder or the video URL itself
            thumbnailUrl = mediaUrl
        }
        
        return (mediaUrl, thumbnailUrl)
    }
    
    // Save a post to the database with optional media
    func savePost(userId: UUID, content: String, workoutId: UUID? = nil, workoutType: String? = nil, media: (Data, MediaType)? = nil) async throws -> UUID {
        let postId = UUID()
        let now = Date()
        
        var mediaUrl: String? = nil
        var mediaTypeString: String? = nil
        var thumbnailUrl: String? = nil
        
        // Upload media if provided
        if let (mediaData, mediaType) = media {
            // Compress media before upload
            let compressedData: Data
            switch mediaType {
            case .image:
                compressedData = compressImage(data: mediaData, maxSizeBytes: 10 * 1024 * 1024) // 10MB max for images
            case .video:
                // For video, mediaData should actually be URL data - we'll handle this in the new method below
                compressedData = mediaData
            }
            
            let fileName = "\(postId.uuidString).\(mediaType == .image ? "jpg" : "mp4")"
            let (uploadedUrl, uploadedThumbnailUrl) = try await uploadMedia(compressedData, fileName: fileName, mediaType: mediaType)
            mediaUrl = uploadedUrl
            mediaTypeString = mediaType.rawValue
            thumbnailUrl = uploadedThumbnailUrl
        }
        
        // Create an encodable struct for the post using all columns including media
        struct DatabasePost: Encodable {
            let id: String
            let user_id: String
            let content: String
            let created_at: String
            let workout_id: String?
            let workout_type: String?
            let media_url: String?
            let media_type: String?
            let thumbnail_url: String?
        }
        
        let encodablePost = DatabasePost(
            id: postId.uuidString,
            user_id: userId.uuidString,
            content: content,
            created_at: ISO8601DateFormatter().string(from: now),
            workout_id: workoutId?.uuidString,
            workout_type: workoutType,
            media_url: mediaUrl,
            media_type: mediaTypeString,
            thumbnail_url: thumbnailUrl
        )
        
        _ = try await client
            .from("posts")
            .insert([encodablePost])
            .execute()
        
        return postId
    }
    
    // New method to handle video URLs from PhotosPicker
    func savePost(userId: UUID, content: String, workoutId: UUID? = nil, workoutType: String? = nil, mediaURL: URL?, mediaType: MediaType?) async throws -> (postId: UUID, uploadedMediaURL: String?, thumbnailURL: String?) {
        let postId = UUID()
        let now = Date()
        
        var mediaUrl: String? = nil
        var mediaTypeString: String? = nil
        var thumbnailUrl: String? = nil
        
        // Upload media if provided
        if let url = mediaURL, let type = mediaType {
            let compressedData: Data
            
            switch type {
            case .image:
                // Load image data and compress
                let originalData = try Data(contentsOf: url)
                compressedData = compressImage(data: originalData, maxSizeBytes: 10 * 1024 * 1024) // 10MB max for images
                
            case .video:
                // Compress video
                print("🔄 Compressing video before upload...")
                compressedData = try await compressVideo(url: url)
                print("✅ Video compression completed")
            }
            
            let fileName = "\(postId.uuidString).\(type == .image ? "jpg" : "mp4")"
            let (uploadedUrl, uploadedThumbnailUrl) = try await uploadMedia(compressedData, fileName: fileName, mediaType: type)
            mediaUrl = uploadedUrl
            mediaTypeString = type.rawValue
            thumbnailUrl = uploadedThumbnailUrl
        }
        
        // Create an encodable struct for the post using all columns including media
        struct DatabasePost: Encodable {
            let id: String
            let user_id: String
            let content: String
            let created_at: String
            let workout_id: String?
            let workout_type: String?
            let media_url: String?
            let media_type: String?
            let thumbnail_url: String?
        }
        
        let encodablePost = DatabasePost(
            id: postId.uuidString,
            user_id: userId.uuidString,
            content: content,
            created_at: ISO8601DateFormatter().string(from: now),
            workout_id: workoutId?.uuidString,
            workout_type: workoutType,
            media_url: mediaUrl,
            media_type: mediaTypeString,
            thumbnail_url: thumbnailUrl
        )
        
        _ = try await client
            .from("posts")
            .insert([encodablePost])
            .execute()
        
        return (postId: postId, uploadedMediaURL: mediaUrl, thumbnailURL: thumbnailUrl)
    }
    
    // Legacy method for backward compatibility
    func savePost(userId: UUID, content: String, workoutId: UUID? = nil, workoutType: String? = nil) async throws -> UUID {
        return try await savePost(userId: userId, content: content, workoutId: workoutId, workoutType: workoutType, media: nil)
    }
} 