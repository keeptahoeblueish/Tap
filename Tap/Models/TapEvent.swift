import SwiftUI

struct TapEvent: Codable, Identifiable {
    let type: EventType
    let id: String
    let toolName: String?
    let toolInput: String?
    let message: String
    let timestamp: TimeInterval
    var status: Status = .pending

    enum EventType: String, Codable {
        case permission
        case blocker
        case complete
        case error

        var label: String {
            switch self {
            case .permission: return "Permission"
            case .blocker: return "Blocker"
            case .complete: return "Complete"
            case .error: return "Error"
            }
        }

        var color: Color {
            switch self {
            case .permission: return .orange
            case .blocker: return .blue
            case .complete: return .green
            case .error: return .red
            }
        }
    }

    enum Status: String, Codable {
        case pending
        case approved
        case denied
        case dismissed
    }

    var isPending: Bool {
        type == .permission && status == .pending
    }

    var timeAgo: String {
        let elapsed = Date().timeIntervalSince1970 - timestamp
        if elapsed < 60 { return "just now" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m ago" }
        return "\(Int(elapsed / 3600))h ago"
    }

    enum CodingKeys: String, CodingKey {
        case type, id, message, timestamp, status
        case toolName = "tool_name"
        case toolInput = "tool_input"
    }
}
