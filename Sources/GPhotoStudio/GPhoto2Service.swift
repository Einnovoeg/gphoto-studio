import Foundation

/// Errors surfaced to the UI when invoking `gphoto2` commands.
enum GPhoto2Error: LocalizedError {
    case executableNotFound
    case commandFailed(args: [String], exitCode: Int32, stderr: String)
    case timedOut(args: [String], seconds: Int)
    case invalidOutput(String)
    case emptyPreviewData

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "gphoto2 is not installed or not available in PATH."
        case let .commandFailed(args, exitCode, stderr):
            let command = (["gphoto2"] + args).joined(separator: " ")
            let details = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return "Command failed (\(exitCode)): \(command)\n\(details)"
        case let .timedOut(args, seconds):
            let command = (["gphoto2"] + args).joined(separator: " ")
            return "Command timed out after \(seconds)s: \(command)"
        case let .invalidOutput(message):
            return message
        case .emptyPreviewData:
            return "Camera returned an empty preview frame."
        }
    }
}

/// Captured process output from a `gphoto2` command execution.
struct CommandResult {
    let exitCode: Int32
    let stdoutData: Data
    let stderrData: Data

    var stdoutString: String {
        String(decoding: stdoutData, as: UTF8.self)
    }

    var stderrString: String {
        String(decoding: stderrData, as: UTF8.self)
    }
}

/// Actor wrapper around the `gphoto2` CLI to keep process execution serialized.
actor GPhoto2Service {
    private let fileManager = FileManager.default
    private let gphoto2ExecutablePath: String?
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return formatter
    }()

    init() {
        self.gphoto2ExecutablePath = Self.resolveGPhoto2ExecutablePath()
    }

    /// Verifies that `gphoto2` can be executed.
    func checkAvailability() async throws {
        _ = try await run(["--version"], timeout: 10)
    }

    /// Returns camera model + port pairs from `gphoto2 --auto-detect`.
    func autoDetect() async throws -> [CameraDevice] {
        let result = try await run(["--auto-detect"], timeout: 20)
        return Self.parseAutoDetectOutput(result.stdoutString)
    }

    /// Returns the available configuration keys for the active camera.
    func listConfigKeys(port: String?) async throws -> [String] {
        let result = try await run(withPort(["--list-config"], port: port), timeout: 45)
        return result.stdoutString
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.hasPrefix("/") }
    }

    /// Reads metadata for one specific camera setting key.
    func getConfig(key: String, port: String?) async throws -> CameraSetting {
        let result = try await run(withPort(["--get-config", key], port: port), timeout: 30)
        let lines = result.stdoutString.split(whereSeparator: \.isNewline).map(String.init)

        var label = key
        var current = ""
        var choices: [String] = []

        for line in lines {
            if line.hasPrefix("Label:") {
                label = line.replacingOccurrences(of: "Label:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Current:") {
                current = line.replacingOccurrences(of: "Current:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Choice:") {
                let payload = line.replacingOccurrences(of: "Choice:", with: "")
                    .trimmingCharacters(in: .whitespaces)

                if let index = payload.firstIndex(where: { $0.isWhitespace }) {
                    let choice = payload[index...].trimmingCharacters(in: .whitespaces)
                    if !choice.isEmpty {
                        choices.append(choice)
                    }
                } else if !payload.isEmpty {
                    choices.append(payload)
                }
            }
        }

        return CameraSetting(key: key, label: label, current: current, choices: choices)
    }

    /// Writes one camera setting value.
    func setConfig(key: String, value: String, port: String?) async throws {
        _ = try await run(withPort(["--set-config", "\(key)=\(value)"], port: port), timeout: 30)
    }

    /// Captures one full image and downloads it to the given destination folder.
    func captureImage(port: String?, destinationDirectory: URL) async throws -> URL {
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        let timestamp = dateFormatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let destination = destinationDirectory.appendingPathComponent("capture-\(timestamp).jpg")

        _ = try await run(
            withPort(
                [
                    "--capture-image-and-download",
                    "--force-overwrite",
                    "--filename",
                    destination.path
                ],
                port: port
            ),
            timeout: 90
        )

        return destination
    }

    /// Captures one preview frame and returns raw image bytes.
    func capturePreview(port: String?) async throws -> Data {
        let result = try await run(withPort(["--capture-preview", "--stdout"], port: port), timeout: 25)
        if result.stdoutData.isEmpty {
            throw GPhoto2Error.emptyPreviewData
        }
        return result.stdoutData
    }

    /// Waits for camera events and downloads any files produced by those events.
    func waitForEventAndDownload(
        port: String?,
        destinationDirectory: URL,
        waitSeconds: Int
    ) async throws -> [URL] {
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        let filenamePattern = destinationDirectory
            .appendingPathComponent("tether-%Y%m%d-%H%M%S-%n.%C")
            .path

        let result = try await run(
            withPort(
                [
                    "--wait-event-and-download=\(waitSeconds)s",
                    "--filename",
                    filenamePattern
                ],
                port: port
            ),
            timeout: TimeInterval(waitSeconds + 20)
        )

        let combinedOutput = result.stdoutString + "\n" + result.stderrString
        return Self.parseDownloadedPaths(from: combinedOutput)
    }

    /// Injects `--port` when a specific camera port is selected.
    private func withPort(_ args: [String], port: String?) -> [String] {
        guard let port, !port.isEmpty else {
            return args
        }
        return ["--port", port] + args
    }

    /// Runs `gphoto2` with timeout handling and collected stdout/stderr.
    /// Output is routed through temporary files to avoid deadlocks on large payloads.
    private func run(_ args: [String], timeout: TimeInterval) async throws -> CommandResult {
        let stdoutURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gphoto2-stdout-\(UUID().uuidString)")
        let stderrURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gphoto2-stderr-\(UUID().uuidString)")

        fileManager.createFile(atPath: stdoutURL.path, contents: nil)
        fileManager.createFile(atPath: stderrURL.path, contents: nil)

        defer {
            try? fileManager.removeItem(at: stdoutURL)
            try? fileManager.removeItem(at: stderrURL)
        }

        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)

        defer {
            try? stdoutHandle.close()
            try? stderrHandle.close()
        }

        let process = Process()
        if let executablePath = gphoto2ExecutablePath {
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = args
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["gphoto2"] + args
        }
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle

        do {
            try process.run()
        } catch {
            throw GPhoto2Error.executableNotFound
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if Date() >= deadline {
                process.terminate()
                process.waitUntilExit()
                throw GPhoto2Error.timedOut(args: args, seconds: Int(timeout))
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        let stdoutData = (try? Data(contentsOf: stdoutURL)) ?? Data()
        let stderrData = (try? Data(contentsOf: stderrURL)) ?? Data()
        let result = CommandResult(
            exitCode: process.terminationStatus,
            stdoutData: stdoutData,
            stderrData: stderrData
        )

        if result.exitCode != 0 {
            let combined = (result.stderrString + "\n" + result.stdoutString)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if result.exitCode == 127 || combined.contains("No such file or directory") {
                throw GPhoto2Error.executableNotFound
            }
            throw GPhoto2Error.commandFailed(args: args, exitCode: result.exitCode, stderr: combined)
        }

        return result
    }

    /// Parses stdout from `gphoto2 --auto-detect`.
    static func parseAutoDetectOutput(_ output: String) -> [CameraDevice] {
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)

        guard let separatorIndex = lines.firstIndex(where: { $0.contains("----") }) else {
            return []
        }

        var devices: [CameraDevice] = []
        for line in lines[(separatorIndex + 1)...] {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }

            guard let splitRange = trimmed.range(of: #"\s{2,}"#, options: .regularExpression) else {
                continue
            }

            let model = String(trimmed[..<splitRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let port = String(trimmed[splitRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            if !model.isEmpty, !port.isEmpty {
                devices.append(CameraDevice(model: model, port: port))
            }
        }

        return devices
    }

    /// Extracts unique local download paths from gphoto2 output lines such as:
    /// `Saving file as '/path/file.jpg'`.
    static func parseDownloadedPaths(from output: String) -> [URL] {
        var paths: [URL] = []
        var seen: Set<String> = []

        for line in output.split(whereSeparator: \.isNewline) {
            let text = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let range = text.range(of: "Saving file as ") else {
                continue
            }

            var path = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if path.hasPrefix("'"), path.hasSuffix("'"), path.count > 1 {
                path.removeFirst()
                path.removeLast()
            } else if path.hasPrefix("\""), path.hasSuffix("\""), path.count > 1 {
                path.removeFirst()
                path.removeLast()
            }

            if path.isEmpty || seen.contains(path) {
                continue
            }

            seen.insert(path)
            paths.append(URL(fileURLWithPath: path))
        }

        return paths
    }

    /// Tries PATH first, then common macOS package manager install locations.
    private static func resolveGPhoto2ExecutablePath() -> String? {
        let fileManager = FileManager.default
        let environmentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let searchPaths = environmentPath
            .split(separator: ":")
            .map(String.init) + [
                "/opt/homebrew/bin",
                "/usr/local/bin",
                "/opt/local/bin"
            ]

        for directory in searchPaths {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent("gphoto2").path
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }
}
