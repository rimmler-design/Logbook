import Foundation
import SwiftData
import Observation

@Observable
final class TimerEngine {
    private let modelContext: ModelContext

    var runningEntry: TimeEntry?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        resumeRunningEntry()
    }

    var isRunning: Bool { runningEntry != nil }

    /// On launch, pick up any entry left running (end == nil).
    private func resumeRunningEntry() {
        let descriptor = FetchDescriptor<TimeEntry>(
            sortBy: [SortDescriptor(\.start, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        runningEntry = all.first { $0.end == nil }
    }

    func start(task: Task) {
        stop() // never allow two running entries
        let entry = TimeEntry(start: Date(), project: task.project, task: task, source: .timer)
        modelContext.insert(entry)
        runningEntry = entry
        save()
    }

    func startGeneral() {
        stop()
        let entry = TimeEntry(start: Date(), project: nil, task: nil, source: .timer)
        modelContext.insert(entry)
        runningEntry = entry
        save()
    }

    func startProject(_ project: Project) {
        stop()
        let entry = TimeEntry(start: Date(), project: project, task: nil, source: .timer)
        modelContext.insert(entry)
        runningEntry = entry
        save()
    }

    func assign(project: Project, task: Task? = nil) {
        guard let entry = runningEntry else { return }
        entry.project = project
        entry.task = task
        save()
        runningEntry = entry  // re-assign to propagate Observable tracking
    }

    var isRunningUnassigned: Bool {
        runningEntry?.project == nil && isRunning
    }

    func stop() {
        guard let entry = runningEntry else { return }
        entry.end = Date()
        runningEntry = nil
        save()
    }

    /// Tapping the running task stops it; tapping any other task switches to it.
    func toggle(task: Task) {
        if let running = runningEntry,
           running.task?.persistentModelID == task.persistentModelID {
            stop()
        } else {
            start(task: task)
        }
    }

    func isRunningProject(_ project: Project) -> Bool {
        guard let entry = runningEntry else { return false }
        return entry.project?.persistentModelID == project.persistentModelID && entry.task == nil
    }

    func toggleProject(_ project: Project) {
        isRunningProject(project) ? stop() : startProject(project)
    }

    private func save() {
        do { try modelContext.save() }
        catch { print("TimerEngine save error: \(error)") }
    }
}
