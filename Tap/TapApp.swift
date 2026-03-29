import SwiftUI

@main
struct TapApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Tap", systemImage: appState.hasActiveEvents ? "bell.badge.fill" : "bell.fill") {
            MenuBarView(appState: appState)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var hasActiveEvents = false
    @Published var recentEvents: [TapEvent] = []

    let socketServer: SocketServer
    let notificationManager: NotificationManager
    let hookInstaller: HookInstaller
    let eventStore: EventStore

    init() {
        self.eventStore = EventStore()
        self.notificationManager = NotificationManager()
        self.socketServer = SocketServer()
        self.hookInstaller = HookInstaller()

        setupBindings()
        startServices()
    }

    private func setupBindings() {
        eventStore.onEventsChanged = { [weak self] events in
            Task { @MainActor in
                self?.recentEvents = events
                self?.hasActiveEvents = events.contains { $0.isPending }
            }
        }
    }

    private func startServices() {
        hookInstaller.installIfNeeded()
        notificationManager.requestPermission()
        notificationManager.registerCategories()

        socketServer.onEvent = { [weak self] event in
            self?.handleEvent(event)
        }

        notificationManager.onResponse = { [weak self] eventId, approved in
            self?.handleResponse(eventId: eventId, approved: approved)
        }

        socketServer.start()
    }

    func handleEvent(_ event: TapEvent) {
        eventStore.add(event)
        notificationManager.send(event)
    }

    func handleResponse(eventId: String, approved: Bool) {
        eventStore.resolve(eventId: eventId)
        socketServer.sendResponse(eventId: eventId, approved: approved)
    }
}
