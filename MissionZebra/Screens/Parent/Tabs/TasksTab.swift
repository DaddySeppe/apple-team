import SwiftUI

// MARK: - Filter & Sort Enums

enum TaskFilterStatus: String, CaseIterable {
    case all = "Alle"
    case pending = "In afwachting"
    case completed = "Voltooid"
    case active = "Actief"

    var label: String { rawValue }
}

enum TaskSortOption: String, CaseIterable {
    case dateDesc = "Nieuwste eerst"
    case dateAsc = "Oudste eerst"
    case pointsDesc = "Meeste punten"
    case pointsAsc = "Minste punten"
    case titleAsc = "Titel A-Z"

    var label: String { rawValue }
}

// MARK: - TAB 2: TAKEN (Modernized)

struct TasksPage: View {
    @EnvironmentObject var router: NavigationRouter
    let uiState: ParentDashboardUiState
    let onTaskChildSelected: (String) -> Void
    let onNewTaskTitleChange: (String) -> Void
    let onNewTaskPointsChange: (String) -> Void
    let onNewTaskDueDateChange: (Date) -> Void
    let onNewTaskRepeatsWeeklyChange: (Bool) -> Void
    let onNewTaskPurposeChange: (String) -> Void
    let onNewTaskContributionTargetChange: (String) -> Void
    let onAddTaskClick: () -> Void
    let onApproveTask: (String, String) -> Void
    let onRejectTask: (String) -> Void
    let onUpdateTask: (MZTask) -> Void
    let onDeleteTask: (String) -> Void
    let showsAds: Bool
    let onShowInterstitialAd: () -> Void
    let headerContent: AnyView

    @State private var sortOption: TaskSortOption = .dateDesc
    @State private var filterStatus: TaskFilterStatus = .all
    @State private var showAddTaskDialog = false
    @State private var wasSavingTask = false

    private var filteredTasks: [MZTask] {
        TaskOrdering.filter(uiState.tasks, by: filterStatus)
    }

    private var sortedTasks: [MZTask] {
        TaskOrdering.sort(filteredTasks, by: sortOption)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    headerContent

                    // Calendar button
                    Button(action: {
                        onShowInterstitialAd()
                        router.navigate(to: .taskCalendar)
                    }) {
                        HStack {
                            Image(systemName: "calendar")
                                .font(.caption)
                            Text("Bekijk takenkalender")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MZSecondaryButtonStyle())
                    .padding(.horizontal, 16)

                    Spacer().frame(height: 16)

                    // Filter & Sort bar
                    TasksFilterSection(
                        selectedSort: $sortOption,
                        selectedFilter: $filterStatus
                    )

                    Spacer().frame(height: 12)

                    Text("Takenlijst (\(sortedTasks.count))")
                        .font(.body)
                        .fontWeight(.bold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if sortedTasks.isEmpty {
                        EmptyStateCard()
                    } else {
                        ForEach(Array(sortedTasks.enumerated()), id: \.element.id) { index, task in
                            VStack(spacing: 0) {
                                ParentTaskCard(
                                    task: task,
                                    children: uiState.children,
                                    onApprove: { feedback in onApproveTask(task.id, feedback) },
                                    onReject: { onRejectTask(task.id) },
                                    onUpdateTask: onUpdateTask,
                                    onDeleteTask: onDeleteTask,
                                    onShowInterstitialAd: onShowInterstitialAd
                                )

                            }
                        }
                    }

                    Spacer().frame(height: 80)
                }
            }

            // FAB
            Button(action: {
                onShowInterstitialAd()
                showAddTaskDialog = true
            }) {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.accentColor))
                    .shadow(radius: 4)
            }
            .padding(16)
        }
        .sheet(isPresented: $showAddTaskDialog) {
            AddTaskDialog(
                children: uiState.children,
                selectedChildId: uiState.selectedTaskChildId,
                title: uiState.newTaskTitle,
                points: uiState.newTaskPoints,
                dueDate: uiState.newTaskDueDate,
                repeatsWeekly: uiState.newTaskRepeatsWeekly,
                purpose: uiState.newTaskPurpose,
                contributionTarget: uiState.newTaskContributionTarget,
                isSaving: uiState.isSavingTask,
                error: uiState.taskError,
                onChildSelected: onTaskChildSelected,
                onTitleChange: onNewTaskTitleChange,
                onPointsChange: onNewTaskPointsChange,
                onDueDateChange: onNewTaskDueDateChange,
                onRepeatsWeeklyChange: onNewTaskRepeatsWeeklyChange,
                onPurposeChange: onNewTaskPurposeChange,
                onContributionTargetChange: onNewTaskContributionTargetChange,
                onAddClick: {
                    onAddTaskClick()
                },
                onDismiss: { showAddTaskDialog = false }
            )
        }
        .onChange(of: uiState.isSavingTask) { isSaving in
            if wasSavingTask && !isSaving && uiState.taskError == nil {
                showAddTaskDialog = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onShowInterstitialAd()
                }
            }
            wasSavingTask = isSaving
        }
    }
}

// MARK: - Filter Section

struct TasksFilterSection: View {
    @Binding var selectedSort: TaskSortOption
    @Binding var selectedFilter: TaskFilterStatus

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(TaskSortOption.allCases, id: \.self) { option in
                    Button(action: { selectedSort = option }) {
                        HStack {
                            Text(option.label)
                            if option == selectedSort {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color(.tertiarySystemBackground)))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TaskFilterStatus.allCases, id: \.self) { status in
                        let isSelected = status == selectedFilter
                        Button(action: { selectedFilter = status }) {
                            HStack(spacing: 4) {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.caption2)
                                }
                                Text(status.label)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(isSelected ? Color.accentColor.opacity(0.15) : Color(.tertiarySystemBackground))
                            )
                            .foregroundColor(isSelected ? .accentColor : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Parent Task Card

struct ParentTaskCard: View {
    let task: MZTask
    let children: [Child]
    let onApprove: (String) -> Void
    let onReject: () -> Void
    let onUpdateTask: (MZTask) -> Void
    let onDeleteTask: (String) -> Void
    let onShowInterstitialAd: () -> Void

    @State private var showEditDialog = false
    @State private var showDeleteDialog = false
    @State private var showFeedbackDialog = false
    @State private var parentFeedback = ""

    private var childName: String {
        children.first(where: { $0.id == task.childId })?.name ?? "Onbekend"
    }

    private var statusColor: Color {
        if task.completed { return .accentColor }
        if task.pendingApproval { return .red }
        if TaskOrdering.displayStatus(task) == .expired { return .orange }
        return .secondary
    }

    private var statusText: String? {
        switch TaskOrdering.displayStatus(task) {
        case .pendingApproval:
            return "Wacht op goedkeuring"
        case .expired:
            return "Verlopen"
        case .completed:
            return "Voltooid"
        case .active:
            return nil
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Status strip
            Rectangle()
                .fill(statusColor)
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(.body)
                            .fontWeight(.bold)

                        HStack(spacing: 8) {
                            Text(childName)
                                .font(.caption)
                            if let statusText {
                                Text("• \(statusText)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(statusColor)
                            }
                            if let dueDate = task.dueDate {
                                Text("• \(dueDate)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if task.recurrence == MZTask.recurrenceWeekly {
                                Text("• Wekelijks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    Text("\(task.points) pnt")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(.tertiarySystemBackground)))
                }

                // Actions
                if task.pendingApproval && !task.completed {
                    HStack {
                        Button(action: {
                            onShowInterstitialAd()
                            showEditDialog = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button("Afwijzen") {
                            onShowInterstitialAd()
                            onReject()
                        }
                            .font(.caption)
                            .foregroundColor(.red)
                            .buttonStyle(MZSecondaryButtonStyle())

                        Button("Goedkeuren") {
                            onShowInterstitialAd()
                            showFeedbackDialog = true
                        }
                            .font(.caption)
                            .buttonStyle(MZPrimaryButtonStyle())
                    }
                    .padding(.top, 12)
                } else {
                    HStack {
                        Spacer()
                        Button(action: {
                            onShowInterstitialAd()
                            showEditDialog = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(radius: 2))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .alert("Taak bewerken", isPresented: $showEditDialog) {
            // SwiftUI alert limitations - simplified edit
            Button("Verwijderen", role: .destructive) {
                onShowInterstitialAd()
                onDeleteTask(task.id)
            }
            Button("Annuleren", role: .cancel) {}
        }
        .alert("Feedback voor \(childName)", isPresented: $showFeedbackDialog) {
            TextField("Bijv. Mooi volgehouden!", text: $parentFeedback)
            Button("Goedkeuren") {
                onShowInterstitialAd()
                onApprove(parentFeedback.trimmingCharacters(in: .whitespacesAndNewlines))
                parentFeedback = ""
            }
            Button("Annuleren", role: .cancel) {}
        } message: {
            Text("Optioneel bericht voor deze taak.")
        }
    }
}

// MARK: - Empty State Card

struct EmptyStateCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "info.circle")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Geen taken gevonden")
                .font(.body)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.tertiarySystemBackground).opacity(0.3)))
        .padding(16)
    }
}
