import Foundation

struct TapEvent: Identifiable {
    let id: String
    let type: EventType
    let message: String
    let timestamp: Date
    var isPending: Bool

    enum EventType: String, Codable {
        case permission
        case execution
        case error

        var label: String {
            switch self {
            case .permission: "Permission"
            case .execution: "Execution"
            case .error: "Error"
            }
        }

        var color: String {
            switch self {
            case .permission: "#FF9500" // orange
            case .execution: "#34C759" // green
            case .error: "#FF3B30" // red
            }
        }
    }

    var timeAgo: String {
        let interval = Date.now.timeIntervalSince(timestamp)
        switch interval {
        case ..<60:
            return "now"
        case ..<3600:
            let minutes = Int(interval) / 60
            return "\(minutes)m ago"
        case ..<86400:
            let hours = Int(interval) / 3600
            return "\(hours)h ago"
        default:
            let days = Int(interval) / 86400
            return "\(days)d ago"
        }
    }
}
