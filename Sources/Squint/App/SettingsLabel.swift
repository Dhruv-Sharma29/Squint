import SwiftUI

/// A settings row label: icon, title and an optional one-line explanation.
struct SettingsLabel: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey?
    let systemName: String
    let color: Color

    var body: some View {
        HStack {
            SettingsIcon(systemName: systemName, color: color)
            VStack(alignment: .leading) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
