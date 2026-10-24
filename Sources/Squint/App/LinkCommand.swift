import Foundation

/// A `squint://` link: `squint://capture` or `squint://clipboard`, with an optional `?mode=code` or `?mode=plain`.
/// `code` is nil when the link doesn't choose a mode, so the Code Mode setting applies.
enum LinkCommand: Equatable {
    case capture(code: Bool?)
    case clipboard(code: Bool?)

    init?(_ url: URL) {
        guard url.scheme?.lowercased() == "squint" else { return nil }
        let mode = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "mode" }?.value?.lowercased()
        let code: Bool? = switch mode {
        case "code": true
        case "plain": false
        default: nil
        }
        switch url.host()?.lowercased() {
        case "capture": self = .capture(code: code)
        case "clipboard": self = .clipboard(code: code)
        default: return nil
        }
    }
}
