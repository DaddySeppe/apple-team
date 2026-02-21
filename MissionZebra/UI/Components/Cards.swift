import SwiftUI

// MARK: - MZCard

struct MZCard<Content: View>: View {
    var onClick: (() -> Void)?
    var elevation: CGFloat = 2
    var cornerRadius: CGFloat = 16
    var containerColor: Color = Color(.systemBackground)
    var contentPadding: CGFloat = 20
    @ViewBuilder let content: Content

    var body: some View {
        Group {
            if let onClick = onClick {
                Button(action: onClick) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(contentPadding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(containerColor)
                .shadow(radius: elevation)
        )
    }
}

// MARK: - MZElevatedCard

struct MZElevatedCard<Content: View>: View {
    var onClick: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        MZCard(onClick: onClick, elevation: 6, cornerRadius: 20) {
            content
        }
    }
}

// MARK: - MZCompactCard

struct MZCompactCard<Content: View>: View {
    var onClick: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        MZCard(onClick: onClick, elevation: 1, cornerRadius: 12, contentPadding: 16) {
            content
        }
    }
}
