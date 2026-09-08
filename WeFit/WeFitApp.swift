//
//  WeFitApp.swift
//  WeFit
//
//  Created by Sofia Muniz on 1/28/25.
//

import SwiftUI

@main
struct WeFitApp: App {
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                ContentView()
                    .environmentObject(authManager)
            } else {
                AuthenticationView()
                    .environmentObject(authManager)
            }
        }
    }
}
