import SwiftUI
import SwiftData

// MARK: - Project Detail

struct ProjectDetailView: View {
    @Environment(TimerEngine.self) private var timerEngine
    @Environment(\.modelContext) private var context

    let project: Project

    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.name)
    private var allProjects: [Project]

    @State private var showingEditProject = false
    @State private var showingNewTask = false
    @State private var editingTask: Task?
    @State private var quickLoggingTask: Task?
    @State private var editingEntry: TimeEntry?

    private var activeTasks: [Task] {
        project.tasks
            .filter { !$0.isArchived }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var todayEntries: [TimeEntry] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return project.entries.filter { $0.start >= startOfDay }
    }

    private func todayTotal(for task: Task) -> TimeInterval {
        todayEntries
            .filter { $0.task?.persistentModelID == task.persistentModelID }
            .reduce(0) { $0 + $1.duration }
    }

    private var projectTodayTotal: TimeInterval {
        todayEntries.reduce(0) { $0 + $1.duration }
    }

    private func isRunning(_ task: Task) -> Bool {
        timerEngine.runningEntry?.task?.persistentModelID == task.persistentModelID
    }

    private var recentEntries: [TimeEntry] {
        Array(
            project.entries
                .filter { $0.end != nil }
                .sorted { $0.start > $1.start }
                .prefix(20)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    tasksSection
                        .padding(16)
                    Divider()
                    recentEntriesSection
                        .padding(16)
                }
            }
        }
        .sheet(isPresented: $showingEditProject) { ProjectEditView(project: project) }
        .sheet(isPresented: $showingNewTask) { TaskEditView(task: nil, project: project) }
        .sheet(item: $editingTask) { task in TaskEditView(task: task, project: project) }
        .sheet(item: $quickLoggingTask) { task in QuickLogView(task: task) }
        .sheet(item: $editingEntry) { entry in EntryEditView(entry: entry, projects: allProjects) }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: project.colorHex))
                .frame(width: 14, height: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name).font(.title2.bold())
                if let client = project.clientName, !client.isEmpty {
                    Text(client).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Today").font(.caption).foregroundStyle(.secondary)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(TimeFormat.hm(projectTodayTotal))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                }
            }
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let projectRunning = timerEngine.isRunningProject(project)
                Button {
                    timerEngine.toggleProject(project)
                } label: {
                    Image(systemName: projectRunning ? "stop.circle.fill" : "play.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(projectRunning ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .help(projectRunning ? "Stop timer" : "Track time on this project")
            }
            Button("Edit") { showingEditProject = true }
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Tasks

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tasks").font(.headline)
                Spacer()
                Button { showingNewTask = true } label: {
                    Label("Add Task", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .font(.system(size: 13))
            }

            if activeTasks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No tasks yet.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            let running = timerEngine.isRunningProject(project)
                            Button {
                                timerEngine.toggleProject(project)
                            } label: {
                                Label(
                                    running ? "Stop Timer" : "Track without task",
                                    systemImage: running ? "stop.fill" : "play.fill"
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(running ? .red : .accentColor)
                            .controlSize(.small)
                        }
                        Button("Add Task") { showingNewTask = true }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 4) {
                    ForEach(activeTasks) { task in
                        taskRow(task)
                    }
                }
            }
        }
    }

    private func taskRow(_ task: Task) -> some View {
        let running = isRunning(task)
        return HStack(spacing: 12) {
            Text(task.name)
                .font(.system(size: 13, weight: running ? .semibold : .regular))
            Spacer()
            TimelineView(.periodic(from: .now, by: running ? 1 : 60)) { _ in
                Group {
                    if running {
                        Text(TimeFormat.hms(timerEngine.runningEntry?.duration ?? 0))
                    } else {
                        Text(TimeFormat.hm(todayTotal(for: task)))
                    }
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
            }
            Button { quickLoggingTask = task } label: {
                Label("Log", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Button {
                timerEngine.toggle(task: task)
            } label: {
                Image(systemName: running ? "stop.circle.fill" : "play.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(running ? .red : .secondary)
            }
            .buttonStyle(.plain)
            Button { editingTask = task } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(running ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Recent Entries

    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Entries").font(.headline)

            if recentEntries.isEmpty {
                Text("No entries yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 4) {
                    ForEach(recentEntries) { entry in
                        entryRow(entry)
                    }
                }
            }
        }
    }

    private func entryRow(_ entry: TimeEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.task?.name ?? "No task")
                    .font(.system(size: 13))
                Text("\(entry.start, format: .dateTime.month().day().hour().minute()) – \(entry.end ?? entry.start, format: .dateTime.hour().minute())")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
                    Button { editingEntry = entry } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    Button(role: .destructive) {
                        context.delete(entry)
                        try? context.save()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Quick Log

struct QuickLogView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let task: Task

    @State private var start = Date().addingTimeInterval(-3600)
    @State private var end   = Date()
    @State private var note  = ""

    private var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
    private var valid: Bool { end > start }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Log Time").font(.title3.bold())
                Text(task.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            DatePicker("Start", selection: $start)
            DatePicker("End",   selection: $end)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                Text(valid ? TimeFormat.hm(duration) : "End must be after start")
                    .font(.system(size: 12, design: valid ? .monospaced : .default))
                    .foregroundStyle(valid ? Color.secondary : Color.red)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Note (optional)").font(.caption).foregroundStyle(.secondary)
                TextField("e.g. client call, standup…", text: $note)
                    .textFieldStyle(.roundedBorder)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add Entry") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!valid)
            }
        }
        .padding(20)
        .frame(width: 340, height: 290)
    }

    private func save() {
        guard valid else { return }
        context.insert(TimeEntry(
            start: start, end: end,
            project: task.project, task: task,
            source: .manual,
            note: note.isEmpty ? nil : note
        ))
        try? context.save()
        dismiss()
    }
}

// MARK: - Task Edit

struct TaskEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let task: Task?
    let project: Project

    @State private var name = ""

    private var isEditing: Bool { task != nil }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEditing ? "Edit Task" : "New Task").font(.title3.bold())

            VStack(alignment: .leading, spacing: 6) {
                Text("Name").font(.caption).foregroundStyle(.secondary)
                TextField("Task name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            Spacer()

            HStack {
                if isEditing {
                    Button("Archive", role: .destructive) {
                        task?.isArchived = true
                        try? context.save()
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320, height: 200)
        .onAppear {
            if let task { name = task.name }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        if let task {
            task.name = trimmedName
        } else {
            let newTask = Task(name: trimmedName, project: project)
            context.insert(newTask)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - Project Edit

struct ProjectEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let project: Project?

    @State private var name = ""
    @State private var clientName = ""
    @State private var colorHex = ProjectPalette.hexes[0]
    @State private var isArchived = false

    private var isEditing: Bool { project != nil }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEditing ? "Edit Project" : "New Project").font(.title3.bold())

            field("Name") {
                TextField("Project name", text: $name).textFieldStyle(.roundedBorder)
            }
            field("Client (optional)") {
                TextField("Client name", text: $clientName).textFieldStyle(.roundedBorder)
            }
            field("Color") {
                HStack(spacing: 10) {
                    ForEach(ProjectPalette.hexes, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 26, height: 26)
                            .overlay {
                                if hex == colorHex {
                                    Circle().stroke(Color.primary, lineWidth: 2).padding(-3)
                                }
                            }
                            .onTapGesture { colorHex = hex }
                    }
                }
            }

            if isEditing { Toggle("Archived", isOn: $isArchived) }

            Spacer()

            HStack {
                if isEditing {
                    Button("Delete", role: .destructive) {
                        if let project { context.delete(project); try? context.save() }
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360, height: 360)
        .onAppear {
            if let project {
                name = project.name
                clientName = project.clientName ?? ""
                colorHex = project.colorHex
                isArchived = project.isArchived
            }
        }
    }

    private func field<Content: View>(_ label: String,
                                      @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        let client = clientName.isEmpty ? nil : clientName
        if let project {
            project.name = trimmedName
            project.clientName = client
            project.colorHex = colorHex
            project.isArchived = isArchived
        } else {
            context.insert(Project(name: trimmedName, colorHex: colorHex, clientName: client))
        }
        try? context.save()
        dismiss()
    }
}
