import AppKit

guard CommandLine.arguments.count == 3,
      let artwork = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
    fatalError("Usage: IconGenerator <artwork> <output>")
}

let output = CommandLine.arguments[2]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
NSColor.clear.setFill()
rect.fill()
let iconRect = rect.insetBy(dx: 10, dy: 10)
NSBezierPath(roundedRect: iconRect, xRadius: 225, yRadius: 225).addClip()
NSGraphicsContext.current?.imageInterpolation = .high
artwork.draw(in: iconRect,
             from: NSRect(origin: .zero, size: artwork.size),
             operation: .sourceOver,
             fraction: 1)
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to render icon")
}
try png.write(to: URL(fileURLWithPath: output))
