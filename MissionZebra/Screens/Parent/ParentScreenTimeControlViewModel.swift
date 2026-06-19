import Foundation
import Combine

struct ParentScreenTimeControlUiState {
    var children: [Child] = []
    var newChildName: String = ""
    var newChildMinutes: String = ""
    var newChildBirthDate: Date = Calendar.current.date(byAdding: .year, value: -8, to: Date()) ?? Date()
    var editedLimits: [String: String] = [:]
    var isLoading: Bool = false
    var error: String? = nil
}

class ParentScreenTimeControlViewModel: ObservableObject {
    @Published var uiState = ParentScreenTimeControlUiState()

    private let childrenRepository: ParentChildrenFirebaseRepository
    private var cancellables = Set<AnyCancellable>()

    init(childrenRepository: ParentChildrenFirebaseRepository = ParentChildrenFirebaseRepository()) {
        self.childrenRepository = childrenRepository
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        childrenRepository.childrenFlow()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] children in
                self?.uiState.children = children
            }
            .store(in: &cancellables)
    }

    // MARK: - Nieuw kind aanmaken

    func onNewChildNameChange(_ value: String) {
        uiState.newChildName = value
        uiState.error = nil
    }

    func onNewChildMinutesChange(_ value: String) {
        uiState.newChildMinutes = value.filter { $0.isNumber }
        uiState.error = nil
    }

    func onNewChildBirthDateChange(_ value: Date) {
        uiState.newChildBirthDate = value
        uiState.error = nil
    }

    func addChild() {
        let name = uiState.newChildName.trimmingCharacters(in: .whitespaces)
        let minutesText = uiState.newChildMinutes.trimmingCharacters(in: .whitespaces)

        if name.isEmpty {
            uiState.error = "Geef een naam in"
            return
        }
        if minutesText.isEmpty {
            uiState.error = "Geef schermtijd in minuten in"
            return
        }

        guard let minutes = Int(minutesText), minutes > 0 else {
            uiState.error = "Schermtijd moet groter dan 0 zijn"
            return
        }

        uiState.isLoading = true

        Task {
            let result = await childrenRepository.addChild(
                name: name,
                limitMinutes: minutes,
                birthDate: Self.dateKey(from: uiState.newChildBirthDate)
            )
            await MainActor.run {
                uiState.isLoading = false
                switch result {
                case .success:
                    uiState.newChildName = ""
                    uiState.newChildMinutes = ""
                    uiState.newChildBirthDate = Calendar.current.date(byAdding: .year, value: -8, to: Date()) ?? Date()
                case .failure(let error):
                    uiState.error = error.localizedDescription
                }
            }
        }
    }

    func deleteChild(childId: String) {
        Task {
            try? await childrenRepository.deleteChild(childId: childId)
        }
    }

    // MARK: - Limiet per kind aanpassen

    func onChildLimitChange(childId: String, value: String) {
        let filtered = value.filter { $0.isNumber }
        uiState.editedLimits[childId] = filtered
        uiState.error = nil
    }

    func saveChildLimit(childId: String) {
        guard let child = uiState.children.first(where: { $0.id == childId }) else { return }

        let text = uiState.editedLimits[childId]?.isEmpty == false
            ? uiState.editedLimits[childId]!
            : String(child.dailyScreenTimeLimitMinutes)

        guard let newLimit = Int(text), newLimit > 0 else {
            uiState.error = "Limiet moet groter dan 0 zijn"
            return
        }

        uiState.isLoading = true

        Task {
            let result = await childrenRepository.updateChildScreenTimeLimit(childId: childId, newLimitMinutes: newLimit)
            await MainActor.run {
                uiState.isLoading = false
                switch result {
                case .success:
                    uiState.editedLimits.removeValue(forKey: childId)
                case .failure(let error):
                    uiState.error = error.localizedDescription
                }
            }
        }
    }

    private static func dateKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
