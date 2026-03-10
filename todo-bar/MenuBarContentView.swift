//
//  MenuBarContentView.swift
//  todo-bar
//
//  Created by Codex on 2026/3/10.
//

import SwiftUI

struct MenuBarContentView: View {
    let appModel: TodoBarAppModel

    var body: some View {
        Group {
            if let message = appModel.viewState.message {
                Text(message)
            }

            if permissionNeedsAttention {
                Divider()

                Text("权限")

                Button(permissionActionTitle) {
                    if appModel.authorizationStatusLabel == "denied" {
                        appModel.openRemindersSettings()
                    } else {
                        Task {
                            await appModel.requestPermission()
                        }
                    }
                }
                .disabled(appModel.isRefreshing)

                Text(appModel.authorizationStatusLabel)
            }

            Divider()

            Menu(monitorListActionTitle) {
                if appModel.availableLists.isEmpty {
                    Text("暂无可用列表")
                } else {
                    ForEach(appModel.availableLists) { list in
                        Button(list.title) {
                            Task {
                                await appModel.selectList(list.id)
                            }
                        }
                    }

                    Divider()

                    Button("清除绑定") {
                        Task {
                            await appModel.clearSelection()
                        }
                    }
                }
            }
            .disabled(appModel.availableLists.isEmpty)

            Toggle(
                "开机启动",
                isOn: Binding(
                    get: { appModel.launchAtLoginEnabled },
                    set: { appModel.setLaunchAtLogin($0) }
                )
            )

            Button("打开提醒事项") {
                appModel.openRemindersApp()
            }

            if shouldShowReminderSection {
                Divider()

                if appModel.visibleReminders.isEmpty {
                    Text("已全部完成")
                } else {
                    ForEach(appModel.visibleReminders) { reminder in
                        Button {
                            Task {
                                await appModel.completeReminder(reminder.id)
                            }
                        } label: {
                            Label(reminder.title, systemImage: "circle")
                        }
                    }
                }
            }

            Divider()

            Button("退出") {
                appModel.quit()
            }
        }
        .task {
            await appModel.loadAvailableListsIfNeeded()
        }
    }

    private var permissionNeedsAttention: Bool {
        !["authorized", "fullAccess"].contains(appModel.authorizationStatusLabel)
    }

    private var permissionActionTitle: String {
        appModel.authorizationStatusLabel == "denied" ? "打开系统设置" : "请求提醒事项权限"
    }

    private var shouldShowReminderSection: Bool {
        switch appModel.viewState {
        case .ready:
            return true
        case .loading, .noSelection, .accessDenied, .missingList, .error:
            return false
        }
    }

    private var monitorListActionTitle: String {
        switch appModel.viewState {
        case let .ready(listName, _):
            return listName
        case .loading:
            return "切换监控列表"
        case .noSelection:
            return "选择监控列表"
        case .accessDenied, .missingList, .error:
            return "切换监控列表"
        }
    }
}
