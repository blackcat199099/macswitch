import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 3 else { fatalError("Usage: make-icon.swift icon-directory output.iconset") }
let icons = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func drawIcon(size: Int) -> Data {
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        let context = NSGraphicsContext.current!.cgContext
        context.saveGState()
        context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
        let bounds = NSRect(x: 32, y: 32, width: 960, height: 960)
        let tile = NSBezierPath(roundedRect: bounds, xRadius: 216, yRadius: 216)
        NSGradient(starting: NSColor(srgbRed: 0.35, green: 0.48, blue: 1, alpha: 1),
                   ending: NSColor(srgbRed: 0.18, green: 0.29, blue: 0.83, alpha: 1))!
            .draw(in: tile, angle: -65)

        func symbol(_ name: String, rect: NSRect, color: NSColor) {
            guard let svg = NSImage(contentsOf: icons.appendingPathComponent(name + ".svg")) else {
                fatalError("Missing icon: \(name)")
            }
            let tinted = NSImage(size: rect.size, flipped: false) { local in
                svg.draw(in: local)
                color.setFill()
                local.fill(using: .sourceAtop)
                return true
            }
            tinted.draw(in: rect)
        }
        symbol("laptop-outline", rect: NSRect(x: 188, y: 181, width: 648, height: 648), color: .white)
        let badge = NSBezierPath(ovalIn: NSRect(x: 643, y: 623, width: 230, height: 230))
        NSColor(srgbRed: 0.25, green: 0.38, blue: 0.92, alpha: 1).setFill()
        badge.fill()
        symbol("sun-filled", rect: NSRect(x: 659, y: 639, width: 198, height: 198),
               color: NSColor(srgbRed: 1, green: 0.84, blue: 0.44, alpha: 1))
        context.restoreGState()
        return true
    }
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("PNG render failed") }
    return data
}

for size in [16, 32, 128, 256, 512] {
    try drawIcon(size: size).write(to: output.appendingPathComponent("icon_\(size)x\(size).png"))
    try drawIcon(size: size * 2).write(to: output.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
