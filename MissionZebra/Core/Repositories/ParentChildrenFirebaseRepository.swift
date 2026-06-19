import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class ParentChildrenFirebaseRepository: ObservableObject {
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()

    private func childrenCollection(_ parentUid: String) -> CollectionReference {
        firestore.collection("parents").document(parentUid).collection("children")
    }

    func childrenFlow() -> AnyPublisher<[Child], Never> {
        let subject = CurrentValueSubject<[Child], Never>([])

        guard let user = auth.currentUser else {
            return Just([]).eraseToAnyPublisher()
        }

        let listener = childrenCollection(user.uid).addSnapshotListener { snapshot, error in
            guard let snapshot = snapshot, error == nil else {
                subject.send([])
                return
            }

            let children: [Child] = snapshot.documents.compactMap { doc in
                let data = doc.data()
                let name = data["name"] as? String ?? ""
                let points = data["points"] as? Int ?? 0

                let storedUsedMinutes = (data["dailyScreenTimeUsedMinutes"] as? Int)
                    ?? (data["screenTimeUsedMinutes"] as? Int)
                    ?? 0
                let deviceScreenTimes = Self.intMap(data["deviceScreenTimes"])
                let deviceScreenTimeDates = data["deviceScreenTimeDates"] as? [String: String] ?? [:]
                let today = Self.todayKey()
                let aggregateDeviceMinutes = deviceScreenTimes.reduce(0) { partial, entry in
                    deviceScreenTimeDates[entry.key] == today ? partial + entry.value : partial
                }
                let usedMinutes = max(storedUsedMinutes, aggregateDeviceMinutes)

                let limitMinutes = (data["dailyScreenTimeLimitMinutes"] as? Int)
                    ?? (data["screenTimeLimitMinutes"] as? Int)
                    ?? 60

                let isBlocked = data["isBlocked"] as? Bool ?? false

                let historyRaw = data["screenTimeHistory"] as? [String: Any] ?? [:]
                var history: [String: Int] = [:]
                for (key, value) in historyRaw {
                    if let intVal = value as? Int {
                        history[key] = intVal
                    } else if let numVal = value as? NSNumber {
                        history[key] = numVal.intValue
                    }
                }

                return Child(
                    id: doc.documentID,
                    name: name,
                    points: points,
                    dailyScreenTimeUsedMinutes: usedMinutes,
                    dailyScreenTimeLimitMinutes: limitMinutes,
                    isBlocked: isBlocked,
                    purchasedAccessoryIds: (data["purchasedAccessoryIds"] as? [String]) ?? [],
                    equippedAccessoryId: data["equippedAccessoryId"] as? String,
                    streak: data["streak"] as? Int ?? 0,
                    lastStreakCheckDate: data["lastStreakCheckDate"] as? String,
                    motivationalMessage: data["motivationalMessage"] as? String,
                    screenTimeHistory: history,
                    deviceScreenTimes: deviceScreenTimes,
                    deviceNames: data["deviceNames"] as? [String: String] ?? [:],
                    deviceScreenTimeDates: deviceScreenTimeDates,
                    screenTimePermissionGranted: data["screenTimePermissionGranted"] as? Bool
                )
            }

            subject.send(children)
        }

        // Store listener reference to keep it alive
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    func sendMessage(childId: String, message: String?) async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            try await childrenCollection(user.uid).document(childId)
                .updateData(["motivationalMessage": message as Any])
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func updateStreak(childId: String, newStreak: Int, checkDate: String) async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            try await childrenCollection(user.uid).document(childId)
                .updateData([
                    "streak": newStreak,
                    "lastStreakCheckDate": checkDate
                ])
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func updateChildScreenTimeLimit(childId: String, newLimitMinutes: Int) async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            try await firestore.collection("parents").document(user.uid)
                .collection("children").document(childId)
                .updateData(["dailyScreenTimeLimitMinutes": newLimitMinutes])
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func addChild(name: String, limitMinutes: Int) async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            _ = try await childrenCollection(user.uid).addDocument(data: [
                "name": name,
                "points": 0,
                "dailyScreenTimeUsedMinutes": 0,
                "dailyScreenTimeLimitMinutes": limitMinutes,
                "isBlocked": false,
                "screenTimeHistory": [String: Int]()
            ])
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func deleteChild(childId: String) async {
        guard let user = auth.currentUser else { return }
        try? await firestore.collection("parents").document(user.uid)
            .collection("children").document(childId).delete()
    }

    func deleteTutorialChildren() async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            let snapshot = try await childrenCollection(user.uid)
                .whereField("isTutorial", isEqualTo: true)
                .getDocuments()
            guard !snapshot.documents.isEmpty else { return .success(()) }

            let batch = firestore.batch()
            snapshot.documents.forEach { batch.deleteDocument($0.reference) }
            try await batch.commit()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func addPoints(childId: String, pointsToAdd: Int) async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            let childRef = childrenCollection(user.uid).document(childId)

            try await firestore.runTransaction { transaction, errorPointer in
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(childRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                let currentPoints = snapshot.data()?["points"] as? Int ?? 0
                transaction.updateData(["points": currentPoints + pointsToAdd], forDocument: childRef)
                return nil
            }
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func updateDailyScreenTime(childId: String, minutes: Int) async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            let childRef = childrenCollection(user.uid).document(childId)
            let dateKey = Self.todayKey()
            let deviceSession = SessionManager.shared.getDeviceSession()

            try await childRef.updateData([
                "dailyScreenTimeUsedMinutes": minutes,
                "screenTimeHistory.\(dateKey)": minutes,
                "deviceScreenTimes.\(deviceSession.deviceId)": minutes,
                "deviceNames.\(deviceSession.deviceId)": deviceSession.deviceName,
                "deviceScreenTimeDates.\(deviceSession.deviceId)": dateKey,
                "screenTimePermissionGranted": true
            ])
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func updateScreenTimePermission(childId: String, granted: Bool) async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            try await childrenCollection(user.uid).document(childId)
                .updateData(["screenTimePermissionGranted": granted])
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func setChildBlocked(childId: String, blocked: Bool) async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            try await childrenCollection(user.uid).document(childId)
                .updateData(["isBlocked": blocked])
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func intMap(_ value: Any?) -> [String: Int] {
        let raw = value as? [String: Any] ?? [:]
        var result: [String: Int] = [:]
        for (key, value) in raw {
            if let intValue = value as? Int {
                result[key] = intValue
            } else if let numberValue = value as? NSNumber {
                result[key] = numberValue.intValue
            }
        }
        return result
    }
}
