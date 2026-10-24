import AppIntents

struct ReadClipboardImageIntent: AppIntent {
    static let title: LocalizedStringResource = "Read Clipboard Image"
    static var description: IntentDescription {
        IntentDescription("Copy the text in the image on the clipboard, or in an image file copied in Finder.")
    }

    @Dependency private var model: CaptureModel

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: await model.readClipboard() ?? "")
    }
}
