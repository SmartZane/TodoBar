//
//  ReminderService.swift
//  todo-bar
//
//  Created by Codex on 2026/3/10.
//

import EventKit
import Foundation
import AppKit

enum ReminderAccessState: Equatable {
    case granted
    case denied
}

struct ReminderAuthorizationSnapshot: Equatable, Sendable {
    let status: EKAuthorizationStatus

    var label: String {
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorized:
            return "authorized"
        case .fullAccess:
            return "fullAccess"
        case .writeOnly:
            return "writeOnly"
        @unknown default:
            return "unknown"
        }
    }
}

struct ReminderItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let notes: String?
}

@MainActor
protocol ReminderServiceProtocol: Sendable {
    func ensureAccess(promptIfNeeded: Bool) async throws -> ReminderAccessState
    func fetchLists() async throws -> [ReminderList]
    func fetchList(forID listID: String) async throws -> ReminderList?
    func fetchIncompleteReminders(forListID listID: String) async throws -> [ReminderItem]
    func completeReminder(withID reminderID: String) async throws
    func authorizationSnapshot() -> ReminderAuthorizationSnapshot
}

@MainActor
final class ReminderService: ReminderServiceProtocol {
    private let eventStore = EKEventStore()

    func ensureAccess(promptIfNeeded: Bool) async throws -> ReminderAccessState {
        let status = authorizationStatus()
        switch status {
        case .fullAccess, .authorized:
            return .granted
        case .notDetermined:
            guard promptIfNeeded else {
                return .denied
            }

            let granted = try await requestFullAccess()
            return granted ? .granted : .denied
        case .denied, .restricted, .writeOnly:
            return .denied
        @unknown default:
            return .denied
        }
    }

    func fetchLists() async throws -> [ReminderList] {
        eventStore.calendars(for: .reminder).map {
            ReminderList(id: $0.calendarIdentifier, title: $0.title)
        }
    }

    func fetchList(forID listID: String) async throws -> ReminderList? {
        guard let calendar = eventStore.calendar(withIdentifier: listID) else {
            return nil
        }

        return ReminderList(id: calendar.calendarIdentifier, title: calendar.title)
    }

    func fetchIncompleteReminders(forListID listID: String) async throws -> [ReminderItem] {
        guard let calendar = eventStore.calendars(for: .reminder).first(where: { $0.calendarIdentifier == listID }) else {
            return []
        }

        let reminders = try await fetchReminders(in: [calendar])
        return reminders.map {
            ReminderItem(
                id: $0.calendarItemIdentifier,
                title: normalizedTitle(for: $0),
                notes: normalizedNotes(for: $0)
            )
        }
    }

    func completeReminder(withID reminderID: String) async throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: reminderID) as? EKReminder else {
            return
        }

        reminder.isCompleted = true
        reminder.completionDate = Date()
        try eventStore.save(reminder, commit: true)
    }

    private func fetchReminders(in calendars: [EKCalendar]) async throws -> [EKReminder] {
        let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: calendars)

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    func authorizationSnapshot() -> ReminderAuthorizationSnapshot {
        ReminderAuthorizationSnapshot(status: authorizationStatus())
    }

    private func normalizedTitle(for reminder: EKReminder) -> String {
        let title = reminder.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "未命名待办" : title
    }

    private func normalizedNotes(for reminder: EKReminder) -> String? {
        let notes = reminder.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return notes.isEmpty ? nil : notes
    }

    private func requestFullAccess() async throws -> Bool {
        NSApp.activate(ignoringOtherApps: true)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            if #available(macOS 14.0, *) {
                eventStore.requestFullAccessToReminders { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    continuation.resume(returning: granted)
                }
            } else {
                eventStore.requestAccess(to: .reminder) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func authorizationStatus() -> EKAuthorizationStatus {
        if #available(macOS 14.0, *) {
            EKEventStore.authorizationStatus(for: .reminder)
        } else {
            EKEventStore.authorizationStatus(for: .reminder)
        }
    }
}
