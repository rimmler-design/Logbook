import SwiftUI
import SwiftData
import AppKit

struct MenuBarView: View {
    @Environment(TimerEngine.self) private var timer
    @Environment(\.openWindow) private var openWindow
    @State private var showingAssign = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let entry = timer.runningEntry {
                runningView(entry)
            } else {
                idleView
            }
            Divider()
            footer
        }
        .frame(width: 280)
        .sheet(isPresented: $showingAssign) { AssignTimerView() }
    }

    private func runningView(_ entry: TimeEntry) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(entry.project == nil ? Color.orange : Color(hex: entry.project!.colorHex))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                if entry.project == nil {
                    Text("Unassigned timer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.orange)
                } else if let task = entry.task {
                    Text(task.name)
                        .font(.system(size: 13, weight: .semibold))
                    Text(entry.project?.name ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text(entry.project?.name ?? "")
                        .font(.system(size: 13, weight: .semibold))
                }
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(TimeFormat.hms(entry.duration))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if entry.project == nil {
                Button("Assign") { showingAssign = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            Button { timer.stop() } label: {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var idleView: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .foregroundStyle(.secondary)
            Text("No timer running")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
    }

    private var footer: some View {
        HStack {
            Button("Open Logbook") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
