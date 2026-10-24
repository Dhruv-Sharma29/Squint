import SwiftUI

/// Menu bar only; launched from main.swift when there are no command-line arguments.
struct SquintApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        @Bindable var preferences = appDelegate.model.preferences
        MenuBarExtra(isInserted: $preferences.showMenuBarIcon) {
            MenuContent(model: appDelegate.model, showSettings: appDelegate.showSettings)
        } label: {
            if let symbol = appDelegate.model.statusSymbol {
                Image(systemName: symbol)
                    .accessibilityLabel("Squint")
            } else {
                Image(nsImage: MenuBarIcon.image)
            }
        }
    }
}
