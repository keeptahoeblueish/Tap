import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.accentColor)
                Text("Tap")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(appState.socketServer.isRunning ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(appState.socketServer.isRunning ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if appState.recentEvents.isEmpty {
                Text("No recent events")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(12)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(appState.recentEvents) { event in
                            EventRow(event: event) { approved in
                                appState.handleResponse(eventId: event.id, approved: approved)
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 300)
            }

            Divider()

            Button("Reinstall Hooks") {
                appState.hookInstaller.install()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Button("Quit Tap") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .padding(.bottom, 4)
        }
        .frame(width: 320)
    }
}

struct EventRow: View {
    let event: TapEvent
    let onResponse: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(event.type.color)
                    .frame(width: 8, height: 8)
                Text(event.type.label)
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text(event.timeAgo)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(event.message)
                .font(.subheadline)
                .lineLimit(2)

            if event.type == .permission && event.isPending {
                HStack(spacing: 8) {
                    Button("Approve") { onResponse(true) }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.small)
                    Button("Deny") { onResponse(false) }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .controlSize(.small)
                }
                .padding(.top, 2)
            }
        }
        .padding(8)
        .background(event.isPending ? Color.accentColor.opacity(0.05) : Color.clear)
        .cornerRadius(6)
    }
}
