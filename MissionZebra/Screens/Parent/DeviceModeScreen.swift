import SwiftUI

struct DeviceModeScreen: View {
    @EnvironmentObject var router: NavigationRouter

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("Hoe wil je dit toestel gebruiken?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 16)

                Text("Kies of dit toestel vooral door jou als ouder wordt gebruikt of door een kind.")
                    .font(.body)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 24)

                Button(action: {
                    SessionManager.shared.setDeviceForChild(false)
                    router.reset(to: .parentDashboard)
                }) {
                    Text("Dit toestel is voor mij als ouder")
                        .font(.body)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                }
                .buttonStyle(.borderedProminent)

                Spacer().frame(height: 16)

                Button(action: {
                    SessionManager.shared.setDeviceForChild(true)
                    router.reset(to: .childLogin)
                }) {
                    Text("Dit toestel is voor een kind")
                        .font(.body)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding(24)
        }
    }
}
