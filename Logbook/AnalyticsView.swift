import SwiftUI
import SwiftData

// MARK: - Date Range

enum DateRange: String, CaseIterable, Identifiable {
    case today = "Today"
    case week  = "Week"
    case month = "Month"
    case year  = "Year"

    var id: String { rawValue }

    var startDate: Date {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .today:  return cal.startOfDay(for: now)
        case .week:   return cal.dateInterval(of: .weekOfYear, for: now)?.start ?? cal.startOfDay(for: now)
        case .month:  return cal.dateInterval(of: .month, for: now)?.start ?? cal.startOfDay(for: now)
        case .year:   return cal.dateInterval(of: .year, for: now)?.start ?? cal.startOfDay(for: now)
        }
    }

    var subtitle: String {
        switch self {
        case .today:  return "today"
        case .week:   return "this week"
        case .month:  return "this month"
        case .year:   return "this year"
        }
    }
}

// MARK: - Internal stat models

private struct ProjectStat: Identifiable {
    var id: String { project?.persistentModelID.hashValue.description ?? "unassigned" }
    let project: Project?
    let total: TimeInterval
    let fraction: Double
    let tasks: [TaskStat]
}

private struct TaskStat: Identifiable {
    var id: String { task?.persistentModelID.hashValue.description ?? "notask" }
    let task: Task?
    let total: TimeInterval
}

// MARK: - Analytics View

struct AnalyticsView: View {
    @Environment(TimerEngine.self) private var timerEngine
    @Query private var allEntries: [TimeEntry]

    @State private var selectedRange: DateRange = .today

    private func filteredEntries(now: Date) -> [TimeEntry] {
        allEntries.filter { $0.start >= selectedRange.startDate }
    }

    private func totalTime(entries: [TimeEntry]) -> TimeInterval {
        entries.reduce(0) { $0 + $1.duration }
    }

    private func projectStats(entries: [TimeEntry]) -> [ProjectStat] {
        let total = totalTime(entries: entries)
        guard total > 0 else { return [] }

        let grouped = Dictionary(grouping: entries) { $0.project?.persistentModelID }
        return grouped
            .map { (_, projectEntries) -> ProjectStat in
                let project = projectEntries.first?.project
                let projectTotal = projectEntries.reduce(0.0) { $0 + $1.duration }

                let taskGrouped = Dictionary(grouping: projectEntries) {
                    $0.task?.persistentModelID
                }
                let tasks: [TaskStat] = taskGrouped.map { (_, taskEntries) in
                    TaskStat(
                        task: taskEntries.first?.task,
                        total: taskEntries.reduce(0) { $0 + $1.duration }
                    )
                }
                .sorted { $0.total > $1.total }

                return ProjectStat(
                    project: project,
                    total: projectTotal,
                    fraction: projectTotal / total,
                    tasks: tasks
                )
            }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                TimelineView(.periodic(from: .now, by: 10)) { context in
                    let entries = filteredEntries(now: context.date)
                    let total   = totalTime(entries: entries)
                    let stats   = projectStats(entries: entries)

                    VStack(alignment: .leading, spacing: 28) {
                        totalSection(total: total)
                        if entries.isEmpty {
                            emptyState
                        } else {
                            breakdownSection(stats: stats)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Analytics").font(.title2.bold())
            Spacer()
            Picker("Range", selection: $selectedRange) {
                ForEach(DateRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 260)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Total

    private func totalSection(total: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(TimeFormat.hm(total))
                .font(.system(size: 40, weight: .bold, design: .monospaced))
            Text("total \(selectedRange.subtitle)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Breakdown

    private func breakdownSection(stats: [ProjectStat]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("By project")
                .font(.headline)
            VStack(spacing: 6) {
                ForEach(stats) { stat in
                    projectCard(stat)
                }
            }
        }
    }

    private func projectCard(_ stat: ProjectStat) -> some View {
        let isUnassigned = stat.project == nil
        let accentColor: Color = isUnassigned ? .orange : Color(hex: stat.project!.colorHex)

        return VStack(alignment: .leading, spacing: 8) {

            // Name row
            HStack(spacing: 8) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 10, height: 10)
                Text(stat.project?.name ?? "Unassigned")
                    .font(.system(size: 13, weight: .semibold))
                if let client = stat.project?.clientName, !client.isEmpty {
                    Text("· \(client)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(TimeFormat.hm(stat.total))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                Text("\(Int((stat.fraction * 100).rounded()))%")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.07))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(accentColor)
                        .frame(width: max(6, geo.size.width * stat.fraction), height: 6)
                }
            }
            .frame(height: 6)

            // Task breakdown — only show if there are named tasks
            if stat.tasks.contains(where: { $0.task != nil }) {
                VStack(spacing: 3) {
                    ForEach(stat.tasks.filter { $0.task != nil }.prefix(6)) { taskStat in
                        HStack {
                            Text(taskStat.task!.name)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(TimeFormat.hm(taskStat.total))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.leading, 18)
                    }
                    let namedCount = stat.tasks.filter { $0.task != nil }.count
                    if namedCount > 6 {
                        Text("+\(namedCount - 6) more tasks")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 18)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("No entries \(selectedRange.subtitle)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
