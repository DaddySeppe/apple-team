import SwiftUI

// MARK: - Help Tooltip

struct HelpTooltip: View {
    let message: String

    @State private var showDialog = false

    var body: some View {
        Button(action: { showDialog = true }) {
            Image(systemName: "info.circle")
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .alert("Info", isPresented: $showDialog) {
            Button("OK") {}
        } message: {
            Text(message)
        }
    }
}

// MARK: - Info Card (for tips and hints)

struct InfoCard: View {
    let message: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
            }
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.1)))
    }
}
