//
//  TodoBarViewState.swift
//  todo-bar
//
//  Created by Codex on 2026/3/10.
//

import Foundation

enum TodoBarViewState: Equatable {
    case loading
    case ready(listName: String, count: Int)
    case noSelection
    case accessDenied
    case missingList
    case error(String)

    var menuBarTitle: String {
        switch self {
        case .loading:
            return "..."
        case let .ready(listName, count):
            return "\(listName) \(count)"
        case .noSelection, .missingList:
            return "--"
        case .accessDenied:
            return "🚫"
        case .error:
            return "!"
        }
    }

    var menuBarBadgeText: String {
        switch self {
        case .loading:
            return "…"
        case let .ready(_, count):
            return count > 99 ? "99" : "\(count)"
        case .noSelection, .missingList:
            return "–"
        case .accessDenied, .error:
            return "!"
        }
    }

    var primaryLabel: String {
        switch self {
        case .loading, .ready, .noSelection, .missingList:
            return "当前监控"
        case .accessDenied:
            return "权限状态"
        case .error:
            return "状态"
        }
    }

    var primaryValue: String {
        switch self {
        case .loading:
            return "加载中"
        case let .ready(listName, _):
            return listName
        case .noSelection:
            return "尚未选择"
        case .accessDenied:
            return "未授权"
        case .missingList:
            return "列表不存在"
        case .error:
            return "读取失败"
        }
    }

    var secondaryLabel: String? {
        switch self {
        case .loading, .ready:
            return "未完成"
        case .noSelection, .accessDenied, .missingList, .error:
            return nil
        }
    }

    var secondaryValue: String? {
        switch self {
        case .loading:
            return "..."
        case let .ready(_, count):
            return "\(count)"
        case .noSelection, .accessDenied, .missingList, .error:
            return nil
        }
    }

    var message: String? {
        switch self {
        case .loading, .ready:
            return nil
        case .noSelection:
            return "请选择要监控的提醒事项列表"
        case .accessDenied:
            return "请允许 TodoBar 访问提醒事项"
        case .missingList:
            return "绑定的列表已删除，请重新选择"
        case let .error(message):
            return message
        }
    }
}
