import Foundation
import Combine

struct ParentDashboardUiState {
    var children: [Child] = []
    var tasks: [MZTask] = []
    var rewards: [Reward] = []
    var familyTimeActive: Bool = false
    var newTaskTitle: String = ""
    var newTaskPoints: String = ""
    var newTaskDueDate: Date = Date()
    var newTaskRepeatsWeekly: Bool = false
    var newTaskPurpose: String = ""
    var newTaskContributionTarget: String = ""
    var selectedTaskChildId: String? = nil
    var isSavingTask: Bool = false
    var newRewardTitle: String = ""
    var newRewardPoints: String = ""
    var selectedRewardChildId: String? = nil
    var isSavingReward: Bool = false
    var taskError: String? = nil
    var rewardError: String? = nil
    var selectedRewardFilterChildId: String? = nil
    var parentTip: String = ""
    var familyInsight: String = ""
    var isAddingChild: Bool = false
    var addChildError: String? = nil
    var premiumStatus: PremiumStatus = PremiumStatus()
    var isUpdatingAppBlocking: Bool = false

    var appBlockingEnabled: Bool {
        children.contains { $0.screenTimeSchedule.appBlockingEnabled }
    }

    var premiumNudgeVariant: PremiumNudgeVariant? {
        PremiumFeatureGate.nudgeVariant(
            childrenCount: children.count,
            tasksCount: tasks.count,
            rewardsCount: rewards.count,
            isPremium: premiumStatus.isPremium
        )
    }
}

class ParentDashboardViewModel: ObservableObject {
    @Published var uiState = ParentDashboardUiState()

    private let tasksRepository: TaskFirebaseRepository
    private let childrenRepository: ParentChildrenFirebaseRepository
    private let rewardsRepository: RewardFirebaseRepository
    private let premiumRepository: PremiumRepository
    private var cancellables = Set<AnyCancellable>()

    // 🔹 KORTE MICRO-TIPS VOOR OUDERS
    private let parentTips = [
        "Telefoon buiten handbereik vermindert je gebruik merkbaar.",
        "Meldingen uitzetten geeft je vaak bijna een uur extra focus per dag.",
        "Kinderen kopiëren jouw schermgedrag sneller dan je denkt.",
        "Plan minstens één schermvrij moment per dag met je gezin.",
        "Leg je gsm niet naast je bed voor meer rust.",
        "Maak afspraken: geen gsm tijdens maaltijden.",
        "Leg je gsm weg als je kind tegen je praat."
    ]

    init(
        tasksRepository: TaskFirebaseRepository = TaskFirebaseRepository(),
        childrenRepository: ParentChildrenFirebaseRepository = ParentChildrenFirebaseRepository(),
        rewardsRepository: RewardFirebaseRepository = RewardFirebaseRepository(),
        premiumRepository: PremiumRepository = PremiumRepository()
    ) {
        self.tasksRepository = tasksRepository
        self.childrenRepository = childrenRepository
        self.rewardsRepository = rewardsRepository
        self.premiumRepository = premiumRepository

        uiState.parentTip = generateDailyTip()
        setupSubscriptions()
    }

    private func generateDailyTip() -> String {
        if parentTips.isEmpty { return "" }
        let millisPerDay: Int64 = 1000 * 60 * 60 * 24
        let dayIndex = Int64(Date().timeIntervalSince1970 * 1000) / millisPerDay
        let index = Int(dayIndex % Int64(parentTips.count))
        return parentTips[index]
    }

    private func setupSubscriptions() {
        childrenRepository.childrenFlow()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] children in
                self?.uiState.children = children
                self?.uiState.familyInsight = self?.generateFamilyInsight(children: children) ?? ""
            }
            .store(in: &cancellables)

        tasksRepository.tasksFlow()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.uiState.tasks = tasks
            }
            .store(in: &cancellables)

        rewardsRepository.rewardsFlow()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rewards in
                self?.uiState.rewards = rewards
            }
            .store(in: &cancellables)

        premiumRepository.premiumStatusFlow()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.uiState.premiumStatus = status
            }
            .store(in: &cancellables)
    }

    private func generateFamilyInsight(children: [Child]) -> String {
        if children.isEmpty { return "" }

        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var currentWeekTotal: Int = 0
        var previousWeekTotal: Int = 0

        for i in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
            let dateStr = formatter.string(from: date)
            currentWeekTotal += children.reduce(0) { $0 + ($1.screenTimeHistory[dateStr] ?? 0) }
        }

        for i in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: -(i + 7), to: today)!
            let dateStr = formatter.string(from: date)
            previousWeekTotal += children.reduce(0) { $0 + ($1.screenTimeHistory[dateStr] ?? 0) }
        }

        if previousWeekTotal == 0 { return "" }

        let diffMinutes = currentWeekTotal - previousWeekTotal
        let diffHours = diffMinutes / 60

        if diffMinutes < -60 {
            return "Jullie gezin had samen \(abs(diffHours)) uur minder schermtijd dan vorige week. Geweldig! 🎉"
        } else if diffMinutes > 60 {
            return "Jullie gezin had \(diffHours) uur meer schermtijd dan vorige week."
        } else {
            return "Jullie schermtijd is ongeveer gelijk aan vorige week."
        }
    }

    func toggleFamilyTime() {
        uiState.familyTimeActive.toggle()
    }

    func setAppBlockingEnabled(_ enabled: Bool) {
        let children = uiState.children
        guard !children.isEmpty else { return }

        uiState.isUpdatingAppBlocking = true
        uiState.children = children.map { child in
            var updatedChild = child
            updatedChild.screenTimeSchedule.appBlockingEnabled = enabled
            return updatedChild
        }

        Task {
            for child in children {
                var schedule = child.screenTimeSchedule
                schedule.appBlockingEnabled = enabled
                _ = await childrenRepository.updateScreenTimeSchedule(childId: child.id, schedule: schedule)
            }
            await MainActor.run {
                uiState.isUpdatingAppBlocking = false
            }
        }
    }

    // MARK: - Task Management

    func onNewTaskTitleChange(_ value: String) {
        uiState.newTaskTitle = value
        uiState.taskError = nil
    }

    func onNewTaskPointsChange(_ value: String) {
        uiState.newTaskPoints = value.filter { $0.isNumber }
        uiState.taskError = nil
    }

    func onNewTaskDueDateChange(_ value: Date) {
        uiState.newTaskDueDate = value
        uiState.taskError = nil
    }

    func onNewTaskRepeatsWeeklyChange(_ value: Bool) {
        uiState.newTaskRepeatsWeekly = value
        uiState.taskError = nil
    }

    func onNewTaskPurposeChange(_ value: String) {
        uiState.newTaskPurpose = value
        uiState.taskError = nil
    }

    func onNewTaskContributionTargetChange(_ value: String) {
        uiState.newTaskContributionTarget = value
        uiState.taskError = nil
    }

    func onTaskChildSelected(_ childId: String) {
        uiState.selectedTaskChildId = childId
        uiState.taskError = nil
    }

    func addTask() {
        let title = uiState.newTaskTitle.trimmingCharacters(in: .whitespaces)
        let pointsText = uiState.newTaskPoints.trimmingCharacters(in: .whitespaces)
        let purpose = uiState.newTaskPurpose.trimmingCharacters(in: .whitespacesAndNewlines)
        let contributionTarget = uiState.newTaskContributionTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        let childId = uiState.selectedTaskChildId

        if title.isEmpty {
            uiState.taskError = "Vul een taaknaam in"
            return
        }
        if pointsText.isEmpty {
            uiState.taskError = "Vul punten in"
            return
        }
        guard let points = Int(pointsText) else {
            uiState.taskError = "Punten moeten een getal zijn"
            return
        }
        guard let childId = childId else {
            uiState.taskError = "Kies een kind"
            return
        }

        uiState.isSavingTask = true
        uiState.taskError = nil

        Task {
            let result = await tasksRepository.addTask(
                title: title,
                points: points,
                childId: childId,
                dueDate: TaskOrdering.dateKey(from: uiState.newTaskDueDate),
                recurrence: uiState.newTaskRepeatsWeekly ? MZTask.recurrenceWeekly : nil,
                purpose: purpose,
                contributionTarget: contributionTarget
            )
            await MainActor.run {
                switch result {
                case .success:
                    uiState.taskError = nil
                    uiState.newTaskTitle = ""
                    uiState.newTaskPoints = ""
                    uiState.newTaskDueDate = Date()
                    uiState.newTaskRepeatsWeekly = false
                    uiState.newTaskPurpose = ""
                    uiState.newTaskContributionTarget = ""
                case .failure(let error):
                    uiState.taskError = error.localizedDescription
                }
                uiState.isSavingTask = false
            }
        }
    }

    func approveTask(taskId: String, parentFeedback: String = "") {
        Task {
            let result = await tasksRepository.approveTask(taskId: taskId, parentFeedback: parentFeedback)
            await MainActor.run {
                if case .failure(let error) = result {
                    uiState.taskError = error.localizedDescription
                }
            }
        }
    }

    func rejectTask(taskId: String) {
        Task {
            let result = await tasksRepository.rejectTask(taskId: taskId)
            await MainActor.run {
                if case .failure(let error) = result {
                    uiState.taskError = error.localizedDescription
                }
            }
        }
    }

    func updateTask(task: MZTask) {
        Task {
            let result = await tasksRepository.updateTask(task: task)
            await MainActor.run {
                if case .failure(let error) = result {
                    uiState.taskError = error.localizedDescription
                }
            }
        }
    }

    func deleteTask(taskId: String) {
        Task {
            let result = await tasksRepository.deleteTask(taskId: taskId)
            await MainActor.run {
                if case .failure(let error) = result {
                    uiState.taskError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Reward Management

    func onNewRewardTitleChange(_ value: String) {
        uiState.newRewardTitle = value
        uiState.rewardError = nil
    }

    func onNewRewardPointsChange(_ value: String) {
        uiState.newRewardPoints = value.filter { $0.isNumber }
        uiState.rewardError = nil
    }

    func onRewardChildSelected(_ childId: String) {
        uiState.selectedRewardChildId = childId
        uiState.rewardError = nil
    }

    func onRewardFilterChildSelected(_ childId: String?) {
        uiState.selectedRewardFilterChildId = childId
    }

    func addReward() {
        let title = uiState.newRewardTitle.trimmingCharacters(in: .whitespaces)
        let pointsText = uiState.newRewardPoints.trimmingCharacters(in: .whitespaces)
        let childId = uiState.selectedRewardChildId

        if title.isEmpty {
            uiState.rewardError = "Vul een beloning in"
            return
        }
        if pointsText.isEmpty {
            uiState.rewardError = "Vul punten in"
            return
        }
        guard let points = Int(pointsText) else {
            uiState.rewardError = "Punten moeten een getal zijn"
            return
        }
        guard let childId = childId else {
            uiState.rewardError = "Kies een kind"
            return
        }

        uiState.isSavingReward = true
        uiState.rewardError = nil

        Task {
            let result = await rewardsRepository.addReward(title: title, costPoints: points, childId: childId)
            await MainActor.run {
                switch result {
                case .success:
                    uiState.rewardError = nil
                    uiState.newRewardTitle = ""
                    uiState.newRewardPoints = ""
                case .failure(let error):
                    uiState.rewardError = error.localizedDescription
                }
                uiState.isSavingReward = false
            }
        }
    }

    func redeemReward(rewardId: String) {
        Task {
            let result = await rewardsRepository.redeemReward(rewardId: rewardId)
            await MainActor.run {
                if case .failure(let error) = result {
                    uiState.rewardError = error.localizedDescription
                }
            }
        }
    }

    func rejectRewardRequest(rewardId: String) {
        Task {
            let result = await rewardsRepository.cancelRewardRequest(rewardId: rewardId)
            await MainActor.run {
                if case .failure(let error) = result {
                    uiState.rewardError = error.localizedDescription
                }
            }
        }
    }

    func updateReward(reward: Reward) {
        Task {
            let result = await rewardsRepository.updateReward(reward: reward)
            await MainActor.run {
                if case .failure(let error) = result {
                    uiState.rewardError = error.localizedDescription
                }
            }
        }
    }

    func deleteReward(rewardId: String) {
        Task {
            let result = await rewardsRepository.deleteReward(rewardId: rewardId)
            await MainActor.run {
                if case .failure(let error) = result {
                    uiState.rewardError = error.localizedDescription
                }
            }
        }
    }

    func clearTaskError() {
        uiState.taskError = nil
    }

    func clearRewardError() {
        uiState.rewardError = nil
    }

    // MARK: - Child Management

    func deleteChild(childId: String) {
        Task {
            try? await childrenRepository.deleteChild(childId: childId)
        }
    }

    func blockChild(childId: String) {
        Task {
            await childrenRepository.setChildBlocked(childId: childId, blocked: true)
        }
    }

    func unblockChild(childId: String) {
        Task {
            await childrenRepository.setChildBlocked(childId: childId, blocked: false)
        }
    }

    func sendMotivationalMessage(childId: String, message: String) {
        Task {
            await childrenRepository.sendMessage(childId: childId, message: message)
        }
    }

    func addChild(name: String, limitMinutes: Int, birthDate: String? = nil) {
        uiState.isAddingChild = true
        uiState.addChildError = nil

        Task {
            let result = await childrenRepository.addChild(name: name, limitMinutes: limitMinutes, birthDate: birthDate)
            await MainActor.run {
                switch result {
                case .success:
                    uiState.addChildError = nil
                case .failure(let error):
                    uiState.addChildError = error.localizedDescription
                }
                uiState.isAddingChild = false
            }
        }
    }

    func clearAddChildError() {
        uiState.addChildError = nil
    }

    func updateChildScreenTimeLimit(childId: String, minuteLimit: Int) {
        Task {
            await childrenRepository.updateChildScreenTimeLimit(childId: childId, newLimitMinutes: minuteLimit)
        }
    }
}
