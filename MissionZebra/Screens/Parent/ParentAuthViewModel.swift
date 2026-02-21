import Foundation
import Combine

struct AuthUiState {
    var email: String = ""
    var password: String = ""
    var isLoading: Bool = false
    var error: String? = nil
}

class ParentAuthViewModel: ObservableObject {
    @Published var uiState = AuthUiState()

    private let authRepository: AuthRepository

    init(authRepository: AuthRepository = AuthRepository()) {
        self.authRepository = authRepository
    }

    func onEmailChange(_ value: String) {
        uiState.email = value
        uiState.error = nil
    }

    func onPasswordChange(_ value: String) {
        uiState.password = value
        uiState.error = nil
    }

    func register(onSuccess: @escaping () -> Void) {
        let current = uiState
        if current.email.trimmingCharacters(in: .whitespaces).isEmpty || current.password.count < 6 {
            uiState.error = "Vul een geldig e-mailadres en een wachtwoord met minstens 6 tekens in"
            return
        }

        uiState.isLoading = true
        uiState.error = nil

        Task {
            let result = await authRepository.registerWithEmail(email: current.email, password: current.password)
            await MainActor.run {
                uiState.isLoading = false
                switch result {
                case .success:
                    onSuccess()
                case .failure(let error):
                    uiState.error = error.localizedDescription
                }
            }
        }
    }

    func login(onSuccess: @escaping () -> Void) {
        let current = uiState
        if current.email.trimmingCharacters(in: .whitespaces).isEmpty || current.password.trimmingCharacters(in: .whitespaces).isEmpty {
            uiState.error = "Vul e-mailadres en wachtwoord in"
            return
        }

        uiState.isLoading = true
        uiState.error = nil

        Task {
            let result = await authRepository.loginWithEmail(email: current.email, password: current.password)
            await MainActor.run {
                uiState.isLoading = false
                switch result {
                case .success:
                    onSuccess()
                case .failure(let error):
                    uiState.error = error.localizedDescription
                }
            }
        }
    }
}
