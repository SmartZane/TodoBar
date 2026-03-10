//
//  SystemAppCommands.swift
//  todo-bar
//
//  Created by Codex on 2026/3/10.
//

import AppKit
import Foundation

@MainActor
protocol AppCommandsHandling {
    func openRemindersApp()
    func openRemindersSettings()
    func quit()
}

@MainActor
struct SystemAppCommands: AppCommandsHandling {
    func openRemindersApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.reminders") else {
            return
        }

        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    func openRemindersSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
