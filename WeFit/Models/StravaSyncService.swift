import Foundation
import AuthenticationServices
import UIKit

/// Connects to Strava via OAuth and imports recent runs as WeFit Workouts
/// (workout_type = .running) with matching running_workout_details rows.
@MainActor
final class StravaSyncService: NSObject, ObservableObject {
    static let shared = StravaSyncService()

    @Published var isConnected: Bool
    @Published var isSyncing = false
    @Published var errorMessage: String?
    @Published var lastSyncedCount: Int?

    private let client = DatabaseManager.client
    private var pendingContinuation: CheckedContinuation<Void, Error>?

    private var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "strava_access_token") }
        set { UserDefaults.standard.set(newValue, forKey: "strava_access_token") }
    }
    private var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "strava_refresh_token") }
        set { UserDefaults.standard.set(newValue, forKey: "strava_refresh_token") }
    }
    private var expiresAt: Date? {
        get { UserDefaults.standard.object(forKey: "strava_expires_at") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "strava_expires_at") }
    }
    /// On-device record of already-imported Strava activity IDs, so re-syncing
    /// doesn't create duplicate workouts. (Per-device only; a server-side
    /// table keyed by strava activity id would be needed for cross-device dedup.)
    private var importedActivityIds: Set<Int> {
        get { Set(UserDefaults.standard.array(forKey: "strava_imported_ids") as? [Int] ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "strava_imported_ids") }
    }

    override init() {
        self.isConnected = UserDefaults.standard.string(forKey: "strava_access_token") != nil
        super.init()
    }

    // MARK: - Authorization

    /// Public entry point — never throws, publishes failures via errorMessage
    /// so the UI (which can't easily surface a thrown error from a fire-and-
    /// forget Task) always has something to show.
    func connect() async {
        errorMessage = nil
        do {
            try await requestAuthorization()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Strava connect failed: \(error.localizedDescription)")
        }
    }

    private func requestAuthorization() async throws {
        guard StravaConfig.isConfigured else { throw StravaSyncError.notConfigured }

        var components = URLComponents(string: "https://www.strava.com/oauth/mobile/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: StravaConfig.clientId),
            URLQueryItem(name: "redirect_uri", value: StravaConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope", value: "activity:read_all"),
        ]
        guard let authURL = components.url,
              let scheme = URL(string: StravaConfig.redirectURI)?.scheme else {
            throw StravaSyncError.badAuthURL
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.pendingContinuation = continuation
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { [weak self] callbackURL, error in
                guard let self else { return }
                if let error {
                    self.pendingContinuation?.resume(throwing: error)
                    self.pendingContinuation = nil
                    return
                }
                if let callbackURL {
                    Task { await self.finishAuthorization(callbackURL: callbackURL) }
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            session.start()
        }
    }

    func handleRedirect(url: URL) {
        Task { await finishAuthorization(callbackURL: url) }
    }

    private func finishAuthorization(callbackURL: URL) async {
        defer { pendingContinuation = nil }
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            pendingContinuation?.resume(throwing: StravaSyncError.missingCode)
            return
        }
        do {
            try await exchangeCodeForToken(code: code)
            isConnected = true
            pendingContinuation?.resume()
        } catch {
            pendingContinuation?.resume(throwing: error)
        }
    }

    func disconnect() {
        accessToken = nil
        refreshToken = nil
        expiresAt = nil
        isConnected = false
    }

    /// Forgets which Strava activities have already been imported (without
    /// disconnecting Strava), so the next sync re-evaluates recent activities
    /// with current import logic. Doesn't touch anything already saved to
    /// WeFit — delete those rows in Supabase separately if you don't want
    /// duplicates.
    func resetSyncHistory() {
        importedActivityIds = []
        lastSyncedCount = nil
    }

    private func exchangeCodeForToken(code: String) async throws {
        let token = try await requestToken(body: [
            "client_id": StravaConfig.clientId,
            "client_secret": StravaConfig.clientSecret,
            "code": code,
            "grant_type": "authorization_code",
        ])
        store(token)
    }

    private func validAccessToken() async throws -> String {
        if let expiresAt, expiresAt > Date().addingTimeInterval(60), let accessToken {
            return accessToken
        }
        guard let refreshToken else { throw StravaSyncError.notConnected }
        let token = try await requestToken(body: [
            "client_id": StravaConfig.clientId,
            "client_secret": StravaConfig.clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
        ])
        store(token)
        return token.accessToken
    }

    private func requestToken(body: [String: String]) async throws -> StravaTokenResponse {
        var request = URLRequest(url: URL(string: "https://www.strava.com/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let bodyString = String(data: data, encoding: .utf8) ?? "<unreadable body>"
            print("❌ Strava token request failed (\(http.statusCode)): \(bodyString)")
            throw StravaSyncError.apiError(status: http.statusCode, body: bodyString)
        }

        do {
            return try JSONDecoder().decode(StravaTokenResponse.self, from: data)
        } catch {
            let bodyString = String(data: data, encoding: .utf8) ?? "<unreadable body>"
            print("❌ Strava token response didn't match expected shape: \(bodyString)")
            throw StravaSyncError.apiError(status: 200, body: bodyString)
        }
    }

    private func store(_ token: StravaTokenResponse) {
        accessToken = token.accessToken
        refreshToken = token.refreshToken
        expiresAt = Date(timeIntervalSince1970: TimeInterval(token.expiresAt))
    }

    // MARK: - Syncing

    /// Pulls recent Strava runs and inserts any not already imported as
    /// WeFit workouts + running_workout_details rows.
    func syncRecentRuns(userId: UUID) async {
        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }
        do {
            let token = try await validAccessToken()
            var request = URLRequest(url: URL(string: "https://www.strava.com/api/v3/athlete/activities?per_page=15")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let bodyString = String(data: data, encoding: .utf8) ?? "<unreadable body>"
                print("❌ Strava activities request failed (\(http.statusCode)): \(bodyString)")
                throw StravaSyncError.apiError(status: http.statusCode, body: bodyString)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let activities: [StravaActivity]
            do {
                activities = try decoder.decode([StravaActivity].self, from: data)
            } catch {
                let bodyString = String(data: data, encoding: .utf8) ?? "<unreadable body>"
                print("❌ Strava activities response didn't match expected shape: \(bodyString)")
                throw StravaSyncError.apiError(status: 200, body: bodyString)
            }

            var imported = importedActivityIds
            var newlyImported = 0
            var failures: [String] = []

            for activity in activities where !imported.contains(activity.id) {
                // Each activity gets its own try/catch so one bad activity
                // (and any partial writes it made) doesn't abort the rest of
                // the sync, and doesn't get silently retried forever either -
                // mark it imported either way so it's not reattempted.
                do {
                    switch activity.type {
                    case "Run":
                        try await saveAsWorkout(activity: activity, userId: userId)
                        newlyImported += 1
                    case "WeightTraining":
                        if try await importHevyWeightTraining(activity: activity, token: token, userId: userId) {
                            newlyImported += 1
                        }
                    default:
                        continue
                    }
                    imported.insert(activity.id)
                } catch {
                    print("❌ Failed to import Strava activity \(activity.id): \(error.localizedDescription)")
                    failures.append("\(activity.id): \(error.localizedDescription)")
                    imported.insert(activity.id) // don't retry a broken activity every sync
                }
            }
            importedActivityIds = imported
            lastSyncedCount = newlyImported
            if !failures.isEmpty {
                errorMessage = "\(failures.count) activity(ies) failed to import: \(failures.joined(separator: "; "))"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveAsWorkout(activity: StravaActivity, userId: UUID) async throws {
        struct EncodableWorkout: Encodable {
            let id: String
            let user_id: String
            let workout_date: String
            let workout_type: String
            let points: Double
            let created_at: String
        }
        struct EncodableRunningDetails: Encodable {
            let workout_id: String
            let duration: String
            let distance: Double
        }

        let workoutId = UUID()
        let distanceMiles = activity.distance / 1609.34
        let points = 10.0 + Double(activity.movingTime / 600) + (distanceMiles * 2)

        let workout = EncodableWorkout(
            id: workoutId.uuidString,
            user_id: userId.uuidString,
            workout_date: ISO8601DateFormatter().string(from: activity.startDate),
            workout_type: WorkoutType.running.rawValue,
            points: points,
            created_at: ISO8601DateFormatter().string(from: Date())
        )
        try await client.from("workouts").insert([workout]).execute()

        let details = EncodableRunningDetails(
            workout_id: workoutId.uuidString,
            duration: formattedInterval(seconds: activity.movingTime),
            distance: distanceMiles
        )
        do {
            try await client.from("running_workout_details").insert([details]).execute()
        } catch {
            print("❌ running_workout_details insert failed for workout \(workoutId): \(error)")
            try? await client.from("workouts").delete().eq("id", value: workoutId.uuidString).execute()
            throw error
        }
    }

    /// Points for a Hevy-imported session: reps × 0.1 per set (weight isn't
    /// factored in - keeps heavy-lifting sessions from dwarfing everything
    /// else point-wise), plus a per-extra-exercise bonus, 20-point floor.
    /// Note: manually-logged weightlifting (WeightliftingWorkoutView) still
    /// factors in weight, so imported vs. manual entries won't score
    /// identically for the same reps - worth reconciling if that matters.
    static func weightliftingPoints(exercises: [HevyExercise]) -> Double {
        var totalPoints = 0.0
        for exercise in exercises {
            for reps in exercise.reps {
                totalPoints += Double(reps) * 0.1
            }
        }
        let exerciseCountBonus = Double(max(0, exercises.count - 1)) * 5
        return max(20, totalPoints + exerciseCountBonus)
    }

    private func formattedInterval(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    // MARK: - Hevy weight-training import

    /// Strava's activity list doesn't include `description`, so a detail
    /// fetch is needed to see whether this is a Hevy-logged session (Hevy
    /// writes "Logged with hevyapp.com" plus a per-exercise set breakdown
    /// into the description). Returns true if it imported anything.
    private func importHevyWeightTraining(activity: StravaActivity, token: String, userId: UUID) async throws -> Bool {
        var request = URLRequest(url: URL(string: "https://www.strava.com/api/v3/activities/\(activity.id)")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            // Don't fail the whole sync over one activity's detail fetch.
            print("⚠️ Couldn't fetch detail for activity \(activity.id): status \(http.statusCode)")
            return false
        }

        let detail = try? JSONDecoder().decode(StravaActivityDetail.self, from: data)
        guard let description = detail?.description, description.contains("hevyapp.com") else {
            return false
        }

        let exercises = Self.parseHevyDescription(description)
        guard !exercises.isEmpty else { return false }

        // One workout row for the whole session (WeFit's weightlifting detail
        // view only shows aggregate sets/reps/volume, so combining fits it
        // cleanly). workout_name lists every exercise; reps/weight are every
        // set from every exercise, flattened in order.
        let combinedName = exercises.map { $0.name }.joined(separator: ", ")
        let allReps = exercises.flatMap { $0.reps }
        let allWeights = exercises.flatMap { $0.weights }
        let sessionPoints = Self.weightliftingPoints(exercises: exercises)

        try await saveHevySession(
            name: combinedName,
            reps: allReps,
            weights: allWeights,
            occurredAt: activity.startDate,
            points: sessionPoints,
            userId: userId
        )
        return true
    }

    private func saveHevySession(name: String, reps: [Int], weights: [Double], occurredAt: Date, points: Double, userId: UUID) async throws {
        struct EncodableWorkout: Encodable {
            let id: String
            let user_id: String
            let workout_date: String
            let workout_type: String
            let points: Double
            let created_at: String
        }
        struct EncodableWeightliftingDetails: Encodable {
            let workout_id: String
            let workout_name: String?
            let sets: Int
            let reps: [Int]
            let weight: [Double]
        }

        let workoutId = UUID()
        let workout = EncodableWorkout(
            id: workoutId.uuidString,
            user_id: userId.uuidString,
            workout_date: ISO8601DateFormatter().string(from: occurredAt),
            workout_type: WorkoutType.weightlifting.rawValue,
            points: points,
            created_at: ISO8601DateFormatter().string(from: Date())
        )
        try await client.from("workouts").insert([workout]).execute()

        let details = EncodableWeightliftingDetails(
            workout_id: workoutId.uuidString,
            workout_name: name,
            sets: reps.count,
            reps: reps,
            weight: weights
        )
        do {
            try await client.from("weightlifting_workout_details").insert([details]).execute()
        } catch {
            // Don't leave a workout row with no details behind - roll it back
            // and log the actual Supabase error so we can see why it failed.
            print("❌ weightlifting_workout_details insert failed for workout \(workoutId): \(error)")
            try? await client.from("workouts").delete().eq("id", value: workoutId.uuidString).execute()
            throw error
        }
    }

    /// Parses Hevy's Strava description format, e.g.:
    ///   Hack Squat (Machine)
    ///   Set 1: 180 lbs x 8
    ///   Set 2: 205 lbs x 8
    ///
    ///   Pull Up
    ///   Set 1: 8 reps
    /// A quoted line between the exercise name and its sets (a per-exercise
    /// note Hevy lets you attach) is skipped.
    static func parseHevyDescription(_ description: String) -> [HevyExercise] {
        let weightedSet = try! NSRegularExpression(pattern: #"^Set\s+\d+:\s*([\d.]+)\s*lbs?\s*x\s*(\d+)$"#, options: .caseInsensitive)
        let bodyweightSet = try! NSRegularExpression(pattern: #"^Set\s+\d+:\s*(\d+)\s*reps?$"#, options: .caseInsensitive)

        var exercises: [HevyExercise] = []
        var currentName: String?
        var currentReps: [Int] = []
        var currentWeights: [Double] = []

        func flush() {
            if let name = currentName, !currentReps.isEmpty {
                exercises.append(HevyExercise(name: name, reps: currentReps, weights: currentWeights))
            }
            currentName = nil
            currentReps = []
            currentWeights = []
        }

        let lines = description
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        for line in lines {
            guard !line.isEmpty else { continue }
            if line.contains("hevyapp.com") { continue }
            if line.hasPrefix("\"") { continue } // per-exercise note

            let range = NSRange(line.startIndex..., in: line)
            if let match = weightedSet.firstMatch(in: line, range: range) {
                let weight = Double((line as NSString).substring(with: match.range(at: 1))) ?? 0
                let reps = Int((line as NSString).substring(with: match.range(at: 2))) ?? 0
                currentReps.append(reps)
                currentWeights.append(weight)
            } else if let match = bodyweightSet.firstMatch(in: line, range: range) {
                let reps = Int((line as NSString).substring(with: match.range(at: 1))) ?? 0
                currentReps.append(reps)
                currentWeights.append(0)
            } else {
                flush()
                currentName = line
            }
        }
        flush()
        return exercises
    }
}

extension StravaSyncService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

enum StravaSyncError: LocalizedError {
    case notConfigured, badAuthURL, missingCode, notConnected
    case apiError(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Strava isn't configured yet. Add your Strava API credentials to StravaConfig.swift."
        case .badAuthURL: return "Couldn't build the Strava authorization URL."
        case .missingCode: return "Strava didn't return an authorization code."
        case .notConnected: return "Strava isn't connected."
        case .apiError(let status, let body): return "Strava error (\(status)): \(body)"
        }
    }
}

private struct StravaTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
    }
}

private struct StravaActivity: Decodable {
    let id: Int
    let type: String
    let distance: Double // meters
    let movingTime: Int // seconds
    let startDate: Date

    enum CodingKeys: String, CodingKey {
        case id, type, distance
        case movingTime = "moving_time"
        case startDate = "start_date"
    }
}

/// The activity list endpoint omits `description`; only the single-activity
/// detail endpoint returns it, hence a separate decode target.
private struct StravaActivityDetail: Decodable {
    let id: Int
    let description: String?
}

struct HevyExercise: Equatable {
    let name: String
    let reps: [Int]
    let weights: [Double]
}
