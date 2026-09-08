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
            Group {
                if authManager.isAuthenticated {
                    ContentView()
                        .environmentObject(authManager)
                } else {
                    AuthenticationView()
                        .environmentObject(authManager)
                }
            }
            .onOpenURL { url in
                StravaSyncService.shared.handleRedirect(url: url)
            }
        }
    }
}
