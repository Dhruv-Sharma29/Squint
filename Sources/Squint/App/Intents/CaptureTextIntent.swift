import AppIntents

struct CaptureTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture Text"
    static var description: IntentDescription {
        IntentDescription("Select an area of the screen and copy its text, using the Code Mode setting.")
    }

    @Dependency private var model: CaptureModel

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: await model.capture() ?? "")
    }
}
