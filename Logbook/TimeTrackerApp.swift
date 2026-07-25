import SwiftUI
import SwiftData

@main
struct TimeTrackerApp: App {
    let container: ModelContainer
    @State private var timerEngine: TimerEngine

    init() {
        do {
            let container = try ModelContainer(for: Project.self, Task.self, TimeEntry.self)
            self.container = container
            _timerEngine = State(initialValue: TimerEngine(modelContext: container.mainContext))
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(timerEngine)
        } label: {
            Image(systemName: timerEngine.isRunning ? "timer.circle.fill" : "timer")
        }
        .menuBarExtraStyle(.window)
        .modelContainer(container)

        Window("Logbook", id: "main") {
            MainView()
                .environment(timerEngine)
        }
        .defaultLaunchBehavior(.presented)
        .modelContainer(container)
    }
}
