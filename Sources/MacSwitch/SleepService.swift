import Foundation
import MacSwitchCore

struct CommandResult: Sendable {
    let status: Int32
    let output: String
}

enum SleepService {
    static func read() async throws -> SleepMode {
        let result = try await run("/usr/bin/pmset", ["-g"])
        guard result.status == 0, let mode = SleepMode.parse(result.output) else {
            throw ServiceError.unreadable
        }
        return mode
    }

    static func set(_ mode: SleepMode) async throws {
        let result = try await run("/usr/bin/osascript", ["-e", mode.authorizationScript])
        guard result.status == 0 else {
            if result.output.contains("(-128)") { throw ServiceError.cancelled }
            throw ServiceError.changeFailed
        }
        guard try await read() == mode else { throw ServiceError.notApplied }
    }

    /// Keep the main run loop responsive, including mouse unlock, during system dialogs.
    private static func run(_ executable: String, _ arguments: [String]) async throws -> CommandResult {
        try await Task.detached(priority: .utility) {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return CommandResult(status: process.terminationStatus,
                                 output: String(decoding: data, as: UTF8.self))
        }.value
    }

    enum ServiceError: LocalizedError {
        case unreadable, cancelled, changeFailed, notApplied

        var errorDescription: String? {
            switch self {
            case .unreadable: return "잠자기 상태를 읽지 못했습니다. 다시 확인해 주세요."
            case .cancelled: return "인증을 취소했습니다. 잠자기 설정은 바뀌지 않았습니다."
            case .changeFailed: return "잠자기 설정을 변경하지 못했습니다. 관리자 계정으로 인증해 주세요."
            case .notApplied: return "요청한 설정이 확인되지 않았습니다. 다시 시도해 주세요."
            }
        }
    }
}
