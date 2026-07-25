import Testing
import SwiftData
import Foundation
@testable import Logbook

// MARK: - TimeEntry Tests

@Suite("TimeEntry")
struct TimeEntryTests {

    // MARK: duration

    @Test("duration of a running entry grows over time")
    func durationOfRunningEntry() {
        let start = Date().addingTimeInterval(-120) // started 2 minutes ago
        let entry = TimeEntry(start: start, project: nil)

        let duration = entry.duration
        #expect(duration >= 120)
        #expect(duration < 125) // allow a little slack for test execution time
    }

    @Test("duration of a completed entry is fixed")
    func durationOfCompletedEntry() {
        let start = Date().addingTimeInterval(-3600)
        let end   = Date().addingTimeInterval(-1800)
        let entry = TimeEntry(start: start, end: end, project: nil)

        #expect(entry.duration == end.timeIntervalSince(start))
        #expect(entry.duration == 1800)
    }

    @Test("duration is zero when start equals end")
    func durationZero() {
        let now = Date()
        let entry = TimeEntry(start: now, end: now, project: nil)
        #expect(entry.duration == 0)
    }

    // MARK: isRunning

    @Test("isRunning is true when end is nil")
    func isRunningWhenNoEnd() {
        let entry = TimeEntry(start: Date(), project: nil)
        #expect(entry.isRunning)
    }

    @Test("isRunning is false when end is set")
    func isNotRunningWhenEndSet() {
        let entry = TimeEntry(start: Date().addingTimeInterval(-60),
                              end: Date(),
                              project: nil)
        #expect(!entry.isRunning)
    }

    // MARK: source

    @Test("default source is timer")
    func defaultSourceIsTimer() {
        let entry = TimeEntry(start: Date(), project: nil)
        #expect(entry.source == .timer)
    }

    @Test("manual source is stored and retrieved correctly")
    func manualSourceRoundtrips() {
        let entry = TimeEntry(start: Date(), project: nil, source: .manual)
        #expect(entry.source == .manual)
    }

    @Test("unknown sourceRaw falls back to manual")
    func unknownSourceRawFallsBackToManual() {
        let entry = TimeEntry(start: Date(), project: nil)
        entry.sourceRaw = "future_source"
        #expect(entry.source == .manual)
    }
}

// MARK: - Project & Task Relationship Tests

@Suite("Project and Task Relationships")
@MainActor
struct ProjectTaskRelationshipTests {

    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Project.self, Task.self, TimeEntry.self,
                                       configurations: config)
        context = container.mainContext
    }

    @Test("task is linked to its project")
    func taskLinkedToProject() throws {
        let project = Project(name: "Branding", colorHex: "#E8643A")
        context.insert(project)
        let task = Task(name: "Logo", project: project)
        context.insert(task)
        try context.save()

        #expect(task.project?.persistentModelID == project.persistentModelID)
        #expect(project.tasks.contains { $0.persistentModelID == task.persistentModelID })
    }

    @Test("multiple tasks can belong to one project")
    func multipleTasksOnOneProject() throws {
        let project = Project(name: "Branding", colorHex: "#E8643A")
        context.insert(project)
        let names = ["Logo", "Icons", "Style Guide"]
        for name in names {
            context.insert(Task(name: name, project: project))
        }
        try context.save()

        #expect(project.tasks.count == names.count)
    }

    @Test("archived task does not appear in active task filter")
    func archivedTaskFilteredOut() throws {
        let project = Project(name: "Branding", colorHex: "#E8643A")
        context.insert(project)
        let active   = Task(name: "Active",   project: project)
        let archived = Task(name: "Archived", project: project)
        archived.isArchived = true
        context.insert(active)
        context.insert(archived)
        try context.save()

        let activeTasks = project.tasks.filter { !$0.isArchived }
        #expect(activeTasks.count == 1)
        #expect(activeTasks.first?.name == "Active")
    }

    @Test("time entry links to both task and project")
    func entryLinksToTaskAndProject() throws {
        let project = Project(name: "Branding", colorHex: "#E8643A")
        context.insert(project)
        let task = Task(name: "Logo", project: project)
        context.insert(task)
        let entry = TimeEntry(start: Date().addingTimeInterval(-300),
                              end: Date(),
                              project: project,
                              task: task)
        context.insert(entry)
        try context.save()

        #expect(entry.project?.persistentModelID == project.persistentModelID)
        #expect(entry.task?.persistentModelID == task.persistentModelID)
        #expect(project.entries.contains { $0.persistentModelID == entry.persistentModelID })
    }

    @Test("today's total includes running entry's elapsed time")
    func todayTotalIncludesRunningEntry() throws {
        let project = Project(name: "Branding", colorHex: "#E8643A")
        context.insert(project)
        let task = Task(name: "Logo", project: project)
        context.insert(task)

        // One completed entry (30 min) + one running entry (started 10 min ago)
        let completed = TimeEntry(start: Date().addingTimeInterval(-5400),
                                  end:   Date().addingTimeInterval(-3600),
                                  project: project, task: task)
        let running   = TimeEntry(start: Date().addingTimeInterval(-600),
                                  project: project, task: task)
        context.insert(completed)
        context.insert(running)
        try context.save()

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let todayEntries = project.entries.filter { $0.start >= startOfDay }
        let total = todayEntries.reduce(0.0) { $0 + $1.duration }

        // Should be at least 30 + 10 = 40 minutes
        #expect(total >= 2400)
    }

    @Test("deleting a project cascade-deletes its entries")
    func deletingProjectDeletesEntries() throws {
        let project = Project(name: "Branding", colorHex: "#E8643A")
        context.insert(project)
        let task = Task(name: "Logo", project: project)
        context.insert(task)
        let entry = TimeEntry(start: Date().addingTimeInterval(-300),
                              end: Date(), project: project, task: task)
        context.insert(entry)
        try context.save()

        context.delete(project)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<TimeEntry>())
        #expect(entries.isEmpty)
    }

    @Test("deleting a task nullifies entry's task reference, not the entry itself")
    func deletingTaskNullifiesEntryTaskReference() throws {
        let project = Project(name: "Branding", colorHex: "#E8643A")
        context.insert(project)
        let task = Task(name: "Logo", project: project)
        context.insert(task)
        let entry = TimeEntry(start: Date().addingTimeInterval(-300),
                              end: Date(), project: project, task: task)
        context.insert(entry)
        try context.save()

        context.delete(task)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<TimeEntry>())
        #expect(entries.count == 1, "entry should survive task deletion")
        #expect(entries.first?.task == nil, "task reference should be nullified")
        #expect(entries.first?.project?.persistentModelID == project.persistentModelID,
                "project reference must remain intact")
    }
}
