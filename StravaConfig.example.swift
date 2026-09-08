import Foundation

/// Copy this file to StravaConfig.swift (which is gitignored) and fill in
/// your own values after creating a Strava API app at strava.com/settings/api.
/// Strava validates the redirect_uri's *host* against your app's registered
/// "Authorization Callback Domain" (set to "localhost") — so the redirect
/// URI's host must literally be "localhost", with the custom scheme carrying
/// it back to this app (iOS routes by scheme, Strava validates by host).
enum StravaConfig {
    static let clientId = "YOUR_STRAVA_CLIENT_ID"
    static let clientSecret = "YOUR_STRAVA_CLIENT_SECRET"
    static let redirectURI = "wefit://localhost/strava-callback"

    static var isConfigured: Bool {
        !clientId.contains("YOUR_STRAVA_CLIENT_ID") && !clientSecret.contains("YOUR_STRAVA_CLIENT_SECRET")
    }
}
