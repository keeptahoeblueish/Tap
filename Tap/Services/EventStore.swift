import Foundation

final class EventStore {
    private var events: [TapEvent] = []
    private let maxEvents = 50
    var onEventsChanged: (([TapEvent]) -> Void)?

    func add(_ event: TapEvent) {
        var newEvent = event
        newEvent.status = .pending
        events.insert(newEvent, at: 0)
        if events.count > maxEvents {
            events = Array(events.prefix(maxEvents))
        }
        onEventsChanged?(events)
    }

    func resolve(eventId: String) {
        if let index = events.firstIndex(where: { $0.id == eventId }) {
            events[index].status = .dismissed
            onEventsChanged?(events)
        }
    }

    func all() -> [TapEvent] {
        events
    }
}
