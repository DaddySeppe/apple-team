import SwiftUI

// MARK: - Zebra Background View

struct ZebraBackgroundView<Content: View>: View {
    var rotationDegrees: Double = -18
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.mzColors) private var colors

    private var stripeAlpha: Double {
        colorScheme == .dark ? 0.3 : 0.16
    }

    var body: some View {
        ZStack {
            colors.primary
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

// MARK: - Child Zebra Photo Background

struct ChildZebraPhotoBackgroundView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { _ in
                        Image("ZebraStripes")
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height / 2)
                            .clipped()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea()

            Color.black.opacity(0.18)
                .ignoresSafeArea()

            content
        }
    }
}
