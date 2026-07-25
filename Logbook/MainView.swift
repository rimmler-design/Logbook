import SwiftUI
import SwiftData

enum SidebarItem: Hashable {
    case project(Project)
    case analytics
    case history
}

struct MainView: View {
    @Environment(TimerEngine.self) private var timerEngine

    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.name)
    private var projects: [Project]

    @State private var selectedItem: SidebarItem? = .history
    @State private var showingNewProject = false
    @State private var showingAssign = false

    var body: some View {
        VStack(spacing: 0) {
            navigationSplitContent
            if timerEngine.isRunningUnassigned {
                unassignedBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: timerEngine.isRunningUnassigned)
        .sheet(isPresented: $showingAssign) { AssignTimerView() }
    }

    private var navigationSplitContent: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                Section("Projects") {
                    ForEach(projects) { project in
                        sidebarRow(project)
                            .tag(SidebarItem.project(project))
                    }
                }
                Section {
                    Label("Analytics", systemImage: "chart.bar")
                        .tag(SidebarItem.analytics)
                    Label("History", systemImage: "clock")
                        .tag(SidebarItem.history)
                }
            }
            .navigationTitle("Logbook")
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                sidebarActionBar
            }
        } detail: {
            switch selectedItem {
            case .project(let project):
                ProjectDetailView(project: project)
                    .id(project.persistentModelID)
            case .analytics:
                AnalyticsView()
            case .history, nil:
                if projects.isEmpty {
                    emptyState
                } else {
                    HistoryView()
                }
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .sheet(isPresented: $showingNewProject) { ProjectEditView(project: nil) }
        .onChange(of: projects) { _, newProjects in
            if case .project(let proj) = selectedItem {
                let stillExists = newProjects.contains { $0.persistentModelID == proj.persistentModelID }
                if !stillExists { selectedItem = .history }
            }
        }
    }

    private var sidebarActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 6) {
                Button {
                    timerEngine.isRunning ? timerEngine.stop() : timerEngine.startGeneral()
                } label: {
                    Label(
                        timerEngine.isRunning ? "Stop Timer" : "Start Timer",
                        systemImage: timerEngine.isRunning ? "stop.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(timerEngine.isRunning ? .red : .accentColor)

                Button { showingNewProject = true } label: {
                    Label("New Project", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private var unassignedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .foregroundStyle(.orange)
            Text("Timer running · No project assigned")
                .font(.system(size: 13))
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text(TimeFormat.hms(timerEngine.runningEntry?.duration ?? 0))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Button("Assign") { showingAssign = true }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button {
                timerEngine.stop()
            } label: {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundStyle(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No projects yet")
                .font(.title3.bold())
            Text("Create a project to start tracking your time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("New Project") { showingNewProject = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sidebarRow(_ project: Project) -> some View {
        let isRunning = timerEngine.runningEntry?.project?.persistentModelID == project.persistentModelID
        return HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: project.colorHex))
                .frame(width: 10, height: 10)
            Text(project.name)
            Spacer()
            if isRunning {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
            }
        }
    }
}
