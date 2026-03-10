# TodoBar

TodoBar is a macOS menu bar app for a single Apple Reminders list.

It lets you bind one reminders list, show the incomplete count in the menu bar, inspect incomplete items from the menu, mark items complete, and optionally launch at login.

## Features

- Menu bar badge showing the incomplete count for the bound list
- Bind and switch the monitored Reminders list
- Real-time sync for the current monitored list
- Show incomplete reminders directly in the menu
- Mark a reminder complete by clicking its circle
- Open the Reminders app
- Launch at login toggle

## Tech Stack

- Swift
- SwiftUI
- EventKit
- MenuBarExtra
- ServiceManagement

## Project Structure

- `/Users/shenzhen/AppleProjects/todo-bar/todo-bar/todo_barApp.swift`
  App entry and menu bar badge rendering
- `/Users/shenzhen/AppleProjects/todo-bar/todo-bar/TodoBarAppModel.swift`
  App state, refresh flow, completion actions, launch-at-login state
- `/Users/shenzhen/AppleProjects/todo-bar/todo-bar/ReminderService.swift`
  EventKit access, list lookup, incomplete reminders, complete reminder action
- `/Users/shenzhen/AppleProjects/todo-bar/todo-bar/MenuBarContentView.swift`
  Native menu content
- `/Users/shenzhen/AppleProjects/todo-bar/todo-bar/ListBindingManager.swift`
  Persist selected list ID in `UserDefaults`
- `/Users/shenzhen/AppleProjects/todo-bar/todo-bar/LaunchAtLoginService.swift`
  Login item integration through `SMAppService`

## Requirements

- macOS 13 or later recommended
- Reminders permission
- Signed app build for reliable launch-at-login behavior

## Permissions

TodoBar needs:

- Reminders access
- Calendars access

On macOS, Reminders data is accessed through EventKit, and Calendar-related sandbox entitlement is also required.

## Run

Open the project in Xcode:

```bash
open /Users/shenzhen/AppleProjects/todo-bar/todo-bar.xcodeproj
```

Or build from terminal:

```bash
xcodebuild -scheme todo-bar -project /Users/shenzhen/AppleProjects/todo-bar/todo-bar.xcodeproj -configuration Debug -sdk macosx build
```

## Tests

Run unit tests:

```bash
xcodebuild test -scheme todo-bar -project /Users/shenzhen/AppleProjects/todo-bar/todo-bar.xcodeproj -destination 'platform=macOS' -only-testing:todo-barTests
```

## Current Notes

- The app name is `TodoBar`
- The UI test target has been removed from the Xcode project
- The `todo-barUITests/` folder may still exist on disk as leftover source files, but it is no longer part of the build graph
- Opening Reminders currently launches the app, but does not deep-link to the selected list
