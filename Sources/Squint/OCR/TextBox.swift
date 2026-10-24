import CoreGraphics

/// One run of recognized text and its bounds, in Vision's normalized coordinates (origin bottom-left).
struct TextBox {
    let text: String
    let rect: CGRect
}
