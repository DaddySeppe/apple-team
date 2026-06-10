import Foundation

final class LanguagePreferences: ObservableObject {
    static let shared = LanguagePreferences()

    @Published var language: String {
        didSet {
            UserDefaults.standard.set(language, forKey: "missionzebra_language")
        }
    }

    private init() {
        self.language = UserDefaults.standard.string(forKey: "missionzebra_language")
            ?? Locale.current.language.languageCode?.identifier
            ?? "nl"
        if language != "nl" && language != "en" {
            language = "nl"
        }
    }
}
