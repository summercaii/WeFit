//
//  ContentView.swift
//  WeFit
//
//  Created by Sofia Muniz on 1/28/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            ChallengesView()
                .tabItem {
                    Image(systemName: "trophy.fill")
                    Text("Challenges")
                }
                .tag(1)
            
            SocialView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Social")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Profile")
                }
                .tag(3)
        }
        .accentColor(Color("accent-blue"))
    }
}

#Preview {
    ContentView()
}
