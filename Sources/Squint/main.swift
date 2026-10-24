import Foundation

// No arguments: menu bar app. With arguments: command-line OCR and evaluation (see CLI.swift).
let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.isEmpty {
    SquintApp.main()
} else {
    // A run loop on the main thread, as in an app: under dispatchMain() the main thread never runs one, and a long
    // `squint eval` hung once inside Vision, waiting on work that never ran.
    Task { exit(await CLI.run(arguments)) }
    CFRunLoopRun()
}
