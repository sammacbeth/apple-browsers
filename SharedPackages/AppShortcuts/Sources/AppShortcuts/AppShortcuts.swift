// The Swift Programming Language
// https://docs.swift.org/swift-book

import AppIntents

@available(macOS 13, *)
struct DuckDuckGoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: MyAppIntent(),
                    phrases: [
                        "Starts a \(.applicationName)"
                    ])
    }



}

@available(macOS 13, *)
struct MyAppIntent: AppIntent {
    
    static let title: LocalizedStringResource = "My App Intent"

    func perform() async throws -> some IntentResult & ProvidesDialog {
//        await MeditationService.startDefaultSession()
        return .result(dialog: "Okay, something....")
    }

    static let openAppWhenRun: Bool = true
}

struct BangEntity: AppEntity, Identifiable {
    var id: UUID

    var displayRepresentation: DisplayRepresentation { "\(title)" }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Bang"

    static var defaultQuery = BookQuery()
}
