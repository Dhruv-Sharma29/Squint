import AppIntents

struct CapturePlainTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture Plain Text"
    static var description: IntentDescription {
        IntentDescription("Select prose on the screen and copy it, with autocorrect and automatic language detection.")
    }

    @Dependency private var model: CaptureModel

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: await model.capture(code: false) ?? "")
    }
}
