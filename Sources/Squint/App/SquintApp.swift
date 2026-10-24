import SwiftUI

/// Menu bar only; launched from main.swift when there are no command-line arguments.
struct SquintApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("Squint", systemImage: appDelegate.model.symbol) {
            MenuContent(model: appDelegate.model)
        }
    }
}
