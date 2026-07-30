import AppKit

let output = CommandLine.arguments[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
let path = NSBezierPath(roundedRect: rect.insetBy(dx: 42, dy: 42), xRadius: 210, yRadius: 210)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.20, green: 0.38, blue: 0.98, alpha: 1),
    NSColor(calibratedRed: 0.50, green: 0.18, blue: 0.90, alpha: 1)
])!
gradient.draw(in: path, angle: -45)

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 150, weight: .bold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph
]
"KeySwitch".draw(in: NSRect(x: 55, y: 370, width: 914, height: 250), withAttributes: attrs)
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to render icon")
}
try png.write(to: URL(fileURLWithPath: output))
