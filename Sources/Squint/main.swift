import Foundation

// No arguments: menu bar app. With arguments: command-line OCR and evaluation (see CLI.swift).
let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.isEmpty {
    SquintApp.main()
} else {
    exit(CLI.run(arguments))
}
