import SwiftUI

/// Menu bar only; launched from main.swift when there are no command-line arguments.
struct SquintApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: appDelegate.model)
        } label: {
            if let symbol = appDelegate.model.statusSymbol {
                Image(systemName: symbol)
                    .accessibilityLabel("Squint")
            } else {
                Image(nsImage: MenuBarIcon.image)
            }
        }

        Settings {
            SettingsView(model: appDelegate.model)
        }
        .windowResizability(.contentSize) // the window fits its content instead of stretching wide
    }
}
