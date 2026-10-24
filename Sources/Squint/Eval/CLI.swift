import Foundation

enum CLI {
    static let usage = """
        usage: squint                       start the menu bar app
               squint [--plain] <image>     print the text in an image
               squint eval <directory>      score each x.png against x.txt (and x.textsniper.txt if present)
        options: --language <code>          Plain Mode's language, such as hi-IN (default: detected)
                 --also <code>              with detection, also read in this language and keep the more confident
                                            reading (default: this Mac's first preferred language other than English)
        """

    static func run(_ arguments: [String]) async -> Int32 {
        func value(of option: String) -> String? {
            arguments.firstIndex(of: option).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        }
        let language = value(of: "--language")
        let alsoTry = value(of: "--also") ?? Recognizer.preferredAlternative
        let options: Set = ["--language", "--also"]
        let rest = arguments.enumerated().filter { index, argument in
            argument != "--plain" && !options.contains(argument) && !(index > 0 && options.contains(arguments[index - 1]))
        }.map(\.element)
        guard let first = rest.first, !["-h", "--help", "help"].contains(first) else {
            print(usage)
            return 0
        }
        do {
            if first == "eval" {
                try await evaluate(URL(filePath: rest.dropFirst().first ?? "."), language: language, alsoTry: alsoTry)
            } else {
                print(try await Recognizer.text(at: URL(filePath: first), code: !arguments.contains("--plain"), language: language, alsoTry: alsoTry))
            }
            return 0
        } catch {
            FileHandle.standardError.write(Data("squint: \(error.localizedDescription)\n".utf8))
            return 1
        }
    }

    private static func evaluate(_ directory: URL, language: String?, alsoTry: String?) async throws {
        let images = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { ["png", "jpg", "jpeg"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var totals: [String: (cer: Double, exact: Double, count: Int)] = [:]

        print("file\tsystem\tCER\tlines exact")
        for image in images {
            let stem = image.deletingPathExtension()
            guard let truth = try? read(stem.appendingPathExtension("txt")) else { continue }
            var outputs = [
                "plain": try await Recognizer.text(at: image, code: false, language: language, alsoTry: alsoTry),
                "squint": try await Recognizer.text(at: image, code: true),
            ]
            outputs["textsniper"] = try? read(stem.appendingPathExtension("textsniper.txt"))

            for (system, output) in outputs.sorted(by: { $0.key < $1.key }) {
                let cer = Metrics.cer(output, truth: truth), exact = Metrics.exactLines(output, truth: truth)
                print("\(image.lastPathComponent)\t\(system)\t\(format(cer, exact))")
                let total = totals[system, default: (0, 0, 0)]
                totals[system] = (total.cer + cer, total.exact + exact, total.count + 1)
            }
        }
        for (system, total) in totals.sorted(by: { $0.key < $1.key }) {
            let n = Double(total.count)
            print("MEAN (n=\(total.count))\t\(system)\t\(format(total.cer / n, total.exact / n))")
        }
    }

    private static func format(_ cer: Double, _ exact: Double) -> String {
        "\(cer.formatted(.number.precision(.fractionLength(3))))\t\(exact.formatted(.percent.precision(.fractionLength(0))))"
    }

    private static func read(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .newlines)
    }
}
