import Testing
import SwiftData
import Foundation
@testable import Logbook

// MARK: - Helpers

@MainActor
private func makeTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: Project.self, Task.self, TimeEntry.self,
                              configurations: config)
}

// MARK: - TimerEngine Tests

@Suite("TimerEngine")
@MainActor
struct TimerEngineTests {

    let container: ModelContainer
    let context: ModelContext
    let project: Project
    let task: Task

    init() throws {
        container = try makeTestContainer()
        context = container.mainContext
        project = Project(name: "Design", colorHex: "#4F8EF7", clientName: "Acme")
        context.insert(project)
        task = Task(name: "Logo", project: project)
        context.insert(task)
        try context.save()
    }

    // MARK: start(task:)

    @Test("start creates a running entry")
    func startCreatesRunningEntry() throws {
        let engine = TimerEngine(modelContext: context)
        engine.start(task: task)

        #expect(engine.isRunning)
        let entry = try #require(engine.runningEntry)
        #expect(entry.end == nil)
    }

    @Test("start links entry to task and project")
    func startLinksEntryToTaskAndProject() throws {
        let engine = TimerEngine(modelContext: context)
        engine.start(task: task)

        let entry = try #require(engine.runningEntry)
        #expect(entry.task?.persistentModelID == task.persistentModelID)
        #expect(entry.project?.persistentModelID == project.persistentModelID)
    }

    @Test("start marks entry source as timer")
    func startSetsSourceToTimer() throws {
        let engine = TimerEngine(modelContext: context)
        engine.start(task: task)

        let entry = try #require(engine.runningEntry)
        #expect(entry.source == .timer)
    }

    @Test("start while running stops previous entry first")
    func startStopsPreviousEntry() throws {
        let task2 = Task(name: "Revisions", project: project)
        context.insert(task2)
        try context.save()

        let engine = TimerEngine(modelContext: context)
        engine.start(task: task)
        let first = try #require(engine.runningEntry)

        engine.start(task: task2)

        #expect(first.end != nil, "previous entry must be stopped")
        #expect(engine.runningEntry?.task?.persistentModelID == task2.persistentModelID)
    }

    @Test("starting does not create more than one open entry")
    func noTwoRunningEntries() throws {
        let task2 = Task(name: "Revisions", project: project)
        context.insert(task2)
        try context.save()

        let engine = TimerEngine(modelContext: context)
        engine.start(task: task)
        engine.start(task: task2)

        let descriptor = FetchDescriptor<TimeEntry>()
        let all = try context.fetch(descriptor)
        let open = all.filter { $0.end == nil }
        #expect(open.count == 1)
    }

    // MARK: stop()

    @Test("stop sets end date on running entry")
    func stopSetsEndDate() throws {
        let engine = TimerEngine(modelContext: context)
        engine.start(task: task)
        let entry = try #require(engine.runningEntry)

        engine.stop()

        #expect(entry.end != nil)
        #expect(engine.runningEntry == nil)
        #expect(!engine.isRunning)
    }

    @Test("stop is a no-op when nothing is running")
    func stopWhenIdleDoesNothing() {
        let engine = TimerEngine(modelContext: context)
        engine.stop() // must not crash
        #expect(!engine.isRunning)
    }

    @Test("stop persists the end date")
    func stopPersistsEndDate() throws {
        let engine = TimerEngine(modelContext: context)
        engine.start(task: task)
        let entry = try #require(engine.runningEntry)
        engine.stop()

        let fetched = try context.fetch(FetchDescriptor<TimeEntry>())
        let stopped = try #require(fetched.first { $0.persistentModelID == entry.persistentModelID })
        #expect(stopped.end != nil)
    }

    // MARK: toggle(task:)

    @Test("toggle starts timer when idle")
    func toggleStartsWhenIdle() throws {
        let engine = TimerEngine(modelContext: context)
        engine.toggle(task: task)

        #expect(engine.isRunning)
        #expect(engine.runningEntry?.task?.persistentModelID == task.persistentModelID)
    }

    @Test("toggle stops timer when same task is running")
    func toggleStopsSameTask() throws {
        let engine = TimerEngine(modelContext: context)
        engine.start(task: task)
        engine.toggle(task: task)

        #expect(!engine.isRunning)
    }

    @Test("toggle switches to a different task")
    func toggleSwitchesTasks() throws {
        let task2 = Task(name: "Client Calls", project: project)
        context.insert(task2)
        try context.save()

        let engine = TimerEngine(modelContext: context)
        engine.start(task: task)
        engine.toggle(task: task2)

        #expect(engine.isRunning)
        #expect(engine.runningEntry?.task?.persistentModelID == task2.persistentModelID)
    }

    // MARK: resumeRunningEntry()

    @Test("init resumes a previously running entry")
    func resumeRunningEntry() throws {
        // Simulate an entry left open (e.g. app crash / force quit)
        let orphan = TimeEntry(start: Date().addingTimeInterval(-300),
                               project: project,
                               task: task,
                               source: .timer)
        context.insert(orphan)
        try context.save()

        let engine = TimerEngine(modelContext: context)

        #expect(engine.isRunning)
        #expect(engine.runningEntry?.persistentModelID == orphan.persistentModelID)
    }

    @Test("init picks the most recent running entry if multiple exist")
    func resumePicksMostRecent() throws {
        let older = TimeEntry(start: Date().addingTimeInterval(-600),
                              project: project, task: task, source: .timer)
        let newer = TimeEntry(start: Date().addingTimeInterval(-60),
                              project: project, task: task, source: .timer)
        context.insert(older)
        context.insert(newer)
        try context.save()

        let engine = TimerEngine(modelContext: context)

        #expect(engine.runningEntry?.persistentModelID == newer.persistentModelID)
    }

    @Test("init does not resume a completed entry")
    func doesNotResumeCompletedEntry() throws {
        let completed = TimeEntry(start: Date().addingTimeInterval(-300),
                                  end: Date().addingTimeInterval(-60),
                                  project: project, task: task, source: .timer)
        context.insert(completed)
        try context.save()

        let engine = TimerEngine(modelContext: context)

        #expect(!engine.isRunning)
    }
}
