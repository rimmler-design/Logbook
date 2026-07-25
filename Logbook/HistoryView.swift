import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TimeEntry.start, order: .reverse) private var entries: [TimeEntry]
    @Query(filter: #Predicate<Project> { $0.isArchived == false },
           sort: \Project.name) private var projects: [Project]

    @State private var editingEntry: TimeEntry?
    @State private var showingNew = false

    private var grouped: [(day: Date, entries: [TimeEntry])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: entries.filter { $0.end != nil }) {
            cal.startOfDay(for: $0.start)
        }
        return groups
            .map { (day: $0.key, entries: $0.value.sorted { $0.start > $1.start }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if grouped.isEmpty {
                ContentUnavailableView("No entries yet",
                                       systemImage: "clock",
                                       description: Text("Track time or add an entry manually."))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(grouped, id: \.day) { group in
                            daySection(group.day, group.entries)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .sheet(isPresented: $showingNew) { EntryEditView(entry: nil, projects: projects) }
        .sheet(item: $editingEntry) { entry in EntryEditView(entry: entry, projects: projects) }
    }

    private var header: some View {
        HStack {
            Text("History").font(.title2.bold())
            Spacer()
            Button { showingNew = true } label: { Label("Add Entry", systemImage: "plus") }
        }
        .padding(12)
    }

    private func dayTotal(_ list: [TimeEntry]) -> TimeInterval {
        list.reduce(0) { $0 + $1.duration }
    }

    private func daySection(_ day: Date, _ list: [TimeEntry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(day, format: .dateTime.weekday(.wide).month().day())
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(TimeFormat.hms(dayTotal(list)))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            ForEach(list) { entry in entryRow(entry) }
        }
    }

    private func entryRow(_ entry: TimeEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color(hex: entry.project?.colorHex ?? "#8E8E93"))
                .frame(width: 10, height: 10)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.project?.name ?? "No project")
                        .font(.system(size: 13))
                    if let taskName = entry.task?.name {
                        Text("›")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 12))
                        Text(taskName)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                Text("\(entry.start, format: .dateTime.hour().minute()) – \(entry.end ?? entry.start, format: .dateTime.hour().minute())")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(TimeFormat.hms(entry.duration))
                    .font(.system(size: 12, design: .monospaced))
                HStack(spacing: 4) {
                    Button { editingEntry = entry } label: { Image(systemName: "pencil") }
                        .buttonStyle(.borderless)
                    Button(role: .destructive) {
                        context.delete(entry); try? context.save()
                    } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct AssignTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TimerEngine.self) private var timerEngine
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.name)
    private var projects: [Project]

    @State private var selectedProject: Project?
    @State private var selectedTask: Task?

    private var availableTasks: [Task] {
        (selectedProject?.tasks ?? []).filter { !$0.isArchived }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Assign Timer").font(.title3.bold())

            VStack(alignment: .leading, spacing: 6) {
                Text("Project").font(.caption).foregroundStyle(.secondary)
                Picker("Project", selection: $selectedProject) {
                    Text("Select a project…").tag(Project?.none)
                    ForEach(projects) { p in Text(p.name).tag(Optional(p)) }
                }
                .labelsHidden()
                .onChange(of: selectedProject) { _, _ in selectedTask = nil }
            }

            if !availableTasks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Task (optional)").font(.caption).foregroundStyle(.secondary)
                    Picker("Task", selection: $selectedTask) {
                        Text("No specific task").tag(Task?.none)
                        ForEach(availableTasks) { t in Text(t.name).tag(Optional(t)) }
                    }
                    .labelsHidden()
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Assign") {
                    if let project = selectedProject {
                        timerEngine.assign(project: project, task: selectedTask)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedProject == nil)
            }
        }
        .padding(20)
        .frame(width: 320, height: 240)
        .onAppear { selectedProject = projects.first }
    }
}

struct EntryEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let entry: TimeEntry?
    let projects: [Project]

    @State private var selectedProject: Project?
    @State private var selectedTask: Task?
    @State private var start = Date()
    @State private var end = Date()
    @State private var note = ""

    private var isEditing: Bool { entry != nil }
    private var valid: Bool { end >= start }

    private var availableTasks: [Task] {
        (selectedProject?.tasks ?? []).filter { !$0.isArchived }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEditing ? "Edit Entry" : "Add Entry").font(.title3.bold())

            VStack(alignment: .leading, spacing: 6) {
                Text("Project").font(.caption).foregroundStyle(.secondary)
                Picker("Project", selection: $selectedProject) {
                    Text("No project").tag(Project?.none)
                    ForEach(projects) { p in Text(p.name).tag(Optional(p)) }
                }
                .labelsHidden()
                .onChange(of: selectedProject) { _, _ in selectedTask = nil }
            }

            if !availableTasks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Task").font(.caption).foregroundStyle(.secondary)
                    Picker("Task", selection: $selectedTask) {
                        Text("No task").tag(Task?.none)
                        ForEach(availableTasks) { t in Text(t.name).tag(Optional(t)) }
                    }
                    .labelsHidden()
                }
            }

            DatePicker("Start", selection: $start)
            DatePicker("End", selection: $end)

            VStack(alignment: .leading, spacing: 6) {
                Text("Note (optional)").font(.caption).foregroundStyle(.secondary)
                TextField("Note", text: $note).textFieldStyle(.roundedBorder)
            }

            if !valid {
                Text("End must be after start.").font(.caption).foregroundStyle(.red)
            }

            Spacer()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!valid)
            }
        }
        .padding(20)
        .frame(width: 380, height: 420)
        .onAppear {
            if let entry {
                selectedProject = entry.project
                selectedTask = entry.task
                start = entry.start
                end = entry.end ?? Date()
                note = entry.note ?? ""
            } else {
                start = Date().addingTimeInterval(-3600)
                end = Date()
            }
        }
    }

    private func save() {
        guard valid else { return }
        let cleanedNote = note.isEmpty ? nil : note
        if let entry {
            entry.project = selectedProject
            entry.task = selectedTask
            entry.start = start
            entry.end = end
            entry.note = cleanedNote
            entry.source = .manual
        } else {
            context.insert(TimeEntry(start: start, end: end,
                                     project: selectedProject,
                                     task: selectedTask,
                                     source: .manual, note: cleanedNote))
        }
        try? context.save()
        dismiss()
    }
}
