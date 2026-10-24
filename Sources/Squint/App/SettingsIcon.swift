import SwiftUI

/// A System Settings–style row icon: a white symbol on a coloured rounded square. Decorative, so VoiceOver skips it.
struct SettingsIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(color.gradient, in: .rect(cornerRadius: 6))
            .accessibilityHidden(true)
    }
}
