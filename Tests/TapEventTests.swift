import XCTest
@testable import Tap

final class TapEventTests: XCTestCase {

    func testParsePermissionEvent() throws {
        let json = """
        {
            "type": "permission",
            "id": "evt_001",
            "tool_name": "Bash",
            "tool_input": "git push origin main",
            "message": "Claude wants to run: git push origin main",
            "timestamp": 1711700000
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(TapEvent.self, from: json)
        XCTAssertEqual(event.type, .permission)
        XCTAssertEqual(event.id, "evt_001")
        XCTAssertEqual(event.toolName, "Bash")
        XCTAssertEqual(event.message, "Claude wants to run: git push origin main")
        XCTAssertTrue(event.isPending)
    }

    func testParseCompletionEvent() throws {
        let json = """
        {
            "type": "complete",
            "id": "evt_002",
            "message": "Task finished: deployed to preview",
            "timestamp": 1711700100
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(TapEvent.self, from: json)
        XCTAssertEqual(event.type, .complete)
        XCTAssertFalse(event.isPending)
    }

    func testParseErrorEvent() throws {
        let json = """
        {
            "type": "error",
            "id": "evt_003",
            "message": "Build failed: TypeScript error in server/index.ts",
            "timestamp": 1711700200
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(TapEvent.self, from: json)
        XCTAssertEqual(event.type, .error)
    }

    func testParseBlockerEvent() throws {
        let json = """
        {
            "type": "blocker",
            "id": "evt_004",
            "message": "Claude needs you to log in to Railway in the browser",
            "timestamp": 1711700300
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(TapEvent.self, from: json)
        XCTAssertEqual(event.type, .blocker)
    }

    func testResponseEncode() throws {
        let response = TapResponse(eventId: "evt_001", approved: true)
        let data = try JSONEncoder().encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["event_id"] as? String, "evt_001")
        XCTAssertEqual(json["approved"] as? Bool, true)
    }
}
