import SwiftUI

// MARK: - Simple Bar Chart

struct SimpleBarChart: View {
    let title: String
    let data: [(String, Int)] // Label to value
    let maxValue: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.body)
                .fontWeight(.bold)

            if data.isEmpty {
                Text("Nog geen data beschikbaar")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(data, id: \.0) { label, value in
                    BarItemView(label: label, value: value, maxValue: maxValue)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(radius: 2))
    }
}

private struct BarItemView: View {
    let label: String
    let value: Int
    let maxValue: Int

    private var progress: CGFloat {
        maxValue > 0 ? CGFloat(value) / CGFloat(maxValue) : 0
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(value)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.tertiarySystemBackground))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * min(progress, 1.0), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Circular Progress

struct CircularProgressView: View {
    let progress: Float // 0.0 to 1.0
    let label: String
    var size: CGFloat = 120

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: size * 0.1)
                    .frame(width: size, height: size)

                Circle()
                    .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                    .stroke(Color(red: 0.47, green: 0.85, blue: 0.98), style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(progress * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
            }

            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Legend Item

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            Text(label)
                .font(.caption)
        }
    }
}
