import Foundation
import Combine

class InMemoryMissionZebraRepository: MissionZebraRepository {

    private let childrenSubject = CurrentValueSubject<[Child], Never>([
        Child(
            id: "lotte",
            name: "Lotte",
            points: 85,
            dailyScreenTimeUsedMinutes: 90,
            dailyScreenTimeLimitMinutes: 120
        ),
        Child(
            id: "milan",
            name: "Milan",
            points: 40,
            dailyScreenTimeUsedMinutes: 45,
            dailyScreenTimeLimitMinutes: 90
        ),
        Child(
            id: "seppe",
            name: "Seppe",
            points: 120,
            dailyScreenTimeUsedMinutes: 130,
            dailyScreenTimeLimitMinutes: 120
        )
    ])

    private let tasksSubject = CurrentValueSubject<[MZTask], Never>([
        MZTask(id: "t1", title: "Huiswerk maken", points: 10),
        MZTask(id: "t2", title: "Kamer opruimen", points: 15),
        MZTask(id: "t3", title: "Helpen in de keuken", points: 5),
        MZTask(id: "t4", title: "10 minuten lezen", points: 8)
    ])

    private let rewardsSubject = CurrentValueSubject<[Reward], Never>([
        Reward(id: "r1", title: "30 min extra schermtijd", costPoints: 50),
        Reward(id: "r2", title: "Filmavond kiezen", costPoints: 100),
        Reward(id: "r3", title: "Weekendactiviteit", costPoints: 200)
    ])

    func getChildren() -> AnyPublisher<[Child], Never> {
        return childrenSubject.eraseToAnyPublisher()
    }

    func getTasks() -> AnyPublisher<[MZTask], Never> {
        return tasksSubject.eraseToAnyPublisher()
    }

    func getRewards() -> AnyPublisher<[Reward], Never> {
        return rewardsSubject.eraseToAnyPublisher()
    }

    func completeTask(taskId: String, childId: String) async {
        guard let task = tasksSubject.value.first(where: { $0.id == taskId }) else { return }

        let updatedTasks = tasksSubject.value.map { t in
            t.id == taskId ? MZTask(id: t.id, title: t.title, points: t.points, childId: t.childId, pendingApproval: t.pendingApproval, completed: true) : t
        }
        tasksSubject.send(updatedTasks)

        let updatedChildren = childrenSubject.value.map { child in
            if child.id == childId {
                return Child(
                    id: child.id,
                    name: child.name,
                    points: child.points + task.points,
                    dailyScreenTimeUsedMinutes: child.dailyScreenTimeUsedMinutes,
                    dailyScreenTimeLimitMinutes: child.dailyScreenTimeLimitMinutes,
                    isBlocked: child.isBlocked,
                    purchasedAccessoryIds: child.purchasedAccessoryIds,
                    equippedAccessoryId: child.equippedAccessoryId,
                    streak: child.streak,
                    lastStreakCheckDate: child.lastStreakCheckDate,
                    motivationalMessage: child.motivationalMessage,
                    screenTimeHistory: child.screenTimeHistory
                )
            } else {
                return child
            }
        }
        childrenSubject.send(updatedChildren)
    }
}
