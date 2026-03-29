import XCTest
@testable import Tap

final class SocketServerTests: XCTestCase {

    var server: SocketServer!
    var testSocketPath: String!

    private static func isRunningInCI() -> Bool {
        return ProcessInfo.processInfo.environment["CI"] != nil
            || ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil
            || ProcessInfo.processInfo.environment["CIRCLECI"] != nil
            || ProcessInfo.processInfo.environment["TRAVIS"] != nil
    }

    override func setUp() {
        super.setUp()

        // Create unique temp socket path for each test
        let tempDir = NSTemporaryDirectory()
        let uniqueName = "tap_test_\(UUID().uuidString).sock"
        testSocketPath = (tempDir as NSString).appendingPathComponent(uniqueName)

        server = SocketServer(socketPath: testSocketPath)
    }

    /// Call at the start of each test to skip in CI
    private func skipIfCI() throws {
        try XCTSkipIf(Self.isRunningInCI(), "Socket server tests skipped in CI environment")
    }

    override func tearDown() {
        server?.stop()
        try? FileManager.default.removeItem(atPath: testSocketPath)
        server = nil
        super.tearDown()
    }

    // MARK: - Server Lifecycle Tests

    func testServerStartsSuccessfully() throws {
        try skipIfCI()
        server.start()

        let expectation = XCTestExpectation(description: "Server starts within reasonable time")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            XCTAssertTrue(self.server.isRunning)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testServerCreatesSocketFile() throws {
        try skipIfCI()
        server.start()

        let expectation = XCTestExpectation(description: "Socket file exists")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            let exists = FileManager.default.fileExists(atPath: self.testSocketPath)
            XCTAssertTrue(exists, "Socket file should exist at \(self.testSocketPath)")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testServerStopsSuccessfully() throws {
        try skipIfCI()
        server.start()

        let startExpectation = XCTestExpectation(description: "Server starts")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            XCTAssertTrue(self.server.isRunning)
            self.server.stop()
            startExpectation.fulfill()
        }

        wait(for: [startExpectation], timeout: 2.0)

        let stopExpectation = XCTestExpectation(description: "Server stops")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            XCTAssertFalse(self.server.isRunning)
            stopExpectation.fulfill()
        }

        wait(for: [stopExpectation], timeout: 2.0)
    }

    func testServerCleansUpSocketFileOnStop() throws {
        try skipIfCI()
        server.start()

        let startExpectation = XCTestExpectation(description: "Server starts and socket exists")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            let exists = FileManager.default.fileExists(atPath: self.testSocketPath)
            XCTAssertTrue(exists)
            self.server.stop()
            startExpectation.fulfill()
        }

        wait(for: [startExpectation], timeout: 2.0)

        let cleanupExpectation = XCTestExpectation(description: "Socket file cleaned up")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            let exists = FileManager.default.fileExists(atPath: self.testSocketPath)
            XCTAssertFalse(exists, "Socket file should be cleaned up")
            cleanupExpectation.fulfill()
        }

        wait(for: [cleanupExpectation], timeout: 2.0)
    }

    // MARK: - Event Reception Tests

    func testServerReceivesPermissionEvent() throws {
        try skipIfCI()
        let eventExpectation = XCTestExpectation(description: "Permission event received")
        var receivedEvent: TapEvent?

        server.onEvent = { event in
            receivedEvent = event
            eventExpectation.fulfill()
        }

        server.start()

        // Wait for server to start
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            self.sendEventToServer(type: "permission", id: "evt_test_001")
        }

        wait(for: [eventExpectation], timeout: 3.0)

        XCTAssertNotNil(receivedEvent)
        XCTAssertEqual(receivedEvent?.type, .permission)
        XCTAssertEqual(receivedEvent?.id, "evt_test_001")
        XCTAssertEqual(receivedEvent?.message, "Test permission event")
    }

    func testServerReceivesCompleteEvent() throws {
        try skipIfCI()
        let eventExpectation = XCTestExpectation(description: "Complete event received")
        var receivedEvent: TapEvent?

        server.onEvent = { event in
            receivedEvent = event
            eventExpectation.fulfill()
        }

        server.start()

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            self.sendEventToServer(type: "complete", id: "evt_test_002")
        }

        wait(for: [eventExpectation], timeout: 3.0)

        XCTAssertNotNil(receivedEvent)
        XCTAssertEqual(receivedEvent?.type, .complete)
        XCTAssertEqual(receivedEvent?.id, "evt_test_002")
    }

    func testServerReceivesErrorEvent() throws {
        try skipIfCI()
        let eventExpectation = XCTestExpectation(description: "Error event received")
        var receivedEvent: TapEvent?

        server.onEvent = { event in
            receivedEvent = event
            eventExpectation.fulfill()
        }

        server.start()

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            self.sendEventToServer(type: "error", id: "evt_test_003")
        }

        wait(for: [eventExpectation], timeout: 3.0)

        XCTAssertNotNil(receivedEvent)
        XCTAssertEqual(receivedEvent?.type, .error)
    }

    func testServerReceivesBlockerEvent() throws {
        try skipIfCI()
        let eventExpectation = XCTestExpectation(description: "Blocker event received")
        var receivedEvent: TapEvent?

        server.onEvent = { event in
            receivedEvent = event
            eventExpectation.fulfill()
        }

        server.start()

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            self.sendEventToServer(type: "blocker", id: "evt_test_004")
        }

        wait(for: [eventExpectation], timeout: 3.0)

        XCTAssertNotNil(receivedEvent)
        XCTAssertEqual(receivedEvent?.type, .blocker)
    }

    // MARK: - Response Tests

    func testServerSendsApprovalResponse() throws {
        try skipIfCI()
        let eventExpectation = XCTestExpectation(description: "Event received")
        var receivedEvent: TapEvent?

        server.onEvent = { event in
            receivedEvent = event
            eventExpectation.fulfill()
        }

        server.start()

        var responseData: Data?
        let responseExpectation = XCTestExpectation(description: "Response received")

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            responseData = self.sendEventAndWaitForResponse(type: "permission", id: "evt_resp_001")
            responseExpectation.fulfill()
        }

        wait(for: [eventExpectation], timeout: 3.0)

        // Send approval response
        server.sendResponse(eventId: "evt_resp_001", approved: true)

        wait(for: [responseExpectation], timeout: 3.0)

        XCTAssertNotNil(responseData)
        if let responseData = responseData {
            let responseString = String(data: responseData, encoding: .utf8)
            XCTAssertTrue(responseString?.contains("allow") ?? false)
        }
    }

    func testServerSendsDenialResponse() throws {
        try skipIfCI()
        let eventExpectation = XCTestExpectation(description: "Event received")
        var receivedEvent: TapEvent?

        server.onEvent = { event in
            receivedEvent = event
            eventExpectation.fulfill()
        }

        server.start()

        var responseData: Data?
        let responseExpectation = XCTestExpectation(description: "Response received")

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            responseData = self.sendEventAndWaitForResponse(type: "permission", id: "evt_resp_002")
            responseExpectation.fulfill()
        }

        wait(for: [eventExpectation], timeout: 3.0)

        // Send denial response
        server.sendResponse(eventId: "evt_resp_002", approved: false)

        wait(for: [responseExpectation], timeout: 3.0)

        XCTAssertNotNil(responseData)
        if let responseData = responseData {
            let responseString = String(data: responseData, encoding: .utf8)
            XCTAssertTrue(responseString?.contains("deny") ?? false)
        }
    }

    // MARK: - Event Parsing Tests

    func testServerParsesEventWithToolInfo() throws {
        try skipIfCI()
        let eventExpectation = XCTestExpectation(description: "Event with tool info received")
        var receivedEvent: TapEvent?

        server.onEvent = { event in
            receivedEvent = event
            eventExpectation.fulfill()
        }

        server.start()

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            let json = """
            {
                "type": "permission",
                "id": "evt_tool_001",
                "tool_name": "Bash",
                "tool_input": "git push origin main",
                "message": "Claude wants to run: git push origin main",
                "timestamp": 1711700000
            }
            """
            self.sendRawJSONToServer(json)
        }

        wait(for: [eventExpectation], timeout: 3.0)

        XCTAssertNotNil(receivedEvent)
        XCTAssertEqual(receivedEvent?.toolName, "Bash")
        XCTAssertEqual(receivedEvent?.toolInput, "git push origin main")
    }

    func testServerHandlesMultipleConnections() throws {
        try skipIfCI()
        let event1Expectation = XCTestExpectation(description: "First event received")
        let event2Expectation = XCTestExpectation(description: "Second event received")
        var receivedEvents: [TapEvent] = []

        server.onEvent = { event in
            receivedEvents.append(event)
            if receivedEvents.count == 1 {
                event1Expectation.fulfill()
            } else if receivedEvents.count == 2 {
                event2Expectation.fulfill()
            }
        }

        server.start()

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            self.sendEventToServer(type: "complete", id: "evt_multi_001")
        }

        wait(for: [event1Expectation], timeout: 3.0)

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            self.sendEventToServer(type: "complete", id: "evt_multi_002")
        }

        wait(for: [event2Expectation], timeout: 3.0)

        XCTAssertEqual(receivedEvents.count, 2)
        XCTAssertEqual(receivedEvents[0].id, "evt_multi_001")
        XCTAssertEqual(receivedEvents[1].id, "evt_multi_002")
    }

    // MARK: - Helper Methods

    private func sendEventToServer(type: String, id: String) {
        let json = """
        {
            "type": "\(type)",
            "id": "\(id)",
            "message": "Test \(type) event",
            "timestamp": \(Date().timeIntervalSince1970)
        }
        """
        sendRawJSONToServer(json)
    }

    private func sendRawJSONToServer(_ json: String) {
        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else {
            XCTFail("Failed to create client socket")
            return
        }

        defer { close(sock) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let socketPathBytes = testSocketPath.utf8CString
        _ = socketPathBytes.withUnsafeBytes { buffer in
            memcpy(&addr.sun_path, buffer.baseAddress!, min(buffer.count, 104))
        }

        let result = withUnsafePointer(to: &addr) { ptr -> Int32 in
            return connect(sock, UnsafeRawPointer(ptr).assumingMemoryBound(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_un>.size))
        }

        guard result == 0 else {
            XCTFail("Failed to connect to socket")
            return
        }

        if let data = json.data(using: .utf8) {
            let buffer = [UInt8](data)
            _ = write(sock, buffer, buffer.count)
        }
    }

    private func sendEventAndWaitForResponse(type: String, id: String) -> Data? {
        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else {
            XCTFail("Failed to create client socket")
            return nil
        }

        defer { close(sock) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let socketPathBytes = testSocketPath.utf8CString
        _ = socketPathBytes.withUnsafeBytes { buffer in
            memcpy(&addr.sun_path, buffer.baseAddress!, min(buffer.count, 104))
        }

        let result = withUnsafePointer(to: &addr) { ptr -> Int32 in
            return connect(sock, UnsafeRawPointer(ptr).assumingMemoryBound(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_un>.size))
        }

        guard result == 0 else {
            XCTFail("Failed to connect to socket")
            return nil
        }

        // Send event
        let json = """
        {
            "type": "\(type)",
            "id": "\(id)",
            "message": "Test \(type) event",
            "timestamp": \(Date().timeIntervalSince1970)
        }
        """

        if let data = json.data(using: .utf8) {
            let buffer = [UInt8](data)
            _ = write(sock, buffer, buffer.count)
        }

        // Read response
        var responseBuffer = [UInt8](repeating: 0, count: 1024)
        let bytesRead = read(sock, &responseBuffer, responseBuffer.count)

        if bytesRead > 0 {
            return Data(bytes: responseBuffer, count: Int(bytesRead))
        }

        return nil
    }
}
