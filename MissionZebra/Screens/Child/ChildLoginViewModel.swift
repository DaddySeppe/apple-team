import Foundation
import Combine

struct ChildLoginUiState {
    var children: [Child] = []
    var isLoading: Bool = true
    var error: String? = nil
    var newChildName: String = ""
    var isSavingChild: Bool = false
}

class ChildLoginViewModel: ObservableObject {
    @Published var uiState = ChildLoginUiState()

    private let repository: ParentChildrenFirebaseRepository
    private var cancellables = Set<AnyCancellable>()

    init(repository: ParentChildrenFirebaseRepository = ParentChildrenFirebaseRepository()) {
        self.repository = repository
        observeChildren()
    }

    private func observeChildren() {
        repository.childrenFlow()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] children in
                self?.uiState.children = children
                self?.uiState.isLoading = false
                self?.uiState.error = nil
            }
            .store(in: &cancellables)
    }

    func onNewChildNameChange(_ value: String) {
        uiState.newChildName = value
        uiState.error = nil
    }

    func addChild() {
        let name = uiState.newChildName.trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            uiState.error = "Vul een naam in"
            return
        }

        uiState.isSavingChild = true
        uiState.error = nil

        Task {
            let result = await repository.addChild(name: name, limitMinutes: ScreenTimeDefaults.dailyLimitMinutes)
            await MainActor.run {
                switch result {
                case .success:
                    uiState.newChildName = ""
                    uiState.isSavingChild = false
                case .failure(let error):
                    uiState.isSavingChild = false
                    uiState.error = error.localizedDescription
                }
            }
        }
    }
}
