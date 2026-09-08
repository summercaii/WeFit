import SwiftUI

struct AppSettings {
    // API endpoints
    static let baseURL = "https://api.wefit.com"
    
    // Feature flags
    static let enableHealthKit = true
    static let enableNotifications = true
    
    // Design constants
    struct Colors {
        static let primary = "accent-blue"
        static let secondary = "accent-green" 
        static let background = "bg-light"
        static let text = "text-dark"
    }
    
    struct Fonts {
        static let title = "AvenirNext-Bold"
        static let body = "AvenirNext-Regular"
    }
    
    // Authentication settings
    struct Auth {
        static let appleSignInEnabled = true
        static let googleSignInEnabled = true
        static let emailSignInEnabled = true
    }
    
    // Challenge settings
    struct Challenges {
        static let maxActivePersonalChallenges = 3
        static let maxActiveGroupChallenges = 5
        static let minChallengeDuration = 1 // days
        static let maxChallengeDuration = 30 // days
    }
    
    // Social settings
    struct Social {
        static let maxPostLength = 500
        static let maxCommentLength = 200
        static let maxGroupSize = 50
    }
}

// Extension to make color access more convenient
extension Color {
    static let appPrimary = Color("accent-blue")
    static let appSecondary = Color("accent-green")
    static let appBackground = Color("bg-light")
    static let appText = Color("text-dark")
} 