import SwiftUI

struct WelcomeScreen: View {
    @EnvironmentObject var router: NavigationRouter

    @State private var titleOpacity: Double = 0
    @State private var titleScale: Double = 0.8
    @State private var textOffset: CGFloat = 50
    @State private var textOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 80
    @State private var buttonOpacity: Double = 0

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("Welkom bij MissionZebra")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
                    .multilineTextAlignment(.center)
                    .opacity(titleOpacity)
                    .scaleEffect(titleScale)

                Spacer().frame(height: 16)

                Text("Log eerst in als ouder. Daarna kan je instellen of dit toestel door een ouder of een kind gebruikt wordt.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
                    .offset(y: textOffset)

                Spacer().frame(height: 32)

                Button(action: {
                    router.navigate(to: .parentLogin)
                }) {
                    Text("Inloggen als ouder")
                        .font(.title3)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                }
                .buttonStyle(.borderedProminent)
                .opacity(buttonOpacity)
                .offset(y: buttonOffset)

                Spacer()
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                titleOpacity = 1
                titleScale = 1
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                textOpacity = 1
                textOffset = 0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                buttonOpacity = 1
                buttonOffset = 0
            }
        }
    }
}
