//
//  LaunchAtLoginService.swift
//  todo-bar
//
//  Created by Codex on 2026/3/10.
//

import Foundation
import ServiceManagement

@MainActor
protocol LaunchAtLoginManaging: Sendable {
    var isEnabled: Bool { get }
    func setEnabled(_ isEnabled: Bool) throws
}

@MainActor
struct LaunchAtLoginService: LaunchAtLoginManaging {
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            SMAppService.mainApp.status == .enabled
        } else {
            false
        }
    }

    func setEnabled(_ isEnabled: Bool) throws {
        guard #available(macOS 13.0, *) else {
            return
        }

        if isEnabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
