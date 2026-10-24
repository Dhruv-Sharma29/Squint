/// One output row: recognized text, ink Vision couldn't read, or empty space.
enum Slot: Equatable {
    case text(indent: Int, String)
    case ink(indent: Int)
    case blank

    var indent: Int? {
        switch self {
        case .text(let indent, _), .ink(let indent): indent
        case .blank: nil
        }
    }
}
