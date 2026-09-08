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
        }
    }
}
