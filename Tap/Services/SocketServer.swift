import Foundation
import Combine

final class SocketServer: ObservableObject {
    @Published var isRunning = false
    var onEvent: ((TapEvent) -> Void)?

    private let socketPath: String
    private var serverSocket: Int32 = -1
    private let acceptQueue = DispatchQueue(label: "com.tap.socket.accept", qos: .userInitiated)
    private let responseQueue = DispatchQueue(label: "com.tap.socket.response", qos: .userInitiated)
    private var pendingConnections: [String: PendingConnection] = [:]
    private let pendingLock = NSLock()

    private struct PendingConnection {
        let clientSocket: Int32
        let semaphore: DispatchSemaphore
        var response: String?
    }

    init(socketPath: String = defaultSocketPath()) {
        self.socketPath = socketPath
    }

    static func defaultSocketPath() -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let tapDir = appSupport.appendingPathComponent("Tap")
        return tapDir.appendingPathComponent("tap.sock").path
    }

    func start() {
        guard !isRunning else { return }

        acceptQueue.async { [weak self] in
            self?.setupAndRun()
        }
    }

    func stop() {
        guard isRunning else { return }

        DispatchQueue.main.async {
            self.isRunning = false
        }

        responseQueue.async { [weak self] in
            self?.cleanup()
        }
    }

    func sendResponse(eventId: String, approved: Bool) {
        responseQueue.async { [weak self] in
            self?.handleResponse(eventId: eventId, approved: approved)
        }
    }

    // MARK: - Private

    private func setupAndRun() {
        // Create application support directory if needed
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let tapDir = appSupport.appendingPathComponent("Tap")
        try? FileManager.default.createDirectory(at: tapDir, withIntermediateDirectories: true)

        // Remove stale socket file
        try? FileManager.default.removeItem(atPath: socketPath)

        // Create Unix domain socket
        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            print("SocketServer: Failed to create socket")
            return
        }

        // Set socket options
        var reuseAddr: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))

        // Bind socket
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let socketPathBytes = socketPath.utf8CString
        _ = socketPathBytes.withUnsafeBytes { buffer in
            memcpy(&addr.sun_path, buffer.baseAddress!, min(buffer.count, 104))
        }

        let result = withUnsafePointer(to: &addr) { ptr -> Int32 in
            return bind(serverSocket, UnsafeRawPointer(ptr).assumingMemoryBound(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_un>.size))
        }

        guard result == 0 else {
            print("SocketServer: Failed to bind socket: \(errno)")
            close(serverSocket)
            return
        }

        // Listen for connections
        guard listen(serverSocket, 5) == 0 else {
            print("SocketServer: Failed to listen")
            close(serverSocket)
            return
        }

        DispatchQueue.main.async {
            self.isRunning = true
        }

        // Accept loop
        while isRunning {
            var clientAddr = sockaddr_un()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) { addrPtr -> Int32 in
                return accept(serverSocket, UnsafeMutableRawPointer(addrPtr).assumingMemoryBound(to: sockaddr.self), &clientAddrLen)
            }

            if clientSocket >= 0 {
                responseQueue.async { [weak self] in
                    self?.handleConnection(clientSocket: clientSocket)
                }
            } else {
                // Avoid busy-loop on accept errors
                usleep(100)
            }
        }

        cleanup()
    }

    private func handleConnection(clientSocket: Int32) {
        // Read newline-delimited JSON
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(clientSocket, &buffer, buffer.count)

        guard bytesRead > 0 else {
            close(clientSocket)
            return
        }

        let data = Data(bytes: buffer, count: Int(bytesRead))
        guard let jsonString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            close(clientSocket)
            return
        }

        // Parse event
        guard let eventData = jsonString.data(using: .utf8) else {
            close(clientSocket)
            return
        }

        do {
            let event = try JSONDecoder().decode(TapEvent.self, from: eventData)

            // Notify on main thread
            DispatchQueue.main.async {
                self.onEvent?(event)
            }

            // If permission event, block until response
            if event.type == .permission {
                let semaphore = DispatchSemaphore(value: 0)

                pendingLock.lock()
                pendingConnections[event.id] = PendingConnection(clientSocket: clientSocket, semaphore: semaphore, response: nil)
                pendingLock.unlock()

                // Wait up to 5 minutes for response
                _ = semaphore.wait(timeout: .now() + 300)

                pendingLock.lock()
                let connection = pendingConnections.removeValue(forKey: event.id)
                pendingLock.unlock()

                if let connection = connection, let response = connection.response {
                    _ = write(connection.clientSocket, response, response.count)
                } else {
                    // Timeout
                    let timeoutResponse = "{\"decision\":\"deny\",\"reason\":\"timeout\"}"
                    _ = write(clientSocket, timeoutResponse, timeoutResponse.count)
                }

                close(clientSocket)
            } else {
                // Non-permission events: respond immediately and close
                close(clientSocket)
            }
        } catch {
            print("SocketServer: Failed to parse event: \(error)")
            close(clientSocket)
        }
    }

    private func handleResponse(eventId: String, approved: Bool) {
        let decision = approved ? "allow" : "deny"
        let responseJSON = "{\"decision\":\"\(decision)\"}"

        pendingLock.lock()
        defer { pendingLock.unlock() }

        if var connection = pendingConnections[eventId] {
            connection.response = responseJSON
            pendingConnections[eventId] = connection
            connection.semaphore.signal()
        }
    }

    private func cleanup() {
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
        try? FileManager.default.removeItem(atPath: socketPath)
    }
}
