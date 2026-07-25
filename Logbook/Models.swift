import Foundation
import SwiftData

enum EntrySource: String, Codable {
    case timer
    case manual
}

@Model
final class Project {
    var name: String = ""
    var colorHex: String = "#4F8EF7"
    var clientName: String?
    var isArchived: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Task.project)
    var tasks: [Task] = []

    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.project)
    var entries: [TimeEntry] = []

    init(name: String, colorHex: String, clientName: String? = nil) {
        self.name = name
        self.colorHex = colorHex
        self.clientName = clientName
    }
}

@Model
final class Task {
    var name: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var project: Project?

    // .nullify preserves time entries when a task is deleted
    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.task)
    var entries: [TimeEntry] = []

    init(name: String, project: Project?) {
        self.name = name
        self.project = project
    }
}

@Model
final class TimeEntry {
    var start: Date = Date()
    /// nil == currently running
    var end: Date?
    var note: String?
    var sourceRaw: String = EntrySource.timer.rawValue
    var project: Project?
    var task: Task?

    var source: EntrySource {
        get { EntrySource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    init(start: Date,
         end: Date? = nil,
         project: Project?,
         task: Task? = nil,
         source: EntrySource = .timer,
         note: String? = nil) {
        self.start = start
        self.end = end
        self.project = project
        self.task = task
        self.sourceRaw = source.rawValue
        self.note = note
    }

    /// Always derived from dates — never accumulated.
    var duration: TimeInterval { (end ?? Date()).timeIntervalSince(start) }
    var isRunning: Bool { end == nil }
}
