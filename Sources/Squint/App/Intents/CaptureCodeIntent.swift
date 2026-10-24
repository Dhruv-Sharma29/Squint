import AppIntents

struct CaptureCodeIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture Code"
    static var description: IntentDescription {
        IntentDescription("Select code on the screen and copy it with its indentation, blank lines and brackets intact.")
    }

    @Dependency private var model: CaptureModel

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: await model.capture(code: true) ?? "")
    }
}
