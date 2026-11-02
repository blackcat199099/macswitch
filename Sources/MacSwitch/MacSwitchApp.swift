import AppKit
import SwiftUI
import MacSwitchCore

@main
struct MacSwitchLauncher {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        if let index = CommandLine.arguments.firstIndex(of: "--render-preview"),
           CommandLine.arguments.indices.contains(index + 1) {
            PreviewRenderer.render(to: CommandLine.arguments[index + 1])
            return
        }
        // A second launch opens the existing instance instead of creating a second filter.
        if let identifier = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            existing.activate(options: [])
            return
        }

        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePanel)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("MacSwitch")
        }
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        let controller = NSHostingController(rootView: ControlPanel(model: model))
        controller.sizingOptions = [.preferredContentSize]
        popover.contentViewController = controller
        model.onStatusChange = { [weak self] in self?.updateStatusItem() }
        updateStatusItem()
        model.refresh()

        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.refresh() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep),
                                                          name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake),
                                                          name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep),
                                                          name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        // Show the four controls on the first launch; never prompt for permissions on launch.
        DispatchQueue.main.async { [weak self] in self?.showPanel() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return false
    }

    func applicationDidBecomeActive(_ notification: Notification) { model.refresh() }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Do not orphan a pending privileged operation while the UI disappears.
        if model.isChangingSleep { return .terminateCancel }
        model.stop()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        model.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func willSleep() { model.unlockKeyboard() }
    @objc private func didWake() { model.refresh() }

    @objc private func togglePanel() {
        if popover.isShown { popover.performClose(nil) } else { showPanel() }
    }

    private func showPanel() {
        guard let button = statusItem.button else { return }
        model.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        let icon = model.isKeyboardLocked ? "lock" : "laptop"
        let image = Reicon.image(icon, filled: model.isKeyboardLocked || model.sleepMode == .prevented).copy() as! NSImage
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        button.image = image
        button.toolTip = "MacSwitch — \(model.summary)"
        button.setAccessibilityValue(model.summary)
    }
}

@MainActor
enum PreviewRenderer {
    static func render(to path: String) {
        let model = AppModel(preview: true)
        model.sleepMode = CommandLine.arguments.contains("--awake") ? .prevented : .allowed
        model.isKeyboardLocked = CommandLine.arguments.contains("--locked")
        if CommandLine.arguments.contains("--permission") {
            model.hasPermission = false
            model.needsPermission = true
        }
        if CommandLine.arguments.contains("--dark") { NSApp.appearance = NSAppearance(named: .darkAqua) }
        let view = NSHostingView(rootView: ControlPanel(model: model))
        let size = view.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = view
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.25))
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
        do {
            try png.write(to: URL(fileURLWithPath: path))
            print("Rendered \(Int(size.width))×\(Int(size.height)) preview: \(path)")
        } catch {
            fputs("Preview failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}
