import Foundation
import Combine

final class SocketServer: ObservableObject {
    @Published var isRunning = false
    var onEvent: ((TapEvent) -> Void)?

    func start() {
        // Stub: will be implemented in Task 3
        isRunning = true
    }

    func stop() {
        // Stub: will be implemented in Task 3
        isRunning = false
    }

    func sendResponse(eventId: String, approved: Bool) {
        // Stub: will be implemented in Task 3
    }
}
