import AppKit
import Observation
import MacSwitchCore

@MainActor @Observable
final class AppModel {
    var sleepMode: SleepMode?
    var isKeyboardLocked = false
    var hasPermission = false
    var isChangingSleep = false
    var notice: String?
    var noticeIsError = false
    var needsPermission = false

    @ObservationIgnored let keyboard = KeyboardLock()
    @ObservationIgnored var onStatusChange: (() -> Void)?
    @ObservationIgnored private var isReading = false
    @ObservationIgnored let isPreview: Bool

    init(preview: Bool = false) {
        isPreview = preview
        hasPermission = preview || keyboard.isTrusted
        keyboard.onUnlock = { [weak self] message in
            self?.isKeyboardLocked = false
            self?.showNotice(message, isError: false)
            self?.onStatusChange?()
        }
    }

    var summary: String {
        let sleep = sleepMode?.title ?? "잠자기 확인 중"
        return "\(sleep) · 키보드 \(isKeyboardLocked ? "잠김" : "사용 중")"
    }

    func refresh() {
        guard !isPreview else { return }
        hasPermission = keyboard.isTrusted
        if hasPermission { needsPermission = false }
        guard !isChangingSleep, !isReading else { return }
        isReading = true
        Task {
            defer { isReading = false }
            do {
                sleepMode = try await SleepService.read()
            } catch {
                sleepMode = nil
                showNotice(error.localizedDescription, isError: true)
            }
            onStatusChange?()
        }
    }

    func chooseSleep(_ mode: SleepMode) {
        guard !isChangingSleep, mode != sleepMode else { return }
        guard !isPreview else {
            sleepMode = mode
            onStatusChange?()
            return
        }
        // The administrator dialog needs keyboard input. Unlock before it appears.
        let didUnlock = isKeyboardLocked
        unlockKeyboard()
        showNotice(didUnlock ? PasswordMessages().keyboardUnlocked : nil, isError: false)
        isChangingSleep = true
        NSApp.activate(ignoringOtherApps: true)
        Task {
            defer {
                isChangingSleep = false
                onStatusChange?()
            }
            do {
                try await SleepService.set(mode)
                sleepMode = mode
                showNotice(didUnlock ? "잠자기 설정을 변경했습니다. 키보드는 해제된 상태입니다." : nil, isError: false)
            } catch {
                sleepMode = try? await SleepService.read()
                showNotice(error.localizedDescription, isError: true)
            }
        }
    }

    func lockKeyboard() {
        guard !isChangingSleep, !isKeyboardLocked else { return }
        guard !isPreview else {
            isKeyboardLocked = true
            onStatusChange?()
            return
        }
        hasPermission = keyboard.isTrusted
        do {
            try keyboard.lock()
            isKeyboardLocked = true
            needsPermission = false
            showNotice(nil, isError: false)
        } catch {
            isKeyboardLocked = false
            needsPermission = !hasPermission
            showNotice(error.localizedDescription, isError: true)
        }
        onStatusChange?()
    }

    func unlockKeyboard() {
        keyboard.unlock()
        isKeyboardLocked = false
        showNotice(nil, isError: false)
        onStatusChange?()
    }

    func openPermissionSettings() {
        guard !isPreview else { return }
        unlockKeyboard()
        keyboard.requestPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        needsPermission = true
        showNotice("MacSwitch를 허용한 뒤 돌아와 ‘잠그기’를 눌러 주세요.", isError: false)
    }

    func stop() { keyboard.unlock() }

    private func showNotice(_ text: String?, isError: Bool) {
        notice = text
        noticeIsError = isError
    }
}
