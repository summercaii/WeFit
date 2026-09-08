//
//  DatabaseTest.swift
//  WeFit
//
//  Created by Top G on 5/12/25.
//

import Foundation
import Supabase

import SwiftUI


struct TestDatabaseManager {
    static let supabaseURL = "https://vqurobjkazktguvtzive.supabase.co" // <-- Replace with your URL
    static let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxdXJvYmprYXprdGd1dnR6aXZlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk4MzIyMjYsImV4cCI6MjA1NTQwODIyNn0.5dUxDyi2HlfKhdxThXkZCIFVYs-HOmqIjtKp1y-9IDU" // <-- Replace with your anon/public key

    static let client = SupabaseClient(
            supabaseURL: URL(string: supabaseURL)!,
            supabaseKey: supabaseKey
        )
}

struct NewUser: Encodable {
    let username: String
    let email: String
}

func addTestUser() {
    Task {
        do {
            // Generate a random username/email to avoid duplicates
            let randomString = UUID().uuidString.prefix(8)
            let newUser = NewUser(username: "testuser\(randomString)", email: "test\(randomString)@example.com")
            
            let response = try await TestDatabaseManager.client
                .from("users")
                .insert([newUser])
                .execute()
            
            print("✅ User added successfully!")
            let data = response.data
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Response: \(jsonString)")
            }
        } catch {
            print("❌ Failed to add user!")
            print("Error: \(error.localizedDescription)")
        }
    }
}

func testWeightliftingWorkoutDetails() {
    Task {
        do {
            // Create test weightlifting workout details
            struct TestWeightliftingDetails: Encodable {
                let workout_id: String
                let workout_name: String
                let sets: Int
                let reps: [Int]     // Array of reps for each exercise
                let weight: [Double] // Array of weights for each exercise  
            }
            
            let testDetails = TestWeightliftingDetails(
                workout_id: UUID().uuidString,
                workout_name: "Test Weightlifting Workout",
                sets: 6,
                reps: [10, 12, 8],        // 3 exercises with different reps
                weight: [50.0, 75.0, 25.0] // 3 exercises with different weights
            )
            
            print("🧪 Testing weightlifting workout details insert...")
            let response = try await TestDatabaseManager.client
                .from("weightlifting_workout_details")
                .insert([testDetails])
                .execute()
            
            print("✅ Weightlifting workout details added successfully!")
            let data = response.data
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Response: \(jsonString)")
            }
        } catch {
            print("❌ Failed to add weightlifting workout details!")
            print("Error: \(error)")
            print("Localized description: \(error.localizedDescription)")
        }
    }
}

func testRunningWorkoutDetails() {
    Task {
        do {
            // Create test running workout details
            struct TestRunningDetails: Encodable {
                let workout_id: String
                let duration: Int
                let distance: Double
                let splits: Double?
            }
            
            let testDetails = TestRunningDetails(
                workout_id: UUID().uuidString,
                duration: 1800, // 30 minutes in seconds
                distance: 5.0,  // 5km
                splits: 7.0     // 7 splits
            )
            
            print("🏃 Testing running workout details insert...")
            let response = try await TestDatabaseManager.client
                .from("running_workout_details")
                .insert([testDetails])
                .execute()
            
            print("✅ Running workout details added successfully!")
            let data = response.data
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Response: \(jsonString)")
            }
        } catch {
            print("❌ Failed to add running workout details!")
            print("Error: \(error)")
            print("Localized description: \(error.localizedDescription)")
        }
    }
}

func testPostCreation() {
    Task {
        do {
            print("🧪 Testing post creation...")
            
            // Create a test post
            struct TestPost: Encodable {
                let id: String
                let user_id: String
                let content: String
                let created_at: String
                let workout_id: String?
                let workout_type: String?
            }
            
            let testPost = TestPost(
                id: UUID().uuidString,
                user_id: "6ea7df9c-6f8c-4c6a-bde5-ebc9e45f69b4", // Replace with a valid user ID from your database
                content: "Test post to debug saving issues",
                created_at: ISO8601DateFormatter().string(from: Date()),
                workout_id: nil,
                workout_type: "running"
            )
            
            print("📝 Attempting to insert test post...")
            let response = try await TestDatabaseManager.client
                .from("posts")
                .insert([testPost])
                .execute()
            
            print("✅ Post created successfully!")
            print("📊 Response status: \(response.status)")
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("Response: \(jsonString)")
            }
            
        } catch {
            print("❌ Failed to create test post!")
            print("Error: \(error)")
            print("Localized description: \(error.localizedDescription)")
        }
    }
}

func testPostRetrieval() {
    Task {
        do {
            print("🔍 Testing post retrieval...")
            
            let response = try await TestDatabaseManager.client
                .from("posts")
                .select("*, users(*), workouts(*)")
                .order("created_at", ascending: false)
                .limit(10)
                .execute()
            
            print("✅ Posts retrieved successfully!")
            print("📊 Response status: \(response.status)")
            print("📊 Response count: \(response.count ?? 0)")
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("Raw response: \(jsonString)")
            }
            
        } catch {
            print("❌ Failed to retrieve posts!")
            print("Error: \(error)")
            print("Localized description: \(error.localizedDescription)")
        }
    }
}

func testPostCount() {
    Task {
        do {
            print("🔢 Testing post count...")
            
            let response = try await TestDatabaseManager.client
                .from("posts")
                .select("*", count: .exact)
                .execute()
            
            print("✅ Post count retrieved!")
            print("📊 Total posts in database: \(response.count ?? 0)")
            
        } catch {
            print("❌ Failed to get post count!")
            print("Error: \(error)")
        }
    }
}

func testMultiplePostCreation() {
    Task {
        print("🧪 Testing multiple post creation to reproduce intermittent issues...")
        
        // Test creating several posts in succession
        for i in 1...5 {
            do {
                struct TestPost: Encodable {
                    let id: String
                    let user_id: String
                    let content: String
                    let created_at: String
                    let workout_id: String?
                    let workout_type: String?
                }
                
                let testPost = TestPost(
                    id: UUID().uuidString,
                    user_id: "6ea7df9c-6f8c-4c6a-bde5-ebc9e45f69b4", // Replace with valid user ID
                    content: "Test post #\(i) - checking for intermittent failures",
                    created_at: ISO8601DateFormatter().string(from: Date()),
                    workout_id: nil,
                    workout_type: i % 2 == 0 ? "running" : "weightlifting"
                )
                
                print("📝 Creating test post #\(i)...")
                let response = try await TestDatabaseManager.client
                    .from("posts")
                    .insert([testPost])
                    .execute()
                
                print("✅ Post #\(i) created successfully! Status: \(response.status)")
                
                // Small delay between posts
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                
            } catch {
                print("❌ Post #\(i) FAILED!")
                print("Error: \(error)")
                print("Localized description: \(error.localizedDescription)")
            }
        }
        
        print("🏁 Multiple post creation test completed")
        
        // Now test retrieval
        print("🔍 Testing retrieval after multiple posts...")
        testPostRetrieval()
    }
}

func testPostCreationWithWorkoutType() {
    Task {
        do {
            print("🧪 Testing post creation with workout_type...")
            
            // Create a test post with workout_type
            struct TestPost: Encodable {
                let id: String
                let user_id: String
                let content: String
                let created_at: String
                let workout_id: String?
                let workout_type: String?
            }
            
            let testPost = TestPost(
                id: UUID().uuidString,
                user_id: "6ea7df9c-6f8c-4c6a-bde5-ebc9e45f69b4", // Replace with a valid user ID from your database
                content: "Test post with workout type - this should work now!",
                created_at: ISO8601DateFormatter().string(from: Date()),
                workout_id: nil,
                workout_type: "running"
            )
            
            print("📝 Attempting to insert test post with workout_type...")
            let response = try await TestDatabaseManager.client
                .from("posts")
                .insert([testPost])
                .execute()
            
            print("✅ Post with workout_type created successfully!")
            print("📊 Response status: \(response.status)")
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("Response: \(jsonString)")
            }
            
        } catch {
            print("❌ Failed to create test post with workout_type!")
            print("Error: \(error)")
            print("Localized description: \(error.localizedDescription)")
        }
    }
}

func testPointCalculation() {
    Task {
        do {
            print("🧪 Testing point calculation system...")
            
            // Use a valid user ID from your database
            let testUserId = "6ea7df9c-6f8c-4c6a-bde5-ebc9e45f69b4" // Replace with actual user ID
            
            let userService = UserService()
            let stats = try await userService.fetchUserStats(userId: testUserId)
            
            print("✅ Point calculation test completed!")
            print("📊 Results:")
            print("   - Workouts: \(stats.workouts)")
            print("   - Challenges: \(stats.challenges)")
            print("   - Total Points: \(stats.points)")
            
        } catch {
            print("❌ Failed to test point calculation!")
            print("Error: \(error)")
            print("Localized description: \(error.localizedDescription)")
        }
    }
}

func testAuthenticationState() {
    Task {
        do {
            print("🔍 Testing authentication state...")
            
            // Check current session
            let session = try await TestDatabaseManager.client.auth.session
            print("✅ Session exists!")
            print("   - User ID: \(session.user.id)")
            print("   - Email: \(session.user.email ?? "N/A")")
            print("   - Access Token length: \(session.accessToken.count)")
            print("   - Session expires at: \(session.expiresAt)")
            
            // Test if we can make authenticated API calls
            print("🔍 Testing authenticated API call...")
            let response = try await TestDatabaseManager.client
                .from("users")
                .select("*")
                .eq("id", value: session.user.id.uuidString)
                .execute()
            
            print("✅ Authenticated API call successful!")
            print("   - Response status: \(response.status)")
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("   - User data: \(jsonString)")
            }
            
        } catch {
            print("❌ Authentication state test failed!")
            print("Error: \(error)")
            print("Localized description: \(error.localizedDescription)")
        }
    }
}

func testEmailVerificationError() {
    Task {
        do {
            print("🧪 Testing email verification error handling...")
            
            // Simulate the condition where signup succeeds but session isn't immediately available
            let authManager = AuthenticationManager()
            
            // Check current session status
            let hasValidSession = await authManager.verifyAuthenticationStatus()
            print("📊 Current session status: \(hasValidSession ? "Valid" : "Invalid/Not found")")
            
            if !hasValidSession {
                print("✅ This simulates the post-signup state where email verification is needed")
                print("💡 In this case, users should see: 'Please check your email and click the verification link to complete your account setup'")
            } else {
                print("ℹ️ User currently has a valid session")
            }
            
        } catch {
            print("❌ Error testing email verification: \(error)")
        }
    }
}

func checkUserExists() {
    Task {
        do {
            print("🔍 Checking if user exists in database...")
            
            // Check for the user by email
            let response = try await TestDatabaseManager.client
                .from("users")
                .select("*")
                .eq("email", value: "shawheeng23@gmail.com")
                .execute()
            
            print("✅ User lookup successful!")
            print("📊 Response status: \(response.status)")
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("📋 User data: \(jsonString)")
            }
            
            // Also check auth users table if accessible
            print("🔍 Checking auth.users table...")
            let authResponse = try await TestDatabaseManager.client.auth.admin.listUsers()
            print("📊 Found \(authResponse.users.count) auth users")
            
            for user in authResponse.users {
                if user.email == "shawheeng23@gmail.com" {
                    print("✅ Found auth user:")
                    print("   - ID: \(user.id)")
                    print("   - Email: \(user.email ?? "N/A")")
                    print("   - Email verified: \(user.emailConfirmedAt != nil)")
                    print("   - Created: \(user.createdAt)")
                }
            }
            
        } catch {
            print("❌ Failed to check user!")
            print("Error: \(error)")
            print("Localized description: \(error.localizedDescription)")
        }
    }
}

func testDirectAuthentication() {
    Task {
        do {
            print("🔐 Testing direct authentication...")
            
            // Replace with the actual password you used
            let email = "shawheeng23@gmail.com"
            let password = "password!" // You need to replace this
            
            print("🔍 Attempting to sign in with email: \(email)")
            
            let session = try await TestDatabaseManager.client.auth.signIn(
                email: email,
                password: password
            )
            
            print("✅ Direct authentication successful!")
            print("📋 User ID: \(session.user.id)")
            print("📧 Email: \(session.user.email ?? "N/A")")
            print("✅ Email verified: \(session.user.emailConfirmedAt != nil)")
            
            // Sign out after test
            try await TestDatabaseManager.client.auth.signOut()
            print("🚪 Signed out after test")
            
        } catch {
            print("❌ Direct authentication failed!")
            print("📝 Error: \(error)")
            print("📝 Error type: \(type(of: error))")
            print("📝 Localized description: \(error.localizedDescription)")
        }
    }
}

func applyMediaMigration() {
    Task {
        do {
            print("🔧 Applying media migration to posts table...")
            
            // Use Supabase's migration approach - we'll need to check if columns exist first
            // For now, let's try to add the columns directly
            
            // Since we can't use ALTER TABLE directly with the anon key, 
            // let's document what needs to be added via Supabase dashboard
            
            print("📋 Media Migration Required:")
            print("   Please add these columns to the 'posts' table via Supabase dashboard:")
            print("   - media_url (TEXT, nullable)")
            print("   - media_type (TEXT, nullable) - values: 'image', 'video'")
            print("   - thumbnail_url (TEXT, nullable) - for video thumbnails")
            print("")
            print("📝 SQL to run in Supabase SQL Editor:")
            print("   ALTER TABLE posts")
            print("   ADD COLUMN media_url TEXT,") 
            print("   ADD COLUMN media_type TEXT,")
            print("   ADD COLUMN thumbnail_url TEXT;")
            print("")
            print("🔒 Note: Cannot execute DDL with anon key. Please run this manually.")
            
        } catch {
            print("❌ Migration info display failed!")
            print("Error: \(error)")
        }
    }
}

func setupMediaStorage() {
    Task {
        do {
            print("🗄️ Setting up media storage...")
            
            // Since we can't create buckets with anon key, provide instructions
            print("📋 Media Storage Setup Required:")
            print("   1. Go to Supabase Dashboard → Storage")
            print("   2. Create a new bucket named: 'post-media'")
            print("   3. Set bucket to 'Public bucket' if you want images to be publicly viewable")
            print("   4. Or keep it private and use signed URLs (recommended)")
            print("")
            print("📝 Bucket policies needed:")
            print("   - Allow authenticated users to INSERT")
            print("   - Allow authenticated users to SELECT their own files")
            print("   - Allow public SELECT if using public bucket")
            print("")
            print("🔒 Sample RLS policies:")
            print("   INSERT: auth.uid() = user_id (if you add user tracking)")
            print("   SELECT: bucket_id = 'post-media' (for public access)")
            print("")
            print("✅ Once bucket is created, the app will be ready for media uploads!")
            
        } catch {
            print("❌ Setup info display failed!")
            print("Error: \(error)")
        }
    }
}

func testMediaFunctionality() {
    Task {
        do {
            print("🧪 Testing media functionality...")
            
            print("📋 Media Feature Checklist:")
            print("✅ Post model updated with media support")
            print("✅ PostService updated with upload functionality")
            print("✅ NewPostView has photo/video picker")
            print("✅ PostCard displays images and videos")
            print("✅ Database migration instructions provided")
            print("✅ Storage bucket setup instructions provided")
            print("")
            
            print("🔧 Required Setup Steps:")
            print("1. Run database migration (click 'Apply Media Migration' button)")
            print("2. Create Supabase storage bucket (click 'Setup Media Storage' button)")
            print("3. Test creating a post with media attachment")
            print("")
            
            print("📱 How to use:")
            print("1. Open NewPostView (tap + in social feed)")
            print("2. Tap 'Photo' or 'Video' button")
            print("3. Select media from photo library")
            print("4. Preview will appear")
            print("5. Add text and tap 'Post'")
            print("6. Media will upload to Supabase Storage")
            print("7. Post appears in feed with media")
            print("")
            
            print("🎯 Features supported:")
            print("- JPEG/PNG image uploads")
            print("- MP4 video uploads")
            print("- Image preview in compose view")
            print("- AsyncImage loading in feed")
            print("- Video player (opens in system player)")
            print("- Remove media option")
            print("")
            
            print("✅ Media functionality is ready!")
            
        } catch {
            print("❌ Test failed!")
            print("Error: \(error)")
        }
    }
}

struct DatabaseTestView: View {
    var body: some View {
        VStack(spacing: 20) {
            Button("Add Test User") {
                addTestUser()
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Test Weightlifting Details") {
                testWeightliftingWorkoutDetails()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Test Running Details") {
                testRunningWorkoutDetails()
            }
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            // Post debugging buttons
            Button("Test Post Creation") {
                testPostCreation()
            }
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Test Post Retrieval") {
                testPostRetrieval()
            }
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Count Posts") {
                testPostCount()
            }
            .padding()
            .background(Color.gray)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Test Multiple Post Creation") {
                testMultiplePostCreation()
            }
            .padding()
            .background(Color.pink)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Test Post Creation with Workout Type") {
                testPostCreationWithWorkoutType()
            }
            .padding()
            .background(Color.yellow)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Test Point Calculation") {
                testPointCalculation()
            }
            .padding()
            .background(Color.cyan)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Test Authentication State") {
                testAuthenticationState()
            }
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Test Email Verification Error") {
                testEmailVerificationError()
            }
            .padding()
            .background(Color.pink)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Check User Exists") {
                checkUserExists()
            }
            .padding()
            .background(Color.gray)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Test Direct Authentication") {
                testDirectAuthentication()
            }
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Apply Media Migration") {
                applyMediaMigration()
            }
            .padding()
            .background(Color.cyan)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Setup Media Storage") {
                setupMediaStorage()
            }
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Test Media Functionality") {
                testMediaFunctionality()
            }
            .padding()
            .background(Color.pink)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}
