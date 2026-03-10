//
//  ReminderChangeObserver.swift
//  todo-bar
//
//  Created by Codex on 2026/3/10.
//

import EventKit
import Foundation

@MainActor
protocol ReminderChangeObserving: AnyObject {
    func start(_ onChange: @escaping @MainActor () -> Void)
}

@MainActor
final class ReminderChangeObserver: ReminderChangeObserving {
    private var token: NSObjectProtocol?

    deinit {
        if let token {
            NotificationCenter.default.removeObserver(token)
        }
    }

    func start(_ onChange: @escaping @MainActor () -> Void) {
        token = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                onChange()
            }
        }
    }
}
