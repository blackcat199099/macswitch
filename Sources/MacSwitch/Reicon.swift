import AppKit
import SwiftUI

/// Reicon SVGs are bundled locally; the app works without a network connection.
enum Reicon {
    @MainActor private static var cache: [String: NSImage] = [:]

    @MainActor static func image(_ name: String, filled: Bool = false) -> NSImage {
        let file = "\(name)-\(filled ? "filled" : "outline")"
        if let image = cache[file] { return image }
        if let url = Bundle.main.resourceURL?.appendingPathComponent("Icons").appendingPathComponent(file + ".svg"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            cache[file] = image
            return image
        }
        #if SWIFT_PACKAGE
        if let url = Bundle.module.resourceURL?.appendingPathComponent("Resources/Icons").appendingPathComponent(file + ".svg"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            cache[file] = image
            return image
        }
        #endif
        assertionFailure("Missing bundled Reicon asset: \(file)")
        return NSImage(systemSymbolName: "questionmark.square", accessibilityDescription: nil)!
    }
}

struct ReiconView: View {
    let name: String
    var filled = false
    var size: CGFloat = 25

    var body: some View {
        Image(nsImage: Reicon.image(name, filled: filled))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
