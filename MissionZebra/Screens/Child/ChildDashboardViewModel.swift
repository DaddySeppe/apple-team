import Foundation
import Combine

struct ChildDashboardUiState {
    var child: Child? = nil
    var tasks: [MZTask] = []
    var rewards: [Reward] = []
    var isLoading: Bool = true
    var error: String? = nil
    var showScreenTimeDialog: Bool = true
    var needsUsagePermission: Bool = false
    var isFocusModeActive: Bool = false
    var focusStartTime: Date? = nil
    var startScreenTimeMinutes: Int = 0
    var focusSessionEarnedPoints: Int? = nil
    var isShopOpen: Bool = false
    var streak: Int = 0
}

class ChildDashboardViewModel: ObservableObject {
    @Published var uiState = ChildDashboardUiState()

    let childId: String
    let childName: String

    private let tasksRepository: TaskFirebaseRepository
    private let childrenRepository: ParentChildrenFirebaseRepository
    private let rewardsRepository: RewardFirebaseRepository
    private let screenTimeRepository: ScreenTimeFirebaseRepository
    private let deviceUsageRepository: DeviceUsageRepository
    private let zebraShopRepository: ZebraShopRepository
    private let safetyUsageProducer: SafetyUsageProducer
    private let shieldController: ScreenTimeShieldController
    private let soundManager = SoundManager()
    private var cancellables = Set<AnyCancellable>()
    private var previousPoints: Int? = nil
    private var screenTimeSyncTimer: Timer?

    init(
        childId: String,
        childName: String,
        tasksRepository: TaskFirebaseRepository = TaskFirebaseRepository(),
        childrenRepository: ParentChildrenFirebaseRepository = ParentChildrenFirebaseRepository(),
        rewardsRepository: RewardFirebaseRepository = RewardFirebaseRepository(),
        screenTimeRepository: ScreenTimeFirebaseRepository = ScreenTimeFirebaseRepository(),
        deviceUsageRepository: DeviceUsageRepository = DeviceUsageRepository(),
        zebraShopRepository: ZebraShopRepository = ZebraShopRepository(),
        safetyUsageProducer: SafetyUsageProducer = SafetyUsageProducer(),
        shieldController: ScreenTimeShieldController = .shared
    ) {
        self.childId = childId
        self.childName = childName
        self.tasksRepository = tasksRepository
        self.childrenRepository = childrenRepository
        self.rewardsRepository = rewardsRepository
        self.screenTimeRepository = screenTimeRepository
        self.deviceUsageRepository = deviceUsageRepository
        self.zebraShopRepository = zebraShopRepository
        self.safetyUsageProducer = safetyUsageProducer
        self.shieldController = shieldController

        screenTimeRepository.startSession()
        observeData()
        Task { _ = await deviceUsageRepository.startDeviceActivityMonitoringIfPossible() }
        startScreenTimeAutoSync()
        checkStreak()
    }

    deinit {
        soundManager.release()
        screenTimeSyncTimer?.invalidate()
    }

    private func checkStreak() {
        Task {
            // Simplified streak check
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let today = formatter.string(from: Date())
            let yesterday = formatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)

            // We'll get the child from the flow
            // For now, wait a bit and use the current state
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second wait for data

            guard let child = uiState.child else { return }

            if child.lastStreakCheckDate == today { return }

            let yesterdayUsage = child.screenTimeHistory[yesterday]
            let limit = child.dailyScreenTimeLimitMinutes

            var calculatedStreak = child.streak

            if child.lastStreakCheckDate != yesterday && child.lastStreakCheckDate != nil {
                calculatedStreak = 0
            }

            if let usage = yesterdayUsage, usage <= limit {
                calculatedStreak += 1
            } else {
                calculatedStreak = 0
            }

            _ = await childrenRepository.updateStreak(childId: childId, newStreak: calculatedStreak, checkDate: today)
        }
    }

    private func observeData() {
        Publishers.CombineLatest3(
            childrenRepository.childrenFlow(),
            tasksRepository.tasksFlow(),
            rewardsRepository.rewardsFlow()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] children, tasks, rewards in
            guard let self = self else { return }
            let child = children.first(where: { $0.id == self.childId })
            self.shieldController.updateShield(for: child)

            // Sound logic
            let currentPoints = child?.points ?? 0
            if let prevPoints = self.previousPoints, currentPoints > prevPoints {
                self.soundManager.playSound(.success)
            }
            self.previousPoints = currentPoints

            let tasksForChild = tasks.filter { $0.childId == self.childId }
            let rewardsForChild = rewards.filter { $0.childId == self.childId }

            self.uiState = ChildDashboardUiState(
                child: child,
                tasks: tasksForChild,
                rewards: rewardsForChild,
                isLoading: false,
                error: self.uiState.error,
                showScreenTimeDialog: self.uiState.showScreenTimeDialog,
                needsUsagePermission: self.uiState.needsUsagePermission,
                isFocusModeActive: self.uiState.isFocusModeActive,
                focusStartTime: self.uiState.focusStartTime,
                startScreenTimeMinutes: self.uiState.startScreenTimeMinutes,
                focusSessionEarnedPoints: self.uiState.focusSessionEarnedPoints,
                isShopOpen: self.uiState.isShopOpen,
                streak: child?.streak ?? 0
            )
        }
        .store(in: &cancellables)
    }

    func dismissMessage() {
        Task {
            await childrenRepository.sendMessage(childId: childId, message: nil)
        }
    }

    private func startScreenTimeAutoSync() {
        screenTimeSyncTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkAndSyncDeviceScreenTime()
        }
    }

    func checkAndSyncDeviceScreenTime() {
        Task {
            if !deviceUsageRepository.hasUsagePermission() {
                _ = await childrenRepository.updateScreenTimePermission(childId: childId, granted: false)
                await MainActor.run {
                    uiState.needsUsagePermission = true
                }
            } else {
                do {
                    let snapshot = await deviceUsageRepository.getTodayUsageSnapshot()
                    if snapshot.isWholeDeviceScreenTime {
                        _ = await childrenRepository.updateDailyScreenTime(
                            childId: childId,
                            minutes: snapshot.minutes,
                            source: snapshot.source.rawValue
                        )
                        _ = await safetyUsageProducer.uploadDeviceActivitySnapshot(
                            childId: childId,
                            usageSnapshot: snapshot
                        )
                    } else {
                        _ = await childrenRepository.updateAppForegroundUsage(
                            childId: childId,
                            minutes: snapshot.minutes,
                            source: snapshot.source.rawValue
                        )
                    }
                    await MainActor.run {
                        uiState.needsUsagePermission = !snapshot.isWholeDeviceScreenTime
                        uiState.error = nil
                    }

                    // Check screen time limit and send notification if needed
                    let limit = uiState.child?.dailyScreenTimeLimitMinutes ?? 60
                    if snapshot.isWholeDeviceScreenTime {
                        NotificationManager.shared.checkAndNotify(
                            childName: childName,
                            usedMinutes: snapshot.minutes,
                            limitMinutes: limit
                        )
                    }
                    await MainActor.run {
                        shieldController.updateShield(for: uiState.child)
                    }
                }
            }
        }
    }

    func usagePermissionDialogHandled() {
        uiState.needsUsagePermission = false
    }

    func markTaskDone(taskId: String, childReflection: String, effortLevel: String) {
        Task {
            let result = await tasksRepository.requestTaskCompletion(
                taskId: taskId,
                childReflection: childReflection,
                effortLevel: effortLevel
            )
            await MainActor.run {
                if case .failure(let error) = result {
                    uiState.error = error.localizedDescription
                }
            }
        }
    }

    func redeemReward(rewardId: String) {
        Task {
            let result = await rewardsRepository.redeemReward(rewardId: rewardId)
            await MainActor.run {
                if case .failure(let error) = result {
                    uiState.error = error.localizedDescription
                }
            }
        }
    }

    func endSession() {
        Task {
            _ = await screenTimeRepository.endSession(childId: childId)
        }
    }

    func dismissScreenTimeDialog() {
        uiState.showScreenTimeDialog = false
    }

    func clearError() {
        uiState.error = nil
    }

    // MARK: - Focus Mode

    func startFocusMode() {
        Task {
            let currentScreenTime = await deviceUsageRepository.getTodayScreenTimeMinutes()
            await MainActor.run {
                uiState.isFocusModeActive = true
                uiState.focusStartTime = Date()
                uiState.startScreenTimeMinutes = currentScreenTime
            }
        }
    }

    func stopFocusMode() {
        Task {
            let startTime = uiState.focusStartTime
            let startScreenTime = uiState.startScreenTimeMinutes

            if let startTime = startTime {
                let currentScreenTime = await deviceUsageRepository.getTodayScreenTimeMinutes()

                let durationSeconds = Date().timeIntervalSince(startTime)
                let totalMinutesElapsed = Int(durationSeconds / 60)

                let screenTimeUsedDuringFocus = max(currentScreenTime - startScreenTime, 0)

                let realFocusMinutes = max(totalMinutesElapsed - screenTimeUsedDuringFocus, 0)

                if realFocusMinutes > 0 {
                    let pointsEarned = realFocusMinutes * 2
                    _ = await childrenRepository.addPoints(childId: childId, pointsToAdd: pointsEarned)

                    await MainActor.run {
                        uiState.focusSessionEarnedPoints = pointsEarned
                    }
                }
            }

            await MainActor.run {
                uiState.isFocusModeActive = false
                uiState.focusStartTime = nil
                uiState.startScreenTimeMinutes = 0
            }
        }
    }

    func clearFocusSessionResult() {
        uiState.focusSessionEarnedPoints = nil
    }

    // MARK: - Zebra Shop

    var availableAccessories: [Accessory] {
        return zebraShopRepository.availableAccessories
    }

    var accessoriesByCategory: [ZebraCategory: [Accessory]] {
        Dictionary(grouping: availableAccessories, by: { $0.category })
    }

    func toggleShop(isOpen: Bool) {
        uiState.isShopOpen = isOpen
    }

    func buyAccessory(accessory: Accessory) {
        Task {
            let result = await zebraShopRepository.buyAccessory(childId: childId, accessory: accessory)
            await MainActor.run {
                if case .failure(let error) = result {
                    uiState.error = error.localizedDescription
                }
            }
        }
    }

    func equipAccessory(accessoryId: String?) {
        Task {
            _ = await zebraShopRepository.equipAccessory(childId: childId, accessoryId: accessoryId)
        }
    }

    func equipCategoryItem(category: ZebraCategory, accessoryId: String?) {
        Task {
            let result = await zebraShopRepository.equipCategoryItem(
                childId: childId,
                category: category,
                accessoryId: accessoryId
            )
            await MainActor.run {
                if case .failure(let error) = result {
                    uiState.error = error.localizedDescription
                }
            }
        }
    }

    func accessoryEmoji(for child: Child?) -> String? {
        guard let child else { return nil }
        if let headItemId = child.equippedItems[ZebraCategory.HOOFD.rawValue],
           let headAccessory = availableAccessories.first(where: { $0.id == headItemId }) {
            return headAccessory.emoji
        }
        if let fallbackId = child.equippedAccessoryId,
           let fallback = availableAccessories.first(where: { $0.id == fallbackId }) {
            return fallback.emoji
        }
        return nil
    }
}
