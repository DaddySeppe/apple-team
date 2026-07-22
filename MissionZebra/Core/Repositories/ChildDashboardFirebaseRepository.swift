import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class ChildDashboardFirebaseRepository: ObservableObject {
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()

    private func parentId() -> String? {
        auth.currentUser?.uid
    }

    private func childDoc(childId: String) -> DocumentReference? {
        guard let parentId = parentId() else { return nil }
        return firestore
            .collection("parents")
            .document(parentId)
            .collection("children")
            .document(childId)
    }

    func childFlow(childId: String) -> AnyPublisher<Child?, Never> {
        let subject = CurrentValueSubject<Child?, Never>(nil)
        guard let childReference = childDoc(childId: childId) else {
            return Just(nil).eraseToAnyPublisher()
        }

        let listener = childReference.addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot, error == nil, snapshot.exists else {
                    subject.send(nil)
                    return
                }

                let data = snapshot.data() ?? [:]
                let equippedItems = FirestoreDecoding.stringMap(data["equippedItems"])
                let deviceScreenTimes = FirestoreDecoding.intMap(data["deviceScreenTimes"])
                let deviceScreenTimeDates = FirestoreDecoding.stringMap(data["deviceScreenTimeDates"])
                let storedUsedMinutes = data["dailyScreenTimeUsedMinutes"] != nil
                    ? FirestoreDecoding.int(data["dailyScreenTimeUsedMinutes"])
                    : FirestoreDecoding.int(data["screenTimeUsedMinutes"])
                let schedule = ScreenTimeSchedule.fromFirestore(data["screenTimeSchedule"])
                let rawConfiguredLimit = data["dailyScreenTimeLimitMinutes"] != nil
                    ? FirestoreDecoding.int(data["dailyScreenTimeLimitMinutes"], default: 120)
                    : FirestoreDecoding.int(data["screenTimeLimitMinutes"], default: 120)
                let lastValidLimit = FirestoreDecoding.int(data["lastValidDailyScreenTimeLimitMinutes"], default: 60)
                let configuredLimit = rawConfiguredLimit > 0
                    ? rawConfiguredLimit
                    : ScreenTimeDefaults.sanitizedLimit(lastValidLimit)
                let child = Child(
                    id: snapshot.documentID,
                    name: data["name"] as? String ?? "",
                    birthDate: data["birthDate"] as? String,
                    points: FirestoreDecoding.int(data["points"]),
                    dailyScreenTimeUsedMinutes: Child.aggregatedDailyScreenTime(
                        storedUsedMinutes: storedUsedMinutes,
                        deviceScreenTimes: deviceScreenTimes,
                        deviceScreenTimeDates: deviceScreenTimeDates,
                        todayKey: ParentChildrenFirebaseRepository.todayKey()
                    ),
                    dailyScreenTimeLimitMinutes: schedule.effectiveLimitMinutes(defaultLimitMinutes: configuredLimit),
                    isBlocked: FirestoreDecoding.bool(data["isBlocked"]),
                    purchasedAccessoryIds: FirestoreDecoding.stringArray(data["purchasedAccessoryIds"]),
                    equippedAccessoryId: data["equippedAccessoryId"] as? String,
                    equippedItems: equippedItems.isEmpty ? Self.legacyEquippedItems(data["equippedAccessoryId"] as? String) : equippedItems,
                    streak: FirestoreDecoding.int(data["streak"]),
                    lastStreakCheckDate: data["lastStreakCheckDate"] as? String,
                    motivationalMessage: data["motivationalMessage"] as? String,
                    screenTimeHistory: FirestoreDecoding.intMap(data["screenTimeHistory"]),
                    deviceScreenTimes: deviceScreenTimes,
                    deviceNames: FirestoreDecoding.stringMap(data["deviceNames"]),
                    deviceScreenTimeDates: deviceScreenTimeDates,
                    screenTimeSchedule: schedule,
                    screenTimePermissionGranted: FirestoreDecoding.optionalBool(data["screenTimePermissionGranted"])
                )
                subject.send(child)
            }

        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    func tasksFlow(childId: String) -> AnyPublisher<[MZTask], Never> {
        let subject = CurrentValueSubject<[MZTask], Never>([])
        guard let parentId = parentId() else {
            return Just([]).eraseToAnyPublisher()
        }

        let listener = firestore
            .collection("parents")
            .document(parentId)
            .collection("tasks")
            .whereField("childId", isEqualTo: childId)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot, error == nil else {
                    subject.send([])
                    return
                }

                let tasks: [MZTask] = snapshot.documents.map { doc in
                    let data = doc.data()
                    return MZTask(
                        id: doc.documentID,
                        title: data["title"] as? String ?? "",
                        points: FirestoreDecoding.int(data["points"]),
                        childId: data["childId"] as? String,
                        childName: data["childName"] as? String,
                        parentId: data["parentId"] as? String,
                        pendingApproval: FirestoreDecoding.bool(data["pendingApproval"]),
                        completed: FirestoreDecoding.bool(data["completed"]),
                        dueDate: data["dueDate"] as? String,
                        recurrence: data["recurrence"] as? String,
                        purpose: data["purpose"] as? String ?? "",
                        contributionTarget: data["contributionTarget"] as? String ?? "",
                        childReflection: data["childReflection"] as? String ?? "",
                        effortLevel: data["effortLevel"] as? String ?? "",
                        parentFeedback: data["parentFeedback"] as? String ?? "",
                        createdAt: FirestoreDecoding.int64(data["createdAt"]),
                        updatedAt: FirestoreDecoding.int64(data["updatedAt"])
                    )
                }
                subject.send(tasks)
            }

        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    func rewardsFlow(childId: String) -> AnyPublisher<[Reward], Never> {
        let subject = CurrentValueSubject<[Reward], Never>([])
        guard let parentId = parentId() else {
            return Just([]).eraseToAnyPublisher()
        }

        let listener = firestore
            .collection("parents")
            .document(parentId)
            .collection("rewards")
            .whereField("childId", isEqualTo: childId)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot, error == nil else {
                    subject.send([])
                    return
                }

                let rewards: [Reward] = snapshot.documents.map { doc in
                    let data = doc.data()
                    return Reward(
                        id: doc.documentID,
                        title: data["title"] as? String ?? "",
                        costPoints: FirestoreDecoding.int(data["costPoints"]),
                        childId: data["childId"] as? String,
                        redeemed: FirestoreDecoding.bool(data["redeemed"]),
                        requested: FirestoreDecoding.bool(data["requested"])
                    )
                }
                subject.send(rewards)
            }

        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    func updateDailyScreenTime(childId: String, usedMinutes: Int) async {
        guard let childReference = childDoc(childId: childId) else { return }
        try? await childReference
            .updateData(["dailyScreenTimeUsedMinutes": usedMinutes])
    }

    func markTaskDone(childId: String, taskId: String) async {
        guard let parentId = parentId() else { return }
        try? await firestore
            .collection("parents")
            .document(parentId)
            .collection("tasks")
            .document(taskId)
            .updateData(["pendingApproval": true])
    }

    func redeemReward(childId: String, rewardId: String) async {
        guard let parentId = parentId() else { return }
        try? await firestore
            .collection("parents")
            .document(parentId)
            .collection("rewards")
            .document(rewardId)
            .updateData(["redeemed": true])
    }

    func endSession(childId: String) async {
        guard let childReference = childDoc(childId: childId) else { return }
        try? await childReference.setData([
            "lastSessionEndedAt": Timestamp(date: Date())
        ], merge: true)
    }

    private static func legacyEquippedItems(_ accessoryId: String?) -> [String: String] {
        guard let accessoryId else { return [:] }
        return [ZebraCategory.HOOFD.rawValue: accessoryId]
    }
}
