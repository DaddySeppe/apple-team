import SwiftUI

struct SplashScreen: View {
    let onSplashFinished: () -> Void

    @State private var startAnimation = false
    @State private var progress: Double = 0.0

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 48) {
                // Logo with animation
                Image("logozebra")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 180)
                    .scaleEffect(startAnimation ? 1.0 : 0.5)
                    .opacity(startAnimation ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 1.0), value: startAnimation)

                // Loading bar
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color("MzSky")))
                    .frame(width: 200)
            }

            // Branding at the bottom
            VStack {
                Spacer()
                Text("Mission Zebra")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .opacity(startAnimation ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 1.0), value: startAnimation)
                    .padding(.bottom, 48)
            }
        }
        .onAppear {
            startAnimation = true
            simulateLoading()
        }
    }

    private func simulateLoading() {
        let steps = 100
        let stepDelay = 0.02

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDelay * Double(i)) {
                progress = Double(i) / Double(steps)
                if i == steps {
                    onSplashFinished()
                }
            }
        }
    }
}
