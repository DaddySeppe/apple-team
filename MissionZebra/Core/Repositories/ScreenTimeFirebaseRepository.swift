import Foundation
import FirebaseAuth
import FirebaseFirestore

class ScreenTimeFirebaseRepository: ObservableObject {
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()
    private var currentSessionStartDate: Date?

    func startSession() {
        currentSessionStartDate = Date()
    }

    func endSession(childId: String) async -> Result<Void, Error> {
        guard let start = currentSessionStartDate else {
            return .success(())
        }
        currentSessionStartDate = nil
        let end = Date()
        let durationMinutes = Int(end.timeIntervalSince(start) / 60.0)

        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }

            _ = try await firestore
                .collection("parents")
                .document(user.uid)
                .collection("children")
                .document(childId)
                .collection("screenSessions")
                .addDocument(data: [
                    "childId": childId,
                    "startMillis": Int64(start.timeIntervalSince1970 * 1000),
                    "endMillis": Int64(end.timeIntervalSince1970 * 1000),
                    "durationMinutes": durationMinutes
                ])

            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
