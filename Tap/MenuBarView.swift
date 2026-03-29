import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState

    private var pendingCount: Int {
        appState.recentEvents.filter(\.isPending).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
                Text("Tap")
                    .font(.system(size: 14, weight: .bold))
                if pendingCount > 0 {
                    Text("\(pendingCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.orange))
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(appState.socketServer.isRunning ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(appState.socketServer.isRunning ? "Listening" : "Offline")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Events
            if appState.recentEvents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No recent events")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Tap will notify you when Claude\nneeds your attention")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(appState.recentEvents) { event in
                            EventRow(event: event) { approved in
                                appState.handleResponse(eventId: event.id, approved: approved)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 320)
            }

            Divider()

            // Footer
            HStack(spacing: 0) {
                Button(action: { appState.hookInstaller.install() }) {
                    Label("Reinstall Hooks", systemImage: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)

                Spacer()

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("Quit")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
        }
        .frame(width: 340)
    }
}

struct EventRow: View {
    let event: TapEvent
    let onResponse: (Bool) -> Void

    private var isResolved: Bool {
        event.status == .approved || event.status == .denied || event.status == .dismissed
    }

    private var statusIcon: String {
        switch event.status {
        case .approved: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .dismissed: return "minus.circle.fill"
        case .pending:
            switch event.type {
            case .permission: return "lock.fill"
            case .blocker: return "hand.raised.fill"
            case .complete: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
    }

    private var statusColor: Color {
        switch event.status {
        case .approved: return .green
        case .denied: return .red
        case .dismissed: return .gray
        case .pending: return event.type.color
        }
    }

    private var statusLabel: String {
        switch event.status {
        case .approved: return "Approved"
        case .denied: return "Denied"
        case .dismissed: return "Dismissed"
        case .pending: return event.type.label
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header row
            HStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .font(.system(size: 10))
                    .foregroundColor(statusColor)
                Text(statusLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isResolved ? .secondary : .primary)
                Spacer()
                Text(event.timeAgo)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Message
            Text(event.message)
                .font(.system(size: 12))
                .foregroundColor(isResolved ? .secondary : .primary)
                .lineLimit(2)

            // Action buttons (only for pending permission requests)
            if event.type == .permission && event.isPending {
                HStack(spacing: 8) {
                    Button(action: { onResponse(true) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                            Text("Approve")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)

                    Button(action: { onResponse(false) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                            Text("Deny")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(event.isPending ? Color.accentColor.opacity(0.06) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(event.isPending ? Color.accentColor.opacity(0.15) : Color.clear, lineWidth: 1)
        )
        .opacity(isResolved ? 0.6 : 1.0)
    }
}
