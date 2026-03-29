import Foundation

final class EventStore {
    var onEventsChanged: (([TapEvent]) -> Void)?
    private(set) var events: [TapEvent] = []

    func add(_ event: TapEvent) {
        // Stub: will be implemented in Task 5
        var newEvent = event
        newEvent.isPending = true
        events.insert(newEvent, at: 0)
        onEventsChanged?(events)
    }

    func resolve(eventId: String) {
        // Stub: will be implemented in Task 5
        if let index = events.firstIndex(where: { $0.id == eventId }) {
            events[index].isPending = false
            onEventsChanged?(events)
        }
    }

    func clear() {
        // Stub: will be implemented in Task 5
        events.removeAll()
        onEventsChanged?(events)
    }
}
