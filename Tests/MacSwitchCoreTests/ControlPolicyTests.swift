import Testing
@testable import MacSwitchCore

@Suite("System state and keyboard recovery")
struct ControlPolicyTests {
    @Test func readsRealPmsetOutput() {
        #expect(SleepMode.parse("System-wide power settings:\n SleepDisabled\t\t0\n") == .allowed)
        #expect(SleepMode.parse("System-wide power settings:\n SleepDisabled\t\t1\nCurrently in use:\n sleep 0\n") == .prevented)
    }

    @Test(arguments: ["", "sleep 0", "SleepDisabled", "SleepDisabled 2", "SleepDisabled false", "SleepDisabled 1 extra"])
    func malformedStateIsNeverShownAsEnabled(output: String) {
        #expect(SleepMode.parse(output) == nil)
    }

    @Test func commandsAreRestrictedToTheTwoRequestedSettings() {
        #expect(SleepMode.allowed.command == "/usr/bin/pmset disablesleep 0")
        #expect(SleepMode.prevented.command == "/usr/bin/pmset disablesleep 1")
        #expect(!SleepMode.allowed.authorizationScript.contains("sudo"))
    }

    @Test(arguments: [UInt32(10), 11, 12, 14])
    func keyboardAndMediaEventsAreBlocked(eventType: UInt32) {
        #expect(KeyboardPolicy.decide(isLocked: true, eventType: eventType,
                                      keyCode: 0, modifiers: []) == .block)
    }

    @Test(arguments: [UInt32(1), 2, 3, 5, 6, 22, 27])
    func mouseAndTrackpadRemainUsable(eventType: UInt32) {
        #expect(KeyboardPolicy.decide(isLocked: true, eventType: eventType,
                                      keyCode: 0, modifiers: []) == .pass)
    }

    @Test func emergencyUnlockRequiresAllThreeModifiersAndEscapeKeyDown() {
        let decide: (UInt32, Int64, KeyModifiers) -> KeyboardDecision = {
            KeyboardPolicy.decide(isLocked: true, eventType: $0, keyCode: $1, modifiers: $2)
        }
        #expect(decide(10, 53, [.control, .option, .command]) == .unlock)
        #expect(decide(10, 53, [.option, .command]) == .block)
        #expect(decide(10, 53, [.control, .command]) == .block)
        #expect(decide(10, 53, [.control, .option]) == .block)
        #expect(decide(11, 53, [.control, .option, .command]) == .block)
        #expect(decide(10, 0, [.control, .option, .command]) == .block)
        #expect(decide(10, 53, KeyModifiers(rawValue: (1 << 18) | (1 << 19) | (1 << 20) | (1 << 17))) == .unlock)
    }

    @Test func unlockedKeyboardIsNeverFiltered() {
        #expect(KeyboardPolicy.decide(isLocked: false, eventType: 10,
                                      keyCode: 0, modifiers: []) == .pass)
        #expect(KeyboardPolicy.decide(isLocked: false, eventType: 10,
                                      keyCode: 53, modifiers: [.control, .option, .command]) == .pass)
    }

    @Test func threeSeparateEscapesUnlockWithoutModifiers() {
        var recovery = EmergencyUnlockGesture()
        let results = [
            recovery.press(keyCode: 53, isRepeat: false, at: 10),
            recovery.press(keyCode: 53, isRepeat: false, at: 10.3),
            recovery.press(keyCode: 53, isRepeat: false, at: 10.6),
            recovery.press(keyCode: 53, isRepeat: false, at: 10.8)
        ]
        #expect(results == [false, false, true, false])
    }

    @Test func heldEscapeCannotUnlock() {
        var recovery = EmergencyUnlockGesture()
        let initial = recovery.press(keyCode: 53, isRepeat: false, at: 1)
        #expect(!initial)
        for time in [1.1, 1.2, 1.3, 1.4] {
            let repeated = recovery.press(keyCode: 53, isRepeat: true, at: time)
            #expect(!repeated)
        }
    }

    @Test func slowEscapesAndOtherKeysBreakTheRecoverySequence() {
        var recovery = EmergencyUnlockGesture()
        let results = [
            recovery.press(keyCode: 53, isRepeat: false, at: 1),
            recovery.press(keyCode: 53, isRepeat: false, at: 1.5),
            recovery.press(keyCode: 53, isRepeat: false, at: 3),
            recovery.press(keyCode: 0, isRepeat: false, at: 3.1),
            recovery.press(keyCode: 53, isRepeat: false, at: 3.2),
            recovery.press(keyCode: 53, isRepeat: false, at: 3.4),
            recovery.press(keyCode: 53, isRepeat: false, at: 3.6)
        ]
        #expect(results == [false, false, false, false, false, false, true])
    }
}
