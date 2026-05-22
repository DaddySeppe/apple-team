import Foundation
import FirebaseAuth
import FirebaseFirestore

enum UserFacingError {
    static func message(for error: Error, default defaultMessage: String) -> String {
        let nsError = error as NSError

        if let domainMessage = domainMessage(for: nsError.localizedDescription) {
            return domainMessage
        }

        if nsError.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .invalidEmail:
                return "Vul een geldig e-mailadres in."
            case .wrongPassword, .invalidCredential:
                return "E-mailadres of wachtwoord klopt niet."
            case .userNotFound:
                return "Er bestaat nog geen account met dit e-mailadres."
            case .emailAlreadyInUse:
                return "Er bestaat al een account met dit e-mailadres."
            case .weakPassword:
                return "Kies een sterker wachtwoord van minstens 6 tekens."
            case .networkError:
                return "Er is geen goede internetverbinding. Controleer je verbinding en probeer opnieuw."
            case .tooManyRequests:
                return "Er zijn te veel pogingen gedaan. Wacht even en probeer opnieuw."
            default:
                if let response = nsError.userInfo["FIRAuthErrorUserInfoDeserializedResponseKey"] as? [String: Any],
                   let message = response["message"] as? String {
                    return firebaseAuthBackendMessage(message, fallback: defaultMessage)
                }
                return defaultMessage
            }
        }

        if nsError.domain == FirestoreErrorDomain,
           let code = FirestoreErrorCode.Code(rawValue: nsError.code) {
            switch code {
            case .unavailable:
                return "Er is geen goede internetverbinding. Controleer je verbinding en probeer opnieuw."
            case .permissionDenied, .unauthenticated:
                return "Je sessie is verlopen. Log opnieuw in en probeer het nog eens."
            case .notFound:
                return "Deze gegevens bestaan niet meer. Vernieuw het scherm en probeer opnieuw."
            case .aborted, .deadlineExceeded:
                return "Het duurde te lang om op te slaan. Probeer het nog eens."
            default:
                return defaultMessage
            }
        }

        if (nsError.domain == NSURLErrorDomain) {
            return "Er is geen goede internetverbinding. Controleer je verbinding en probeer opnieuw."
        }

        return defaultMessage
    }

    private static func domainMessage(for message: String) -> String? {
        switch message.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "Niet ingelogd", "Not logged in", "User is not logged in.":
            return "Je sessie is verlopen. Log opnieuw in en probeer het nog eens."
        case "Geen kind gekoppeld aan beloning":
            return "Deze beloning is niet meer gekoppeld aan een kind."
        case "Beloning is al ingewisseld":
            return "Deze beloning is al ingewisseld."
        case "Niet genoeg punten", "Niet genoeg punten!":
            return "Je hebt nog niet genoeg punten."
        case "Je hebt dit item al!":
            return "Je hebt dit item al."
        default:
            return nil
        }
    }

    private static func firebaseAuthBackendMessage(_ message: String, fallback: String) -> String {
        switch message {
        case let value where value.contains("API key expired") || value.contains("API_KEY_INVALID"):
            return "Firebase is niet juist geconfigureerd. De API key in GoogleService-Info.plist is verlopen."
        case let value where value.contains("EMAIL_NOT_FOUND"):
            return "Er bestaat nog geen account met dit e-mailadres."
        case let value where value.contains("INVALID_PASSWORD") || value.contains("INVALID_LOGIN_CREDENTIALS"):
            return "E-mailadres of wachtwoord klopt niet."
        case let value where value.contains("USER_DISABLED"):
            return "Dit account is uitgeschakeld."
        default:
            return fallback
        }
    }
}

extension Error {
    func userFriendlyMessage(_ defaultMessage: String) -> String {
        UserFacingError.message(for: self, default: defaultMessage)
    }
}
