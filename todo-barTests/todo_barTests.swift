//
//  todo_barTests.swift
//  todo-barTests
//
//  Created by 申震 on 2026/3/10.
//

import Testing
import EventKit
@testable import todo_bar

struct todo_barTests {
    @MainActor
    @Test func refreshLoadsSelectedListCount() async throws {
        let service = MockReminderService(
            accessState: .granted,
            lists: [
                ReminderList(id: "work", title: "工作"),
                ReminderList(id: "personal", title: "个人")
            ],
            remindersByListID: [
                "work": [
                    ReminderItem(id: "r1", title: "整理周报", notes: nil),
                    ReminderItem(id: "r2", title: "发送版本说明", notes: "发给产品和测试")
                ]
            ]
        )
        let binding = InMemoryListBindingManager(selectedListID: "work")
        let model = TodoBarAppModel(
            reminderService: service,
            bindingManager: binding,
            appCommands: MockAppCommands(),
            changeObserver: NoopReminderChangeObserver(),
            lifecycleObserver: NoopApplicationLifecycleObserver(),
            autoRefreshOnLaunch: false
        )

        await model.refresh()

        #expect(model.viewState == .ready(listName: "工作", count: 2))
        #expect(model.visibleReminders.map(\.title) == ["整理周报", "发送版本说明"])
        #expect(model.menuBarTitle == "工作 2")
        #expect(model.availableLists.isEmpty)
        #expect(["authorized", "fullAccess"].contains(model.authorizationStatusLabel))
    }

    @MainActor
    @Test func refreshClearsMissingSelection() async throws {
        let service = MockReminderService(
            accessState: .granted,
            lists: [ReminderList(id: "personal", title: "个人")]
        )
        let binding = InMemoryListBindingManager(selectedListID: "deleted")
        let model = TodoBarAppModel(
            reminderService: service,
            bindingManager: binding,
            appCommands: MockAppCommands(),
            changeObserver: NoopReminderChangeObserver(),
            lifecycleObserver: NoopApplicationLifecycleObserver(),
            autoRefreshOnLaunch: false
        )

        await model.refresh()

        #expect(model.viewState == .missingList)
        #expect(binding.selectedListID == nil)
    }

    @Test func viewStateProvidesStablePresentation() {
        #expect(TodoBarViewState.noSelection.menuBarTitle == "--")
        #expect(TodoBarViewState.accessDenied.message == "请允许 TodoBar 访问提醒事项")
        #expect(TodoBarViewState.ready(listName: "项目A", count: 13).secondaryValue == "13")
    }

    @MainActor
    @Test func loadAvailableListsPreservesListOrder() async throws {
        let service = MockReminderService(
            accessState: .granted,
            lists: [
                ReminderList(id: "project", title: "项目A"),
                ReminderList(id: "work", title: "工作"),
                ReminderList(id: "shopping", title: "购物")
            ],
            remindersByListID: [
                "work": [
                    ReminderItem(id: "r3", title: "第三项", notes: nil),
                    ReminderItem(id: "r1", title: "第一项", notes: nil),
                    ReminderItem(id: "r2", title: "第二项", notes: nil)
                ]
            ]
        )
        let model = TodoBarAppModel(
            reminderService: service,
            bindingManager: InMemoryListBindingManager(selectedListID: "work"),
            appCommands: MockAppCommands(),
            changeObserver: NoopReminderChangeObserver(),
            lifecycleObserver: NoopApplicationLifecycleObserver(),
            autoRefreshOnLaunch: false
        )

        await model.loadAvailableLists()

        #expect(model.availableLists.map(\.id) == ["project", "work", "shopping"])
    }

    @MainActor
    @Test func refreshPreservesCurrentListReminderOrder() async throws {
        let service = MockReminderService(
            accessState: .granted,
            lists: [],
            remindersByListID: [
                "work": [
                    ReminderItem(id: "r3", title: "第三项", notes: nil),
                    ReminderItem(id: "r1", title: "第一项", notes: nil),
                    ReminderItem(id: "r2", title: "第二项", notes: nil)
                ]
            ]
        )
        let model = TodoBarAppModel(
            reminderService: service,
            bindingManager: InMemoryListBindingManager(selectedListID: "work"),
            appCommands: MockAppCommands(),
            changeObserver: NoopReminderChangeObserver(),
            lifecycleObserver: NoopApplicationLifecycleObserver(),
            autoRefreshOnLaunch: false
        )

        await model.refresh()

        #expect(model.visibleReminders.map(\.id) == ["r3", "r1", "r2"])
    }

    @MainActor
    @Test func refreshCoalescesReminderChangesDuringInFlightRefresh() async throws {
        let service = ControlledReminderService()
        let binding = InMemoryListBindingManager(selectedListID: "work")
        let changes = TestReminderChangeObserver()
        let model = TodoBarAppModel(
            reminderService: service,
            bindingManager: binding,
            appCommands: MockAppCommands(),
            changeObserver: changes,
            lifecycleObserver: NoopApplicationLifecycleObserver(),
            autoRefreshOnLaunch: false
        )

        let firstRefresh = Task { await model.refresh() }
        await service.awaitFirstCountRequest()
        service.setCount(7)
        changes.fire()
        await firstRefresh.value
        await Task.yield()

        #expect(model.viewState == .ready(listName: "工作", count: 7))
    }

    @MainActor
    @Test func completingReminderRemovesItAndUpdatesCount() async throws {
        let service = MutableReminderService(
            accessState: .granted,
            lists: [ReminderList(id: "work", title: "工作")],
            counts: ["work": 2]
        )
        let model = TodoBarAppModel(
            reminderService: service,
            bindingManager: InMemoryListBindingManager(selectedListID: "work"),
            appCommands: MockAppCommands(),
            changeObserver: NoopReminderChangeObserver(),
            lifecycleObserver: NoopApplicationLifecycleObserver(),
            autoRefreshOnLaunch: false
        )

        await model.refresh()
        let firstReminderID = try #require(model.visibleReminders.first?.id)

        await model.completeReminder(firstReminderID)

        #expect(service.completedReminderIDs == [firstReminderID])
        #expect(model.visibleReminders.count == 1)
        #expect(model.viewState == .ready(listName: "工作", count: 1))
    }

    @MainActor
    @Test func appBecomingActiveRefreshesAfterPermissionRecovery() async throws {
        let service = MutableReminderService(
            accessState: .denied,
            lists: [ReminderList(id: "work", title: "工作")],
            counts: ["work": 3]
        )
        let binding = InMemoryListBindingManager(selectedListID: "work")
        let lifecycle = TestApplicationLifecycleObserver()
        let model = TodoBarAppModel(
            reminderService: service,
            bindingManager: binding,
            appCommands: MockAppCommands(),
            changeObserver: NoopReminderChangeObserver(),
            lifecycleObserver: lifecycle,
            autoRefreshOnLaunch: false
        )

        await model.refresh()
        #expect(model.viewState == .accessDenied)

        service.setAccessState(.granted)
        lifecycle.fireActive()
        await Task.yield()

        #expect(model.viewState == .ready(listName: "工作", count: 3))
    }

    @MainActor
    @Test func launchDefersInitialPermissionPromptUntilLifecycleStarts() async throws {
        let service = MutableReminderService(
            accessState: .granted,
            lists: [ReminderList(id: "work", title: "工作")],
            counts: ["work": 4]
        )
        let lifecycle = TestApplicationLifecycleObserver()
        let model = TodoBarAppModel(
            reminderService: service,
            bindingManager: InMemoryListBindingManager(selectedListID: "work"),
            appCommands: MockAppCommands(),
            changeObserver: NoopReminderChangeObserver(),
            lifecycleObserver: lifecycle,
            autoRefreshOnLaunch: true
        )

        #expect(model.viewState == .loading)
        lifecycle.fireLaunch()
        await Task.yield()

        #expect(model.viewState == .ready(listName: "工作", count: 4))
        #expect(service.requestedPromptIfNeededValues == [true])
    }

    @MainActor
    @Test func togglingLaunchAtLoginUpdatesState() async throws {
        let launchAtLogin = MockLaunchAtLoginManager(isEnabled: false)
        let model = TodoBarAppModel(
            reminderService: MockReminderService(accessState: .granted, lists: []),
            launchAtLoginManager: launchAtLogin,
            bindingManager: InMemoryListBindingManager(),
            appCommands: MockAppCommands(),
            changeObserver: NoopReminderChangeObserver(),
            lifecycleObserver: NoopApplicationLifecycleObserver(),
            autoRefreshOnLaunch: false
        )

        #expect(model.launchAtLoginEnabled == false)

        model.setLaunchAtLogin(true)

        #expect(model.launchAtLoginEnabled == true)
        #expect(launchAtLogin.setValues == [true])
    }
}

@MainActor
private struct MockReminderService: ReminderServiceProtocol {
    var accessState: ReminderAccessState
    var lists: [ReminderList]
    var remindersByListID: [String: [ReminderItem]] = [:]

    func ensureAccess(promptIfNeeded: Bool) async throws -> ReminderAccessState {
        accessState
    }

    func fetchLists() async throws -> [ReminderList] {
        lists
    }

    func fetchList(forID listID: String) async throws -> ReminderList? {
        lists.first(where: { $0.id == listID }) ?? remindersByListID[listID].map { _ in
            ReminderList(id: listID, title: listID == "work" ? "工作" : listID)
        }
    }

    func fetchIncompleteReminders(forListID listID: String) async throws -> [ReminderItem] {
        remindersByListID[listID, default: []]
    }

    func completeReminder(withID reminderID: String) async throws {}

    func authorizationSnapshot() -> ReminderAuthorizationSnapshot {
        ReminderAuthorizationSnapshot(status: accessState == .granted ? .fullAccess : .denied)
    }
}

@MainActor
private final class MockLaunchAtLoginManager: LaunchAtLoginManaging {
    private(set) var isEnabled: Bool
    private(set) var setValues: [Bool] = []

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    func setEnabled(_ isEnabled: Bool) throws {
        setValues.append(isEnabled)
        self.isEnabled = isEnabled
    }
}

@MainActor
private final class InMemoryListBindingManager: ListBindingManaging {
    var selectedListID: String?

    init(selectedListID: String? = nil) {
        self.selectedListID = selectedListID
    }
}

@MainActor
private struct MockAppCommands: AppCommandsHandling {
    func openRemindersApp() {}
    func openRemindersSettings() {}
    func quit() {}
}

@MainActor
private final class NoopReminderChangeObserver: ReminderChangeObserving {
    func start(_ onChange: @escaping @MainActor () -> Void) {}
}

@MainActor
private final class TestReminderChangeObserver: ReminderChangeObserving {
    private var onChange: (@MainActor () -> Void)?

    func start(_ onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
    }

    func fire() {
        onChange?()
    }
}

@MainActor
private final class NoopApplicationLifecycleObserver: ApplicationLifecycleObserving {
    func start(
        onLaunch: @escaping @MainActor () -> Void,
        onActive: @escaping @MainActor () -> Void
    ) {}
}

@MainActor
private final class TestApplicationLifecycleObserver: ApplicationLifecycleObserving {
    private var onLaunch: (@MainActor () -> Void)?
    private var onActive: (@MainActor () -> Void)?

    func start(
        onLaunch: @escaping @MainActor () -> Void,
        onActive: @escaping @MainActor () -> Void
    ) {
        self.onLaunch = onLaunch
        self.onActive = onActive
    }

    func fireLaunch() {
        onLaunch?()
    }

    func fireActive() {
        onActive?()
    }
}

@MainActor
private final class MutableReminderService: ReminderServiceProtocol {
    private var accessState: ReminderAccessState
    private var lists: [ReminderList]
    private var remindersByListID: [String: [ReminderItem]]
    private(set) var requestedPromptIfNeededValues: [Bool] = []
    private(set) var completedReminderIDs: [String] = []

    init(accessState: ReminderAccessState, lists: [ReminderList], counts: [String: Int]) {
        self.accessState = accessState
        self.lists = lists
        self.remindersByListID = counts.mapValues { count in
            (0..<count).map { index in
                ReminderItem(id: "item-\(index)", title: "待办\(index)", notes: nil)
            }
        }
    }

    func setAccessState(_ accessState: ReminderAccessState) {
        self.accessState = accessState
    }

    func ensureAccess(promptIfNeeded: Bool) async throws -> ReminderAccessState {
        requestedPromptIfNeededValues.append(promptIfNeeded)
        return accessState
    }

    func fetchLists() async throws -> [ReminderList] {
        lists
    }

    func fetchList(forID listID: String) async throws -> ReminderList? {
        lists.first(where: { $0.id == listID })
    }

    func fetchIncompleteReminders(forListID listID: String) async throws -> [ReminderItem] {
        remindersByListID[listID, default: []]
    }

    func completeReminder(withID reminderID: String) async throws {
        completedReminderIDs.append(reminderID)
        for listID in remindersByListID.keys {
            remindersByListID[listID]?.removeAll(where: { $0.id == reminderID })
        }
    }

    func authorizationSnapshot() -> ReminderAuthorizationSnapshot {
        ReminderAuthorizationSnapshot(status: accessState == .granted ? .fullAccess : .denied)
    }
}

@MainActor
private final class ControlledReminderService: ReminderServiceProtocol {
    private var reminders = (0..<5).map { index in
        ReminderItem(id: "item-\(index)", title: "待办\(index)", notes: nil)
    }
    private var firstCountContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var didSignalFirstCount = false

    func setCount(_ count: Int) {
        reminders = (0..<count).map { index in
            ReminderItem(id: "item-\(index)", title: "待办\(index)", notes: nil)
        }
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func awaitFirstCountRequest() async {
        if didSignalFirstCount {
            return
        }

        await withCheckedContinuation { continuation in
            firstCountContinuation = continuation
        }
    }

    func ensureAccess(promptIfNeeded: Bool) async throws -> ReminderAccessState {
        .granted
    }

    func fetchLists() async throws -> [ReminderList] {
        [ReminderList(id: "work", title: "工作")]
    }

    func fetchList(forID listID: String) async throws -> ReminderList? {
        listID == "work" ? ReminderList(id: "work", title: "工作") : nil
    }

    func fetchIncompleteReminders(forListID listID: String) async throws -> [ReminderItem] {
        if !didSignalFirstCount {
            didSignalFirstCount = true
            firstCountContinuation?.resume()
            firstCountContinuation = nil

            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
            }
        }

        return reminders
    }

    func completeReminder(withID reminderID: String) async throws {
        reminders.removeAll(where: { $0.id == reminderID })
    }

    func authorizationSnapshot() -> ReminderAuthorizationSnapshot {
        .init(status: .fullAccess)
    }
}
