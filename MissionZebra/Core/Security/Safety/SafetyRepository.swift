import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

class SafetyRepository {
    private let auth: Auth
    private let firestore: Firestore
    private let childrenRepository: ParentChildrenFirebaseRepository
    private let analyzer: RiskAnalyzer

    init(
        auth: Auth = Auth.auth(),
        firestore: Firestore = Firestore.firestore(),
        childrenRepository: ParentChildrenFirebaseRepository = ParentChildrenFirebaseRepository(),
        analyzer: RiskAnalyzer = RiskAnalyzer()
    ) {
        self.auth = auth
        self.firestore = firestore
        self.childrenRepository = childrenRepository
        self.analyzer = analyzer
    }

    func safetyOverviewFlow() -> AnyPublisher<SafetyOverview, Never> {
        let subject = CurrentValueSubject<SafetyOverview, Never>(SafetyOverview())
        var children: [Child] = []
        var snapshotsByChild: [String: [SafetyUsageSnapshot]] = [:]
        var snapshotListeners: [ListenerRegistration] = []

        func publish() {
            let snapshots = snapshotsByChild.values
                .flatMap { $0 }
                .sorted { lhs, rhs in
                    if lhs.childId != rhs.childId { return lhs.childId < rhs.childId }
                    return lhs.date < rhs.date
                }
            subject.send(Self.buildOverview(children: children, snapshots: snapshots, analyzer: analyzer))
        }

        let childrenCancellable = childrenRepository.childrenFlow()
            .sink { newChildren in
                children = newChildren
                snapshotsByChild = [:]
                snapshotListeners.forEach { $0.remove() }
                snapshotListeners.removeAll()

                guard let user = self.auth.currentUser, !children.isEmpty else {
                    publish()
                    return
                }

                children.forEach { child in
                    let listener = self.firestore
                        .collection("parents")
                        .document(user.uid)
                        .collection("children")
                        .document(child.id)
                        .collection(Self.safetyDailyCollection)
                        .addSnapshotListener { snapshot, _ in
                            snapshotsByChild[child.id] = snapshot?.documents.compactMap { document in
                                Self.safetySnapshot(from: document.data())
                            }
                            .sorted { $0.date < $1.date } ?? []
                            publish()
                        }
                    snapshotListeners.append(listener)
                }

                publish()
            }

        return subject
            .handleEvents(receiveCancel: {
                childrenCancellable.cancel()
                snapshotListeners.forEach { $0.remove() }
            })
            .eraseToAnyPublisher()
    }

    func saveSnapshot(_ snapshot: SafetyUsageSnapshot) async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            try await firestore
                .collection("parents")
                .document(user.uid)
                .collection("children")
                .document(snapshot.childId)
                .collection(Self.safetyDailyCollection)
                .document(snapshot.date)
                .setData(Self.firestoreData(from: snapshot, parentId: user.uid))
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    static func buildOverview(
        children: [Child],
        snapshots: [SafetyUsageSnapshot],
        analyzer: RiskAnalyzer = RiskAnalyzer()
    ) -> SafetyOverview {
        let snapshotsByChild = Dictionary(grouping: snapshots, by: \.childId)
        let signals = children.flatMap { child -> [RiskSignal] in
            let childSnapshots = (snapshotsByChild[child.id] ?? []).sorted { $0.date < $1.date }
            let today = childSnapshots.last
            return analyzer.analyze(
                childId: child.id,
                childName: child.name,
                today: today,
                recentHistory: childSnapshots,
                dailyLimitMinutes: child.dailyScreenTimeLimitMinutes,
                trackingPermissionGranted: child.screenTimePermissionGranted
            )
        }

        return SafetyOverview(
            children: children,
            snapshots: snapshots,
            signals: signals,
            latestTrackedAt: snapshots.map(\.trackedAt).max()
        )
    }

    static func safetySnapshot(from data: [String: Any]) -> SafetyUsageSnapshot {
        SafetyUsageSnapshot(
            childId: data["childId"] as? String ?? "",
            deviceId: data["deviceId"] as? String ?? "",
            date: data["date"] as? String ?? "",
            totalMinutes: FirestoreDecoding.int(data["totalMinutes"]),
            nightMinutes: FirestoreDecoding.int(data["nightMinutes"]),
            categoryMinutes: categoryMap(data["categoryMinutes"]),
            categoryOpenCounts: categoryMap(data["categoryOpenCounts"]),
            openCount: FirestoreDecoding.int(data["openCount"]),
            trackedAt: FirestoreDecoding.int64(data["trackedAt"])
        )
    }

    static func firestoreData(from snapshot: SafetyUsageSnapshot, parentId: String) -> [String: Any] {
        [
            "parentId": parentId,
            "childId": snapshot.childId,
            "deviceId": snapshot.deviceId,
            "date": snapshot.date,
            "totalMinutes": snapshot.totalMinutes,
            "nightMinutes": snapshot.nightMinutes,
            "categoryMinutes": snapshot.categoryMinutes.reduce(into: [String: Int]()) { result, entry in
                result[entry.key.rawValue] = entry.value
            },
            "categoryOpenCounts": snapshot.categoryOpenCounts.reduce(into: [String: Int]()) { result, entry in
                result[entry.key.rawValue] = entry.value
            },
            "openCount": snapshot.openCount,
            "trackedAt": snapshot.trackedAt
        ]
    }

    private static func categoryMap(_ value: Any?) -> [SafetyCategory: Int] {
        guard let raw = FirestoreDecoding.rawMap(value) else { return [:] }
        return raw.reduce(into: [SafetyCategory: Int]()) { result, entry in
            guard let category = SafetyCategory(rawValue: entry.key) else { return }
            result[category] = FirestoreDecoding.int(entry.value)
        }
    }

    private static let safetyDailyCollection = "safetyDaily"
}
