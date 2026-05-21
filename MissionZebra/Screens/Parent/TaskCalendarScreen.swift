import SwiftUI

struct TaskCalendarScreen: View {
    @EnvironmentObject var router: NavigationRouter

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

                    TaskCalendarView()

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
    }
}

// MARK: - Task Calendar View

struct TaskCalendarView: View {
    @State private var selectedDate = Date()

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
                            let isToday = isCurrentDay(day)
                            Text("\(day)")
                                .font(.caption)
                                .fontWeight(isToday ? .bold : .regular)
                                .foregroundColor(isToday ? .white : .primary)
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(
                                    Circle()
                                        .fill(isToday ? Color.accentColor : Color.clear)
                                        .frame(width: 32, height: 32)
                                )
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
        return formatter.string(from: selectedDate).capitalized
    }

    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }

    private func isCurrentDay(_ day: Int) -> Bool {
        let cal = Calendar.current
        let today = Date()
        return cal.component(.day, from: today) == day
            && cal.component(.month, from: today) == cal.component(.month, from: selectedDate)
            && cal.component(.year, from: today) == cal.component(.year, from: selectedDate)
    }

    private func generateDays() -> [Int] {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: selectedDate)
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
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
