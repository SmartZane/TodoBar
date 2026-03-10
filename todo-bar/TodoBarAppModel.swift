//
//  TodoBarAppModel.swift
//  todo-bar
//
//  Created by Codex on 2026/3/10.
//

import Foundation
import Observation

@MainActor
@Observable
final class TodoBarAppModel {
    var viewState: TodoBarViewState = .loading
    var availableLists: [ReminderList] = []
    var visibleReminders: [ReminderItem] = []
    var launchAtLoginEnabled = false
    var isRefreshing = false
    var authorizationStatusLabel = "unknown"

    var menuBarTitle: String {
        viewState.menuBarTitle
    }

    private let reminderService: ReminderServiceProtocol
    private let launchAtLoginManager: LaunchAtLoginManaging
    private var bindingManager: ListBindingManaging
    private let appCommands: AppCommandsHandling
    private let changeObserver: ReminderChangeObserving
    private let lifecycleObserver: ApplicationLifecycleObserving
    private var pendingRefresh = false

    init(
        reminderService: ReminderServiceProtocol? = nil,
        launchAtLoginManager: LaunchAtLoginManaging? = nil,
        bindingManager: ListBindingManaging? = nil,
        appCommands: AppCommandsHandling? = nil,
        changeObserver: ReminderChangeObserving? = nil,
        lifecycleObserver: ApplicationLifecycleObserving? = nil,
        autoRefreshOnLaunch: Bool = true
    ) {
        self.reminderService = reminderService ?? ReminderService()
        self.launchAtLoginManager = launchAtLoginManager ?? LaunchAtLoginService()
        self.bindingManager = bindingManager ?? ListBindingManager()
        self.appCommands = appCommands ?? SystemAppCommands()
        self.changeObserver = changeObserver ?? ReminderChangeObserver()
        self.lifecycleObserver = lifecycleObserver ?? ApplicationLifecycleObserver()
        self.launchAtLoginEnabled = self.launchAtLoginManager.isEnabled
        observeRefreshTriggers()

        if autoRefreshOnLaunch {
            pendingRefresh = true
        }
    }

    func refresh(promptForAccess: Bool = false) async {
        if isRefreshing {
            pendingRefresh = true
            return
        }

        isRefreshing = true
        authorizationStatusLabel = reminderService.authorizationSnapshot().label
        defer {
            isRefreshing = false
        }

        do {
            let access = try await reminderService.ensureAccess(promptIfNeeded: promptForAccess)
            authorizationStatusLabel = reminderService.authorizationSnapshot().label
            guard access == .granted else {
                visibleReminders = []
                viewState = .accessDenied
                await finishRefreshIfNeeded()
                return
            }

            guard let selectedListID = bindingManager.selectedListID else {
                visibleReminders = []
                viewState = .noSelection
                await finishRefreshIfNeeded()
                return
            }

            guard let selectedList = try await reminderService.fetchList(forID: selectedListID) else {
                bindingManager.selectedListID = nil
                visibleReminders = []
                viewState = .missingList
                await finishRefreshIfNeeded()
                return
            }

            let reminders = try await reminderService.fetchIncompleteReminders(forListID: selectedList.id)
            visibleReminders = reminders
            viewState = .ready(listName: selectedList.title, count: reminders.count)
        } catch {
            visibleReminders = []
            viewState = .error(error.localizedDescription)
        }

        await finishRefreshIfNeeded()
    }

    func loadAvailableListsIfNeeded() async {
        guard availableLists.isEmpty else {
            return
        }

        await loadAvailableLists()
    }

    func loadAvailableLists() async {
        authorizationStatusLabel = reminderService.authorizationSnapshot().label

        guard ["authorized", "fullAccess"].contains(authorizationStatusLabel) else {
            return
        }

        do {
            availableLists = try await reminderService.fetchLists()
        } catch {
            availableLists = []
        }
    }

    func selectList(_ listID: String) async {
        bindingManager.selectedListID = listID
        await refresh()
    }

    func clearSelection() async {
        bindingManager.selectedListID = nil
        await refresh()
    }

    func requestPermission() async {
        await refresh(promptForAccess: true)
    }

    func setLaunchAtLogin(_ isEnabled: Bool) {
        do {
            try launchAtLoginManager.setEnabled(isEnabled)
            launchAtLoginEnabled = launchAtLoginManager.isEnabled
        } catch {
            launchAtLoginEnabled = launchAtLoginManager.isEnabled
            viewState = .error(error.localizedDescription)
        }
    }

    func completeReminder(_ reminderID: String) async {
        guard let reminderIndex = visibleReminders.firstIndex(where: { $0.id == reminderID }) else {
            return
        }

        let removedReminder = visibleReminders.remove(at: reminderIndex)
        applyVisibleReminderState()

        do {
            try await reminderService.completeReminder(withID: reminderID)
        } catch {
            visibleReminders.insert(removedReminder, at: reminderIndex)
            viewState = .error(error.localizedDescription)
            await refresh()
        }
    }

    func openRemindersApp() {
        appCommands.openRemindersApp()
    }

    func openRemindersSettings() {
        appCommands.openRemindersSettings()
    }

    func quit() {
        appCommands.quit()
    }

    private func observeRefreshTriggers() {
        changeObserver.start { [weak self] in
            guard let self else { return }

            Task {
                await self.refresh()
            }
        }

        lifecycleObserver.start(onLaunch: { [weak self] in
            guard let self else { return }

            Task {
                if self.pendingRefresh {
                    self.pendingRefresh = false
                    await self.refresh(promptForAccess: true)
                }
            }
        }, onActive: { [weak self] in
            guard let self else { return }

            Task {
                await self.refresh()
            }
        })
    }

    private func finishRefreshIfNeeded() async {
        guard pendingRefresh else {
            return
        }

        pendingRefresh = false
        await refresh()
    }

    private func applyVisibleReminderState() {
        if case let .ready(listName, _) = viewState {
            viewState = .ready(listName: listName, count: visibleReminders.count)
        }
    }
}

struct ReminderList: Identifiable, Equatable {
    let id: String
    let title: String
}
