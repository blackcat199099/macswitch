import AppKit
import ApplicationServices
import Carbon
import MacSwitchCore

/// A session event filter. Only keyboard events are included in the mask.
/// No typed characters are stored or transmitted.
@MainActor
final class KeyboardLock {
    private(set) var isLocked = false
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var watchdog: Timer?
    private var recovery = EmergencyUnlockGesture()
    var onUnlock: ((String?) -> Void)?

    var isTrusted: Bool { AXIsProcessTrusted() }
    var secureInputEnabled: Bool { IsSecureEventInputEnabled() }

    func lock() throws {
        guard !isLocked else { return }
        guard isTrusted else { throw LockError.permission }
        guard !secureInputEnabled else { throw LockError.secureInput }

        let eventMask = [10, 11, 12, 14].reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1) }
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            // This source is attached exclusively to the main run loop.
            return MainActor.assumeIsolated {
                let owner = Unmanaged<KeyboardLock>.fromOpaque(context).takeUnretainedValue()
                return owner.filter(type, event)
            }
        }

        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: eventMask, callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { throw LockError.unavailable }
        guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            CFMachPortInvalidate(newTap)
            throw LockError.unavailable
        }

        tap = newTap
        source = newSource
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        guard CGEvent.tapIsEnabled(tap: newTap) else {
            removeTap()
            throw LockError.unavailable
        }
        isLocked = true
        recovery = EmergencyUnlockGesture()
        watchdog = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkHealth() }
        }
        if let watchdog { RunLoop.main.add(watchdog, forMode: .common) }
    }

    func unlock(message: String? = nil) {
        let wasLocked = isLocked
        isLocked = false
        recovery = EmergencyUnlockGesture()
        watchdog?.invalidate()
        watchdog = nil
        removeTap()
        if wasLocked { onUnlock?(message) }
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func removeTap() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil
        tap = nil
    }

    private func filter(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Never show a green lock after macOS has disabled the filter.
            isLocked = false
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.unlock()
                self.onUnlock?("macOS가 입력 차단을 중지해 키보드를 해제했습니다.")
            }
            return Unmanaged.passUnretained(event)
        }
        // Other systemDefined subtypes include auxiliary mouse buttons.
        if type.rawValue == 14, NSEvent(cgEvent: event)?.subtype.rawValue != 8 {
            return Unmanaged.passUnretained(event)
        }
        if isLocked, type == .keyDown,
           recovery.press(keyCode: event.getIntegerValueField(.keyboardEventKeycode),
                          isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
                          at: ProcessInfo.processInfo.systemUptime) {
            finishEmergencyUnlock()
            return nil
        }
        let decision = KeyboardPolicy.decide(
            isLocked: isLocked, eventType: type.rawValue,
            keyCode: event.getIntegerValueField(.keyboardEventKeycode),
            modifiers: KeyModifiers(rawValue: event.flags.rawValue)
        )
        switch decision {
        case .pass: return Unmanaged.passUnretained(event)
        case .block: return nil
        case .unlock:
            finishEmergencyUnlock()
            return nil
        }
    }

    private func finishEmergencyUnlock() {
        isLocked = false
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.unlock()
            self.onUnlock?("비상 단축키로 키보드를 해제했습니다.")
        }
    }

    private func checkHealth() {
        guard isLocked else { return }
        if !isTrusted || secureInputEnabled || tap.map({ !CGEvent.tapIsEnabled(tap: $0) }) != false {
            unlock(message: "입력 차단을 유지할 수 없어 키보드를 해제했습니다.")
        }
    }

    enum LockError: LocalizedError {
        case permission, secureInput, unavailable
        var errorDescription: String? {
            switch self {
            case .permission: return "키보드 잠금에 접근성 권한이 필요합니다."
            case .secureInput: return "암호 입력 창을 닫은 뒤 다시 잠가 주세요."
            case .unavailable: return "입력을 차단하지 못했습니다. 접근성 권한을 확인한 뒤 앱을 다시 실행해 주세요."
            }
        }
    }
}
