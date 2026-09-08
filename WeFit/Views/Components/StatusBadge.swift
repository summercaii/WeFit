import SwiftUI

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColorForStatus)
            .foregroundColor(foregroundColorForStatus)
            .cornerRadius(4)
    }
    
    private var backgroundColorForStatus: Color {
        switch status.lowercased() {
        case "completed":
            return .green.opacity(0.1)
        case "in_progress":
            return .blue.opacity(0.1)
        case "active":
            return .green.opacity(0.1)
        case "paused":
            return .orange.opacity(0.1)
        case "cancelled":
            return .red.opacity(0.1)
        default:
            return .gray.opacity(0.1)
        }
    }
    
    private var foregroundColorForStatus: Color {
        switch status.lowercased() {
        case "completed":
            return .green
        case "in_progress":
            return .blue
        case "active":
            return .green
        case "paused":
            return .orange
        case "cancelled":
            return .red
        default:
            return .gray
        }
    }
} 