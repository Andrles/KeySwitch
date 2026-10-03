import AppKit

// A quiet native mark: two language keys and a system switching symbol.
// No photographic asset is required for this geometric app identity.
guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: IconGenerator <legacy-artwork-path> <output>")
}
let output = CommandLine.arguments[2]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor.clear.setFill()
NSRect(origin: .zero, size: size).fill()
let accent = NSColor(calibratedRed: 0.19, green: 0.36, blue: 0.70, alpha: 1)
let base = NSRect(x: 32, y: 32, width: 960, height: 960)
NSColor(calibratedWhite: 0.95, alpha: 1).setFill()
NSBezierPath(roundedRect: base, xRadius: 214, yRadius: 214).fill()
for (letter, rect) in [("A", NSRect(x: 150, y: 420, width: 332, height: 376)),
                       ("Я", NSRect(x: 542, y: 420, width: 332, height: 376))] {
    accent.setFill()
    NSBezierPath(roundedRect: rect, xRadius: 70, yRadius: 70).fill()
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 232, weight: .medium),
        .foregroundColor: NSColor(calibratedWhite: 0.99, alpha: 1)
    ]
    let textSize = letter.size(withAttributes: attributes)
    letter.draw(at: NSPoint(x: rect.midX - textSize.width / 2,
                           y: rect.midY - textSize.height / 2), withAttributes: attributes)
}
if let arrows = NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: nil)?
    .withSymbolConfiguration(.init(pointSize: 180, weight: .medium)) {
    let rect = NSRect(x: 356, y: 164, width: 312, height: 180)
    arrows.withSymbolConfiguration(.init(paletteColors: [accent]))?.draw(in: rect)
}
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to render icon")
}
try png.write(to: URL(fileURLWithPath: output))
