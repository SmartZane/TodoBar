//
//  todo_barApp.swift
//  todo-bar
//
//  Created by 申震 on 2026/3/10.
//

import AppKit
import SwiftUI

@main
struct TodoBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appModel: TodoBarAppModel

    init() {
        _appModel = State(initialValue: TodoBarAppModel())
    }

    var body: some Scene {
        menuBarScene
    }

    private var menuBarScene: some Scene {
        MenuBarExtra {
            MenuBarContentView(appModel: appModel)
        } label: {
            MenuBarBadgeView(viewState: appModel.viewState)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarBadgeView: View {
    let viewState: TodoBarViewState

    var body: some View {
        Image(nsImage: MenuBarBadgeImageRenderer.render(for: viewState))
            .accessibilityLabel(viewState.menuBarTitle)
    }
}

private enum MenuBarBadgeImageRenderer {
    static func render(for viewState: TodoBarViewState) -> NSImage {
        let size = NSSize(width: 20, height: 20)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        NSGraphicsContext.current?.imageInterpolation = .high

        let rect = NSRect(origin: .zero, size: size)
        let insetRect = rect.insetBy(dx: 1.75, dy: 1.75)
        let circlePath = NSBezierPath(ovalIn: insetRect)
        let badgeColor = badgeColor(for: viewState)
        circlePath.lineWidth = 1.6
        badgeColor.setStroke()
        circlePath.stroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font(for: viewState),
            .foregroundColor: badgeColor,
            .paragraphStyle: paragraph
        ]

        let text = NSAttributedString(string: viewState.menuBarBadgeText, attributes: attributes)
        let textBounds = text.boundingRect(
            with: NSSize(width: size.width, height: size.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let textRect = NSRect(
            x: (size.width - textBounds.width) / 2 - textBounds.origin.x,
            y: (size.height - textBounds.height) / 2 - textBounds.origin.y,
            width: textBounds.width,
            height: textBounds.height
        )
        text.draw(in: textRect)

        image.isTemplate = false
        return image
    }

    private static func badgeColor(for viewState: TodoBarViewState) -> NSColor {
        switch viewState {
        case let .ready(_, count):
            return count == 0 ? .secondaryLabelColor : .labelColor
        case .loading, .noSelection, .missingList:
            return .secondaryLabelColor
        case .accessDenied, .error:
            return .systemOrange
        }
    }

    private static func font(for viewState: TodoBarViewState) -> NSFont {
        let text = viewState.menuBarBadgeText
        let size: CGFloat = text.count > 1 ? 9.5 : 11
        return NSFont.monospacedDigitSystemFont(ofSize: size, weight: .bold)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
