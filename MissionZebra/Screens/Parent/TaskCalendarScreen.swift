import SwiftUI

struct TaskCalendarScreen: View {
    @EnvironmentObject var router: NavigationRouter
    @StateObject private var viewModel = TaskCalendarViewModel()
    @State private var showCalendarPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: { router.goBack() }) {
                    Image(systemName: "arrow.left")
                        .font(.title3)
                }
                Text("📅 Taakkalender")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()

            ScrollView {
                VStack(spacing: 16) {
                    // Header card
                    VStack(spacing: 8) {
                        Text("📆 Taakkalender")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Bekijk welke taken er vandaag en deze week gepland zijn.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

                    CalendarSyncCard(
                        isPremium: viewModel.premiumStatus.isPremium,
                        isConnected: viewModel.isCalendarConnected,
                        calendars: viewModel.availableCalendars,
                        connectedCalendarId: viewModel.connectedCalendarId,
                        isSyncing: viewModel.isSyncingCalendar,
                        message: viewModel.calendarMessage,
                        error: viewModel.calendarError,
                        onConnect: { showCalendarPicker = true },
                        onSync: { viewModel.syncNow() },
                        onDisconnect: { viewModel.disconnectCalendar() }
                    )

                    TaskCalendarView(
                        tasksPerDay: viewModel.tasksPerDay,
                        selectedDate: viewModel.selectedDate,
                        onSelectDate: { viewModel.selectDate($0) }
                    )

                    if !viewModel.tasksForSelectedDate.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Taken op deze dag")
                                .font(.headline)
                            ForEach(viewModel.tasksForSelectedDate) { task in
                                HStack {
                                    Text(task.title)
                                    Spacer()
                                    Text("\(task.points) punten")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    }

                    // Info card
                    VStack(spacing: 8) {
                        Text("💡 Tip")
                            .font(.headline)
                        Text("Voeg taken toe via het Taken-tabblad om ze hier in de kalender te zien verschijnen.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .onAppear { viewModel.refreshCalendars() }
        .confirmationDialog("Kies agenda", isPresented: $showCalendarPicker) {
            ForEach(viewModel.availableCalendars) { calendar in
                Button(calendar.title) {
                    viewModel.connectCalendar(calendarId: calendar.id)
                }
            }
            Button("Annuleren", role: .cancel) {}
        }
    }
}

private struct CalendarSyncCard: View {
    let isPremium: Bool
    let isConnected: Bool
    let calendars: [TaskCalendarDestination]
    let connectedCalendarId: String?
    let isSyncing: Bool
    let message: String?
    let error: String?
    let onConnect: () -> Void
    let onSync: () -> Void
    let onDisconnect: () -> Void

    private var connectedTitle: String {
        calendars.first(where: { $0.id == connectedCalendarId })?.title ?? "Gekoppelde agenda"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Kalender-sync", systemImage: "calendar.badge.clock")
                    .font(.headline)
                Spacer()
                if isPremium {
                    Text(isConnected ? "Verbonden" : "Premium")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(isConnected ? .green : .secondary)
                } else {
                    Text("Premium")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
            }

            Text(isPremium ? (isConnected ? "Taken worden gesynchroniseerd naar \(connectedTitle)." : "Koppel een agenda om taken te synchroniseren.") : "Upgrade naar premium om taken naar je iOS-agenda te synchroniseren.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.green)
            }
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                if isConnected {
                    Button(action: onSync) {
                        if isSyncing {
                            ProgressView()
                        } else {
                            Label("Sync nu", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSyncing || !isPremium)

                    Button("Loskoppelen", role: .destructive, action: onDisconnect)
                        .buttonStyle(.bordered)
                } else {
                    Button(action: onConnect) {
                        Label("Koppel agenda", systemImage: "link")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isPremium)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

// MARK: - Task Calendar View

struct TaskCalendarView: View {
    let tasksPerDay: [String: Int]
    let selectedDate: Date?
    let onSelectDate: (Date) -> Void

    @State private var visibleMonth = Date()

    private let dayLabels = ["Ma", "Di", "Wo", "Do", "Vr", "Za", "Zo"]

    var body: some View {
        VStack(spacing: 12) {
            // Month header
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(monthYearString)
                    .font(.headline)
                Spacer()
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal, 8)

            // Day labels
            HStack {
                ForEach(dayLabels, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            let days = generateDays()
            let rows = days.chunked(into: 7)

            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack {
                    ForEach(rows[rowIndex].indices, id: \.self) { colIndex in
                        let day = rows[rowIndex][colIndex]
                        if day == 0 {
                            Text("")
                                .frame(maxWidth: .infinity, minHeight: 36)
                        } else {
                            let date = dateFor(day: day)
                            let isToday = isCurrentDay(day)
                            let isSelected = date.map { dayDate in
                                selectedDate.map { Calendar.current.isDate($0, inSameDayAs: dayDate) } ?? false
                            } ?? false
                            let count = date.map { tasksPerDay[TaskOrdering.dateKey(from: $0)] ?? 0 } ?? 0
                            Button(action: {
                                if let date { onSelectDate(date) }
                            }) {
                                VStack(spacing: 2) {
                                    Text("\(day)")
                                        .font(.caption)
                                        .fontWeight(isToday || isSelected ? .bold : .regular)
                                    if count > 0 {
                                        Text("\(count)")
                                            .font(.system(size: 9))
                                            .fontWeight(.bold)
                                    }
                                }
                                .foregroundColor(isToday || isSelected ? .white : .primary)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(
                                    Circle()
                                        .fill(isSelected ? Color.orange : (isToday ? Color.accentColor : Color.clear))
                                        .frame(width: 34, height: 34)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_BE")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: visibleMonth).capitalized
    }

    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: visibleMonth) {
            visibleMonth = newDate
        }
    }

    private func isCurrentDay(_ day: Int) -> Bool {
        let cal = Calendar.current
        let today = Date()
        return cal.component(.day, from: today) == day
            && cal.component(.month, from: today) == cal.component(.month, from: visibleMonth)
            && cal.component(.year, from: today) == cal.component(.year, from: visibleMonth)
    }

    private func generateDays() -> [Int] {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: visibleMonth)
        comps.day = 1
        guard let firstOfMonth = cal.date(from: comps) else { return [] }

        let weekday = cal.component(.weekday, from: firstOfMonth)
        // Convert to Monday-based (1=Mon, 7=Sun)
        let offset = (weekday + 5) % 7

        let range = cal.range(of: .day, in: .month, for: firstOfMonth) ?? 1..<31
        let daysInMonth = range.count

        var result = Array(repeating: 0, count: offset)
        for d in 1...daysInMonth {
            result.append(d)
        }
        // Pad to complete last row
        while result.count % 7 != 0 {
            result.append(0)
        }
        return result
    }

    private func dateFor(day: Int) -> Date? {
        var comps = Calendar.current.dateComponents([.year, .month], from: visibleMonth)
        comps.day = day
        return Calendar.current.date(from: comps)
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
