import Foundation
import Supabase

struct DatabaseManager {
    static let supabaseURL = "https://vqurobjkazktguvtzive.supabase.co"
    static let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxdXJvYmprYXprdGd1dnR6aXZlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk4MzIyMjYsImV4cCI6MjA1NTQwODIyNn0.5dUxDyi2HlfKhdxThXkZCIFVYs-HOmqIjtKp1y-9IDU"

    static let client = SupabaseClient(
        supabaseURL: URL(string: supabaseURL)!,
        supabaseKey: supabaseKey
    )
    
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try multiple ISO8601 formatters with different configurations
            let formatters = [
                // Full format with fractional seconds and timezone
                { () -> ISO8601DateFormatter in
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
                    return formatter
                }(),
                // With timezone but no fractional seconds
                { () -> ISO8601DateFormatter in
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
                    return formatter
                }(),
                // Basic format without timezone or fractional seconds
                { () -> ISO8601DateFormatter in
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime]
                    return formatter
                }()
            ]
            
            // Try each formatter
            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            // Fallback: try to parse manually if ISO8601DateFormatter fails
            // Handle cases with excessive fractional seconds
            let modifiedDateString = dateString.replacingOccurrences(
                of: #"(\.\d{3})\d*(\+\d{2}:\d{2}|Z)$"#,
                with: "$1$2",
                options: .regularExpression
            )
            
            if modifiedDateString != dateString {
                // Try again with truncated fractional seconds
                for formatter in formatters {
                    if let date = formatter.date(from: modifiedDateString) {
                        return date
                    }
                }
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        return decoder
    }()
} 