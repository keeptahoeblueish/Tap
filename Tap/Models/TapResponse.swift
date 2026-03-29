import Foundation

struct TapResponse: Codable {
    let eventId: String
    let approved: Bool

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case approved
    }
}
