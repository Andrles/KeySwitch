import AppKit

// A single language key keeps a recognizable silhouette at small sizes.
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
let key = NSRect(x: 148, y: 148, width: 728, height: 728)
accent.setFill()
NSBezierPath(roundedRect: key, xRadius: 164, yRadius: 164).fill()
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 264, weight: .semibold),
    .foregroundColor: NSColor.white
]
for (letter, x) in [("A", CGFloat(332)), ("Я", CGFloat(692))] {
    let textSize = letter.size(withAttributes: attributes)
    letter.draw(at: NSPoint(x: x - textSize.width / 2, y: 490), withAttributes: attributes)
}
if let arrows = NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: nil)?
    .withSymbolConfiguration(.init(pointSize: 160, weight: .semibold)) {
    arrows.withSymbolConfiguration(.init(paletteColors: [.white]))?
        .draw(in: NSRect(x: 352, y: 272, width: 320, height: 160))
}
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to render icon")
}
try png.write(to: URL(fileURLWithPath: output))
