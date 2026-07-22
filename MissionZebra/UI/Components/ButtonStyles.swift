import SwiftUI

struct MZPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.mzColors) private var colors

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundColor(isEnabled ? colors.onPrimary : colors.onSurfaceVariant)
            .frame(minHeight: 42)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isEnabled ? colors.primary : colors.outlineVariant)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: isEnabled ? colors.primary.opacity(0.22) : .clear, radius: 4, x: 0, y: 2)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct MZSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.mzColors) private var colors

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(isEnabled ? colors.onSurface : colors.onSurfaceVariant)
            .frame(minHeight: 40)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isEnabled ? colors.outline.opacity(0.7) : colors.outlineVariant, lineWidth: 1.2)
            )
            .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

extension ButtonStyle where Self == MZPrimaryButtonStyle {
    static var mzPrimary: MZPrimaryButtonStyle { MZPrimaryButtonStyle() }
}

extension ButtonStyle where Self == MZSecondaryButtonStyle {
    static var mzSecondary: MZSecondaryButtonStyle { MZSecondaryButtonStyle() }
}
