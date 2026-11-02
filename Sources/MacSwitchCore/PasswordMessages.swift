import Foundation

/// Short copy for the system password prompt and its related app messages.
/// Only fixed translations enter the authorization script.
public struct PasswordMessages: Sendable {
    public let prompt: String
    public let keyboardUnlocked: String
    public let cancelled: String
    public let failed: String

    public init(preferredLanguages: [String] = Locale.preferredLanguages) {
        let primary = preferredLanguages.first ?? ""
        let language = primary.replacingOccurrences(of: "_", with: "-")
            .split(separator: "-").first?.lowercased()

        if language == "ko" {
            prompt = "Mac 로그인 암호를 입력해 주세요."
            keyboardUnlocked = "암호 입력을 위해 키보드를 해제했습니다."
            cancelled = "취소했습니다. 잠자기 설정은 바뀌지 않았습니다."
            failed = "Mac 로그인 암호를 확인하고 다시 시도해 주세요."
        } else {
            prompt = "Enter your Mac login password."
            keyboardUnlocked = "Keyboard unlocked for password entry."
            cancelled = "Canceled. Sleep settings are unchanged."
            failed = "Check your Mac login password and try again."
        }
    }
}
