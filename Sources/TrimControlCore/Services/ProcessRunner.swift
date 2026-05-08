import Foundation

public struct ProcessResult: Hashable, Sendable {
    public let terminationStatus: Int32
    public let standardOutput: String
    public let standardError: String

    public var succeeded: Bool {
        terminationStatus == 0
    }
}

public enum ProcessRunner {
    @discardableResult
    public static func run(
        executable: String,
        arguments: [String],
        waitUntilExit: Bool = true
    ) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe: Pipe?
        let errorPipe: Pipe?
        if waitUntilExit {
            outputPipe = Pipe()
            errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
        } else {
            outputPipe = nil
            errorPipe = nil
            if let nullDevice = FileHandle(forWritingAtPath: "/dev/null") {
                process.standardOutput = nullDevice
                process.standardError = nullDevice
            }
        }

        try process.run()

        guard waitUntilExit else {
            return ProcessResult(terminationStatus: 0, standardOutput: "", standardError: "")
        }

        process.waitUntilExit()

        let output = String(
            data: outputPipe?.fileHandleForReading.readDataToEndOfFile() ?? Data(),
            encoding: .utf8
        ) ?? ""
        let error = String(
            data: errorPipe?.fileHandleForReading.readDataToEndOfFile() ?? Data(),
            encoding: .utf8
        ) ?? ""

        return ProcessResult(
            terminationStatus: process.terminationStatus,
            standardOutput: output.trimmingCharacters(in: .whitespacesAndNewlines),
            standardError: error.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
