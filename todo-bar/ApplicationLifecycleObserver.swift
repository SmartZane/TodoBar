//
//  ApplicationLifecycleObserver.swift
//  todo-bar
//
//  Created by Codex on 2026/3/10.
//

import AppKit
import Foundation

@MainActor
protocol ApplicationLifecycleObserving: AnyObject {
    func start(
        onLaunch: @escaping @MainActor () -> Void,
        onActive: @escaping @MainActor () -> Void
    )
}

@MainActor
final class ApplicationLifecycleObserver: ApplicationLifecycleObserving {
    private var launchToken: NSObjectProtocol?
    private var activeToken: NSObjectProtocol?

    deinit {
        if let launchToken {
            NotificationCenter.default.removeObserver(launchToken)
        }

        if let activeToken {
            NotificationCenter.default.removeObserver(activeToken)
        }
    }

    func start(
        onLaunch: @escaping @MainActor () -> Void,
        onActive: @escaping @MainActor () -> Void
    ) {
        if NSApp != nil, NSApp.isRunning {
            Task { @MainActor in
                onLaunch()
            }
        }

        launchToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                onLaunch()
            }
        }

        activeToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                onActive()
            }
        }
    }
}
