import Foundation
import Supabase

class WorkoutService {
    // Reference to your Supabase client
    private let client = DatabaseManager.client
    
    // Fetch recent workouts for a user
    func fetchRecentWorkouts(userId: String, limit: Int = 5) async throws -> [Workout] {
        print("🔍 WorkoutService: Fetching workouts for user_id: \(userId), limit: \(limit)")
        
        let response = try await client
            .from("workouts")
            .select()
            .eq("user_id", value: userId)
            .order("workout_date", ascending: false)
            .limit(limit)
            .execute()
        
        print("📊 Database response status: \(response.status)")
        print("📊 Database response count: \(response.count ?? 0)")
        
        // Log raw response data to see actual format
        if let jsonString = String(data: response.data, encoding: .utf8) {
            print("📋 Raw response data: \(jsonString)")
        }
        
        let decoder = JSONDecoder()
        // Custom date decoder that handles both formats
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try format with microseconds first (users table)
            let formatterWithMicroseconds = DateFormatter()
            formatterWithMicroseconds.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
            if let date = formatterWithMicroseconds.date(from: dateString) {
                return date
            }
            
            // Fall back to format without microseconds (workouts table)
            let formatterNoMicroseconds = DateFormatter()
            formatterNoMicroseconds.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            if let date = formatterNoMicroseconds.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode date string \(dateString)")
            )
        }
        
        print("🔄 Attempting to decode \(response.count ?? 0) workout records...")
        let workouts = try decoder.decode([Workout].self, from: response.data)
        print("✅ Successfully decoded \(workouts.count) workouts")
        
        return workouts
    }
    
    // Save a new workout
    func saveWorkout(workout: Workout) async throws {
        // Create an encodable struct for the workout
        struct EncodableWorkout: Encodable {
            let id: String
            let user_id: String
            let workout_date: String
            let workout_type: String
            let points: Double
            let created_at: String
        }
        
        let encodableWorkout = EncodableWorkout(
            id: workout.id.uuidString,
            user_id: workout.user_id.uuidString,
            workout_date: ISO8601DateFormatter().string(from: workout.workout_date),
            workout_type: workout.workout_type.rawValue,
            points: workout.points,
            created_at: ISO8601DateFormatter().string(from: workout.created_at)
        )
        
        _ = try await client
            .from("workouts")
            .insert([encodableWorkout])
            .execute()
    }
    
    // Save running workout details
    func saveRunningWorkoutDetails<T: Encodable>(details: T) async throws {
        _ = try await client
            .from("running_workout_details")
            .insert([details])
            .execute()
    }
    
    // Save basketball workout details
    func saveBasketballWorkoutDetails<T: Encodable>(details: T) async throws {
        _ = try await client
            .from("basketball_workout_details")
            .insert([details])
            .execute()
    }
    
    // Save weightlifting workout details
    func saveWeightliftingWorkoutDetails<T: Encodable>(details: T) async throws {
        _ = try await client
            .from("weightlifting_workout_details")
            .insert([details])
            .execute()
    }
    
    // Save individual exercises for weightlifting workouts
    func saveExercise<T: Encodable>(exercise: T) async throws {
        _ = try await client
            .from("exercises")
            .insert([exercise])
            .execute()
    }
    
    // Fetch detailed workout information
    func fetchWorkoutDetails(workoutId: String) async throws -> Workout? {
        print("🔍 WorkoutService: Fetching detailed workout for ID: \(workoutId)")
        
        // First, fetch the base workout
        let workoutResponse = try await client
            .from("workouts")
            .select()
            .eq("id", value: workoutId)
            .execute()
        
        let workouts = try DatabaseManager.decoder.decode([Workout].self, from: workoutResponse.data)
        guard var workout = workouts.first else {
            print("❌ No workout found with ID: \(workoutId)")
            return nil
        }
        
        // Fetch details based on workout type
        switch workout.workout_type {
        case .basketball:
            workout.basketballDetails = try await fetchBasketballDetails(workoutId: workoutId)
        case .running:
            workout.runningDetails = try await fetchRunningDetails(workoutId: workoutId)
        case .weightlifting:
            workout.weightliftingDetails = try await fetchWeightliftingDetails(workoutId: workoutId)
        }
        
        print("✅ Successfully fetched detailed workout data")
        return workout
    }
    
    // Fetch basketball workout details
    private func fetchBasketballDetails(workoutId: String) async throws -> BasketballWorkoutDetails? {
        let response = try await client
            .from("basketball_workout_details")
            .select()
            .eq("workout_id", value: workoutId)
            .execute()
        
        let details = try DatabaseManager.decoder.decode([BasketballWorkoutDetails].self, from: response.data)
        return details.first
    }
    
    // Fetch running workout details
    private func fetchRunningDetails(workoutId: String) async throws -> RunningWorkoutDetails? {
        let response = try await client
            .from("running_workout_details")
            .select()
            .eq("workout_id", value: workoutId)
            .execute()
        
        let details = try DatabaseManager.decoder.decode([RunningWorkoutDetails].self, from: response.data)
        return details.first
    }
    
    // Fetch weightlifting workout details
    private func fetchWeightliftingDetails(workoutId: String) async throws -> WeightliftingWorkoutDetails? {
        let response = try await client
            .from("weightlifting_workout_details")
            .select()
            .eq("workout_id", value: workoutId)
            .execute()
        
        let details = try DatabaseManager.decoder.decode([WeightliftingWorkoutDetails].self, from: response.data)
        return details.first
    }
} 