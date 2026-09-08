//
//  DatabaseTest.swift
//  WeFit
//
//  Created by Top G on 5/12/25.
//

import Foundation
import Supabase

import SwiftUI


struct DatabaseManager {
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
            
            let response = try await DatabaseManager.client
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
            let response = try await DatabaseManager.client
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
            let response = try await DatabaseManager.client
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
        }
    }
}
