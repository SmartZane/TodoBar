//
//  ListBindingManager.swift
//  todo-bar
//
//  Created by Codex on 2026/3/10.
//

import Foundation

@MainActor
protocol ListBindingManaging {
    var selectedListID: String? { get set }
}

@MainActor
struct ListBindingManager: ListBindingManaging {
    private enum Keys {
        static let selectedListID = "reminderListID"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedListID: String? {
        get { defaults.string(forKey: Keys.selectedListID) }
        set { defaults.set(newValue, forKey: Keys.selectedListID) }
    }
}
