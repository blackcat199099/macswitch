import Foundation

public enum SleepMode: Int, CaseIterable, Sendable {
    case allowed = 0
    case prevented = 1

    public var title: String { self == .allowed ? "잠자기 허용" : "깨어 있기" }
    public var command: String { "/usr/bin/pmset disablesleep \(rawValue)" }

    /// Read the system-wide flag, not unrelated per-power-source sleep timers.
    /// An absent or malformed value is unknown; it must never look like success.
    public static func parse(_ output: String) -> SleepMode? {
        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: \.isWhitespace)
            if fields.first == "SleepDisabled", fields.count == 2,
               let value = Int(fields[1]) {
                return SleepMode(rawValue: value)
            }
        }
        return nil
    }

    public var authorizationScript: String {
        // The complete command is selected from this enum; no user input enters a shell.
        "do shell script \"\(command)\" with administrator privileges with prompt \"MacSwitch에서 잠자기 설정을 변경합니다.\""
    }
}

public struct KeyModifiers: OptionSet, Sendable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }
    // The public CGEventFlags bit positions.
    public static let control = KeyModifiers(rawValue: 1 << 18)
    public static let option = KeyModifiers(rawValue: 1 << 19)
    public static let command = KeyModifiers(rawValue: 1 << 20)
}

public enum KeyboardDecision: Equatable, Sendable {
    case pass, block, unlock
}

public enum KeyboardPolicy {
    public static let escapeKeyCode: Int64 = 53
    public static let emergencyModifiers: KeyModifiers = [.control, .option, .command]

    public static func decide(isLocked: Bool, eventType: UInt32,
                              keyCode: Int64, modifiers: KeyModifiers) -> KeyboardDecision {
        guard isLocked else { return .pass }
        // keyDown, keyUp, flagsChanged and systemDefined (media keys).
        guard [10, 11, 12, 14].contains(eventType) else { return .pass }
        if eventType == 10, keyCode == escapeKeyCode,
           modifiers.isSuperset(of: emergencyModifiers) { return .unlock }
        return .block
    }
}

/// A recovery route that does not depend on modifier events reaching the session.
/// Key repeat cannot turn one held Escape into an unlock gesture.
public struct EmergencyUnlockGesture: Sendable {
    private var firstPress: TimeInterval?
    private var count = 0
    public init() {}

    public mutating func press(keyCode: Int64, isRepeat: Bool, at time: TimeInterval) -> Bool {
        guard keyCode == KeyboardPolicy.escapeKeyCode else {
            firstPress = nil
            count = 0
            return false
        }
        guard !isRepeat else { return false }
        if let firstPress, time >= firstPress, time - firstPress <= 1.5 {
            count += 1
        } else {
            firstPress = time
            count = 1
        }
        if count == 3 {
            firstPress = nil
            count = 0
            return true
        }
        return false
    }
}
