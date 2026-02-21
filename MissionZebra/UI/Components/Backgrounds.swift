import SwiftUI

// MARK: - Zebra Background View

struct ZebraBackgroundView<Content: View>: View {
    var rotationDegrees: Double = -18
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var colorScheme

    private var stripeAlpha: Double {
        colorScheme == .dark ? 0.3 : 0.16
    }

    var body: some View {
        ZStack {
            Color.accentColor
                .ignoresSafeArea()

            Canvas { context, size in
                let stripeWidth = min(size.width, size.height) / 6
                let maxDim = max(size.width, size.height)
                var x: CGFloat = -maxDim
                var index = 0

                context.rotate(by: .degrees(rotationDegrees))

                while x < maxDim * 2 {
                    let color = index % 2 == 0
                        ? Color(.systemBackground).opacity(stripeAlpha)
                        : Color(.secondarySystemBackground).opacity(stripeAlpha)

                    let rect = CGRect(x: x, y: -maxDim, width: stripeWidth, height: maxDim * 3)
                    context.fill(Path(rect), with: .color(color))

                    x += stripeWidth
                    index += 1
                }
            }
            .ignoresSafeArea()

            content
        }
    }
}
