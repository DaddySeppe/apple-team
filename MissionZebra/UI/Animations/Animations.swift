import SwiftUI

// MARK: - Press Animation

/// A view modifier that scales the view slightly when pressed, providing tactile feedback.
/// Equivalent of Android `Modifier.pressAnimation()`.
struct PressAnimationModifier: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.interpolatingSpring(stiffness: 300, damping: 15), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

extension View {
    /// Modifier voor een vloeiende druk-animatie op knoppen en kaarten.
    func pressAnimation() -> some View {
        modifier(PressAnimationModifier())
    }
}

// MARK: - Fade In Animation

/// A view modifier that fades the content in when it appears.
struct FadeInModifier: ViewModifier {
    let duration: Double
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: duration)) {
                    opacity = 1
                }
            }
    }
}

extension View {
    /// Vloeiende fade-in animatie voor schermen en componenten.
    func fadeInAnimation(duration: Double = 0.5) -> some View {
        modifier(FadeInModifier(duration: duration))
    }
}

// MARK: - Slide In From Top

/// A view modifier that slides the content in from the top.
struct SlideInFromTopModifier: ViewModifier {
    let duration: Double
    let delay: Double
    @State private var offsetY: CGFloat = -100

    func body(content: Content) -> some View {
        content
            .offset(y: offsetY)
            .onAppear {
                withAnimation(.easeOut(duration: duration).delay(delay)) {
                    offsetY = 0
                }
            }
    }
}

extension View {
    /// Slide-in van boven animatie voor componenten.
    func slideInFromTop(duration: Double = 0.4, delay: Double = 0) -> some View {
        modifier(SlideInFromTopModifier(duration: duration, delay: delay))
    }
}

// MARK: - Slide In From Bottom

/// A view modifier that slides the content in from the bottom.
struct SlideInFromBottomModifier: ViewModifier {
    let duration: Double
    let delay: Double
    @State private var offsetY: CGFloat = 100

    func body(content: Content) -> some View {
        content
            .offset(y: offsetY)
            .onAppear {
                withAnimation(.easeOut(duration: duration).delay(delay)) {
                    offsetY = 0
                }
            }
    }
}

extension View {
    /// Slide-in van beneden animatie voor componenten.
    func slideInFromBottom(duration: Double = 0.4, delay: Double = 0) -> some View {
        modifier(SlideInFromBottomModifier(duration: duration, delay: delay))
    }
}

// MARK: - Scale In Animation

/// A view modifier that scales the content in with a bouncy spring.
struct ScaleInModifier: ViewModifier {
    let delay: Double
    @State private var scale: CGFloat = 0.8

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 15).delay(delay)) {
                    scale = 1.0
                }
            }
    }
}

extension View {
    /// Scale-in animatie voor componenten die in beeld komen.
    func scaleInAnimation(delay: Double = 0) -> some View {
        modifier(ScaleInModifier(delay: delay))
    }
}
