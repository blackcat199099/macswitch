import Foundation
import Testing
@testable import MacSwitchCore

@Suite("Simple password guidance")
struct PasswordMessagesTests {
    @Test(arguments: ["ko", "ko-KR", "ko_KR", "KO-KR"])
    func koreanLanguageVariantsUseKorean(language: String) {
        let messages = PasswordMessages(preferredLanguages: [language, "en"])
        #expect(messages.prompt == "Mac 로그인 암호를 입력해 주세요.")
    }

    @Test(arguments: [["en"], ["en-US", "ko"], ["fr-FR"], ["kok-IN"], []])
    func otherPrimaryLanguagesUseSimpleEnglish(languages: [String]) {
        let messages = PasswordMessages(preferredLanguages: languages)
        #expect(messages.prompt == "Enter your Mac login password.")
    }

    @Test func languageOnlyChangesThePrompt() {
        for mode in SleepMode.allCases {
            let korean = mode.authorizationScript(preferredLanguages: ["ko"])
            let english = mode.authorizationScript(preferredLanguages: ["en"])
            let command = "do shell script \"\(mode.command)\" with administrator privileges with prompt "
            #expect(korean.hasPrefix(command))
            #expect(english.hasPrefix(command))
            #expect(korean.contains("Mac 로그인 암호를 입력해 주세요."))
            #expect(english.contains("Enter your Mac login password."))
        }
    }

    @MainActor @Test func localizedScriptsCompileWithoutExecuting() {
        for mode in SleepMode.allCases {
            for language in ["ko", "en"] {
                var error: NSDictionary?
                let script = NSAppleScript(source: mode.authorizationScript(preferredLanguages: [language]))
                let compiled = script?.compileAndReturnError(&error) ?? false
                #expect(compiled, "The localized password prompt must compile without executing a command.")
            }
        }
    }
}
