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
                let points = FirestoreDecoding.int(data["points"])

                let storedUsedMinutes = data["dailyScreenTimeUsedMinutes"] != nil
                    ? FirestoreDecoding.int(data["dailyScreenTimeUsedMinutes"])
                    : FirestoreDecoding.int(data["screenTimeUsedMinutes"])
                let deviceScreenTimes = FirestoreDecoding.intMap(data["deviceScreenTimes"])
                let deviceScreenTimeDates = FirestoreDecoding.stringMap(data["deviceScreenTimeDates"])
                let today = Self.todayKey()
                let usedMinutes = Child.aggregatedDailyScreenTime(
                    storedUsedMinutes: storedUsedMinutes,
                    deviceScreenTimes: deviceScreenTimes,
                    deviceScreenTimeDates: deviceScreenTimeDates,
                    todayKey: today
                )

                let rawConfiguredLimitMinutes = data["dailyScreenTimeLimitMinutes"] != nil
                    ? FirestoreDecoding.int(data["dailyScreenTimeLimitMinutes"], default: 60)
                    : FirestoreDecoding.int(data["screenTimeLimitMinutes"], default: 60)
                let lastValidLimitMinutes = FirestoreDecoding.int(data["lastValidDailyScreenTimeLimitMinutes"], default: 60)
                let configuredLimitMinutes = rawConfiguredLimitMinutes > 0
                    ? rawConfiguredLimitMinutes
                    : ScreenTimeDefaults.sanitizedLimit(lastValidLimitMinutes)
                let screenTimeSchedule = ScreenTimeSchedule.fromFirestore(data["screenTimeSchedule"])
                let limitMinutes = screenTimeSchedule.effectiveLimitMinutes(defaultLimitMinutes: configuredLimitMinutes)

                let isBlocked = FirestoreDecoding.bool(data["isBlocked"])
                let history = FirestoreDecoding.intMap(data["screenTimeHistory"])
                let equippedItems = FirestoreDecoding.stringMap(data["equippedItems"])

                return Child(
                    id: doc.documentID,
                    name: name,
                    birthDate: data["birthDate"] as? String,
                    points: points,
                    dailyScreenTimeUsedMinutes: usedMinutes,
                    dailyScreenTimeLimitMinutes: limitMinutes,
                    isBlocked: isBlocked,
                    purchasedAccessoryIds: FirestoreDecoding.stringArray(data["purchasedAccessoryIds"]),
                    equippedAccessoryId: data["equippedAccessoryId"] as? String,
                    equippedItems: equippedItems.isEmpty
                        ? Self.legacyEquippedItems(data["equippedAccessoryId"] as? String)
                        : equippedItems,
                    streak: FirestoreDecoding.int(data["streak"]),
                    lastStreakCheckDate: data["lastStreakCheckDate"] as? String,
                    motivationalMessage: data["motivationalMessage"] as? String,
                    screenTimeHistory: history,
                    deviceScreenTimes: deviceScreenTimes,
                    deviceNames: FirestoreDecoding.stringMap(data["deviceNames"]),
                    deviceScreenTimeDates: deviceScreenTimeDates,
                    screenTimeSchedule: screenTimeSchedule,
                    screenTimePermissionGranted: FirestoreDecoding.optionalBool(data["screenTimePermissionGranted"])
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
            let sanitizedLimit = ScreenTimeDefaults.sanitizedLimit(newLimitMinutes)
            try await firestore.collection("parents").document(user.uid)
                .collection("children").document(childId)
                .updateData([
                    "dailyScreenTimeLimitMinutes": sanitizedLimit,
                    "lastValidDailyScreenTimeLimitMinutes": sanitizedLimit,
                    "screenTimeSchedule.schoolDayLimitMinutes": sanitizedLimit,
                    "screenTimeSchedule.weekendLimitMinutes": sanitizedLimit,
                    "screenTimeSchedule.vacationLimitMinutes": sanitizedLimit
                ])
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func addChild(name: String, limitMinutes: Int, birthDate: String? = nil, isTutorial: Bool = false) async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            let sanitizedLimit = ScreenTimeDefaults.sanitizedLimit(limitMinutes)
            _ = try await childrenCollection(user.uid).addDocument(data: [
                "name": name,
                "birthDate": birthDate ?? NSNull(),
                "points": 0,
                "dailyScreenTimeUsedMinutes": 0,
                "dailyScreenTimeLimitMinutes": sanitizedLimit,
                "lastValidDailyScreenTimeLimitMinutes": sanitizedLimit,
                "isBlocked": false,
                "screenTimeSchedule": ScreenTimeSchedule().toFirestoreMap(),
                "isTutorial": isTutorial,
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

            _ = try await firestore.runTransaction { transaction, errorPointer in
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(childRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                let currentPoints = FirestoreDecoding.int(snapshot.data()?["points"])
                transaction.updateData(["points": currentPoints + pointsToAdd], forDocument: childRef)
                return nil
            }
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func updateDailyScreenTime(childId: String, minutes: Int, source: String = "DEVICE_ACTIVITY") async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            let childRef = childrenCollection(user.uid).document(childId)
            let dateKey = Self.todayKey()
            let deviceSession = SessionManager.shared.getDeviceSession()

            try await firestore.runTransaction { transaction, errorPointer in
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(childRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }

                var existingDeviceTimes = FirestoreDecoding.intMap(snapshot.data()?["deviceScreenTimes"])
                let existingDeviceDates = FirestoreDecoding.stringMap(snapshot.data()?["deviceScreenTimeDates"])
                let existingMinutesForDevice = existingDeviceDates[deviceSession.deviceId] == dateKey
                    ? existingDeviceTimes[deviceSession.deviceId] ?? 0
                    : 0
                let isChildAttributedScreenTime = source == "DEVICE_ACTIVITY_CHILD_ATTRIBUTED"
                let stableMinutes = isChildAttributedScreenTime
                    ? max(minutes, 0)
                    : max(existingMinutesForDevice, minutes)
                existingDeviceTimes[deviceSession.deviceId] = stableMinutes

                let totalMinutes = existingDeviceTimes.reduce(0) { total, entry in
                    if entry.key == deviceSession.deviceId || existingDeviceDates[entry.key] == dateKey {
                        return total + entry.value
                    }
                    return total
                }

                transaction.updateData([
                    "dailyScreenTimeUsedMinutes": totalMinutes,
                    "screenTimeHistory.\(dateKey)": totalMinutes,
                    "deviceScreenTimes.\(deviceSession.deviceId)": stableMinutes,
                    "deviceNames.\(deviceSession.deviceId)": deviceSession.deviceName,
                    "deviceScreenTimeDates.\(deviceSession.deviceId)": dateKey,
                    "screenTimeSource": source,
                    "screenTimePermissionGranted": true
                ], forDocument: childRef)
                return nil
            }
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

    func updateScreenTimeSchedule(childId: String, schedule: ScreenTimeSchedule) async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            try await childrenCollection(user.uid).document(childId)
                .updateData(["screenTimeSchedule": schedule.toFirestoreMap()])
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func updateChildBirthDate(childId: String, birthDate: String?) async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            let value: Any = birthDate ?? FieldValue.delete()
            try await childrenCollection(user.uid).document(childId)
                .updateData(["birthDate": value])
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

    private static func legacyEquippedItems(_ accessoryId: String?) -> [String: String] {
        guard let accessoryId else { return [:] }
        return [ZebraCategory.HOOFD.rawValue: accessoryId]
    }
}
