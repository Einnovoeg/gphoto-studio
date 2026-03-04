import AppKit
import Foundation

/// Main UI state and orchestration layer for gPhoto Studio.
/// This type is intentionally `@MainActor` so all published mutations stay UI-safe.
@MainActor
final class AppViewModel: ObservableObject {
    // MARK: Published UI State

    /// Camera endpoints currently discovered from `gphoto2 --auto-detect`.
    @Published var cameras: [CameraDevice] = []
    /// Active camera ID selected in the sidebar.
    @Published var selectedCameraID: String = ""
    /// Settings currently shown in the settings list panel.
    @Published var settings: [CameraSetting] = []
    /// Recent capture/tether activity log.
    @Published var jobs: [CaptureJob] = []
    /// Global status line shown in the app footer.
    @Published var statusText: String = "Ready"
    /// Last decoded preview frame.
    @Published var livePreviewImage: NSImage?
    /// Whether live view polling is enabled.
    @Published var liveViewEnabled = false
    /// Generic spinner gate for long-running operations.
    @Published var isWorking = false

    /// User-chosen output folder.
    @Published var outputDirectory: String
    /// Fast manual preset fields.
    @Published var preset = CapturePreset()

    /// Timelapse interval field (seconds) as text to preserve user entry.
    @Published var timelapseIntervalSeconds = "3"
    /// Timelapse count field as text to preserve user entry.
    @Published var timelapseShotCount = "10"
    /// Timelapse run-state used by button toggles.
    @Published var timelapseRunning = false
    /// Tether wait timeout field as text.
    @Published var tetherIntervalSeconds = "2"
    /// Tether run-state used by button toggles.
    @Published var tetheringActive = false

    // MARK: Private Runtime State

    private let service: GPhoto2Service
    private var livePreviewTask: Task<Void, Never>?
    private var timelapseTask: Task<Void, Never>?
    private var tetherTask: Task<Void, Never>?

    /// Prefer known common keys first for faster load and better UX.
    private static let commonConfigKeys = [
        "/main/capturesettings/shutterspeed",
        "/main/capturesettings/aperture",
        "/main/imgsettings/iso",
        "/main/imgsettings/whitebalance",
        "/main/imgsettings/imageformat",
        "/main/settings/capturetarget"
    ]
    /// Prevent unbounded queue growth on long tether sessions.
    private static let maxJobHistory = 250

    init(service: GPhoto2Service = GPhoto2Service()) {
        self.service = service
        self.outputDirectory = "~/Pictures/gPhoto Studio"
    }

    deinit {
        // Ensure background tasks do not outlive the view model.
        livePreviewTask?.cancel()
        timelapseTask?.cancel()
        tetherTask?.cancel()
    }

    /// The selected camera model/port pair or `nil` when no device is active.
    var selectedCamera: CameraDevice? {
        cameras.first(where: { $0.id == selectedCameraID })
    }

    /// Convenience flag for enabling capture controls.
    var hasSelectedCamera: Bool {
        selectedCamera != nil
    }

    /// Initial load entry point called by the app scene.
    func bootstrap() {
        refreshCameras()
    }

    /// Detects cameras and prepares initial setting state.
    func refreshCameras() {
        Task {
            isWorking = true
            defer { isWorking = false }

            do {
                try await service.checkAvailability()
                let discovered = try await service.autoDetect()
                cameras = discovered

                if discovered.isEmpty {
                    selectedCameraID = ""
                    settings = []
                    resetCameraBoundTasks()
                    statusText = "No camera detected. Connect a camera and refresh."
                    return
                }

                if !discovered.contains(where: { $0.id == selectedCameraID }) {
                    selectedCameraID = discovered[0].id
                }

                statusText = "Detected \(discovered.count) camera(s)."
                loadCommonSettings()
            } catch {
                statusText = error.localizedDescription
            }
        }
    }

    /// Changes active camera and tears down any camera-bound background jobs.
    func selectCamera(id: String) {
        if selectedCameraID == id {
            return
        }

        selectedCameraID = id
        resetCameraBoundTasks()
        loadCommonSettings()
    }

    /// Loads a short curated list of commonly useful config keys.
    func loadCommonSettings() {
        Task {
            guard let port = selectedCamera?.port else {
                settings = []
                return
            }

            isWorking = true
            defer { isWorking = false }

            var loaded: [CameraSetting] = []

            for key in Self.commonConfigKeys {
                if let config = try? await service.getConfig(key: key, port: port) {
                    loaded.append(config)
                }
            }

            if loaded.isEmpty {
                do {
                    let keys = try await service.listConfigKeys(port: port)
                    for key in keys.prefix(20) {
                        if let config = try? await service.getConfig(key: key, port: port) {
                            loaded.append(config)
                        }
                    }
                } catch {
                    statusText = error.localizedDescription
                }
            }

            settings = loaded
            statusText = loaded.isEmpty ? "No configurable settings returned by camera." : "Loaded \(loaded.count) settings."
        }
    }

    /// Loads a broader config list for advanced control use-cases.
    func loadMoreSettings() {
        Task {
            guard let port = selectedCamera?.port else {
                return
            }

            isWorking = true
            defer { isWorking = false }

            do {
                let keys = try await service.listConfigKeys(port: port)
                var expanded: [CameraSetting] = []
                for key in keys.prefix(60) {
                    if let config = try? await service.getConfig(key: key, port: port) {
                        expanded.append(config)
                    }
                }
                settings = expanded
                statusText = "Loaded \(expanded.count) advanced settings."
            } catch {
                statusText = error.localizedDescription
            }
        }
    }

    /// Writes a setting value to camera and updates local UI state on success.
    func setSetting(_ setting: CameraSetting, to newValue: String) {
        Task {
            guard let port = selectedCamera?.port else {
                return
            }

            do {
                try await service.setConfig(key: setting.key, value: newValue, port: port)
                if let index = settings.firstIndex(where: { $0.key == setting.key }) {
                    settings[index].current = newValue
                }
                statusText = "Updated \(setting.label) to \(newValue)."
            } catch {
                statusText = error.localizedDescription
            }
        }
    }

    /// Applies the quick preset fields (ISO/shutter/aperture) that have values.
    func applyPreset() {
        Task {
            guard let port = selectedCamera?.port else {
                statusText = "Select a camera first."
                return
            }

            do {
                let applied = try await applyPresetValues(port: port)
                if applied.isEmpty {
                    statusText = "Preset is empty."
                } else {
                    statusText = "Applied preset fields: \(applied.joined(separator: ", "))."
                    loadCommonSettings()
                }
            } catch {
                statusText = error.localizedDescription
            }
        }
    }

    /// Triggers one immediate capture.
    func captureNow() {
        Task {
            guard let port = selectedCamera?.port else {
                statusText = "Select a camera first."
                return
            }
            _ = await captureSingleShot(port: port, label: "Manual Capture")
        }
    }

    /// Opens the configured output directory in Finder, creating it if needed.
    func openOutputDirectoryInFinder() {
        let directoryURL = expandedOutputDirectoryURL
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            NSWorkspace.shared.activateFileViewerSelecting([directoryURL])
            statusText = "Opened output folder in Finder."
        } catch {
            statusText = "Unable to open output folder: \(error.localizedDescription)"
        }
    }

    /// Toggles preview polling.
    func toggleLiveView() {
        liveViewEnabled ? stopLiveView() : startLiveView()
    }

    /// Starts periodic `--capture-preview --stdout` polling and image decode.
    func startLiveView() {
        guard let port = selectedCamera?.port else {
            statusText = "Select a camera first."
            return
        }

        if livePreviewTask != nil {
            return
        }

        liveViewEnabled = true
        statusText = "Live view started."

        livePreviewTask = Task {
            var consecutiveFailures = 0
            while !Task.isCancelled {
                do {
                    let data = try await service.capturePreview(port: port)
                    if let image = NSImage(data: data) {
                        livePreviewImage = image
                        consecutiveFailures = 0
                    }
                } catch {
                    consecutiveFailures += 1
                    statusText = "Live view error: \(error.localizedDescription)"
                }

                // Back off slightly if previews are repeatedly failing.
                let delayNs: UInt64 = consecutiveFailures > 3 ? 1_500_000_000 : 900_000_000
                try? await Task.sleep(nanoseconds: delayNs)
            }
        }
    }

    /// Stops preview polling and updates UI flags.
    func stopLiveView() {
        livePreviewTask?.cancel()
        livePreviewTask = nil
        liveViewEnabled = false
        livePreviewImage = nil
    }

    /// Toggles timelapse queue.
    func toggleTimelapse() {
        timelapseRunning ? stopTimelapse() : startTimelapse()
    }

    /// Starts a bounded sequence of captures on a fixed interval.
    func startTimelapse() {
        guard let port = selectedCamera?.port else {
            statusText = "Select a camera first."
            return
        }

        guard let interval = Int(timelapseIntervalSeconds), interval > 0 else {
            statusText = "Timelapse interval must be a positive integer."
            return
        }

        guard let shots = Int(timelapseShotCount), shots > 0 else {
            statusText = "Timelapse shot count must be a positive integer."
            return
        }

        if timelapseTask != nil {
            return
        }

        timelapseRunning = true
        statusText = "Timelapse started (\(shots) shots, every \(interval)s)."

        timelapseTask = Task {
            for shot in 1...shots {
                if Task.isCancelled {
                    break
                }

                _ = await captureSingleShot(port: port, label: "Timelapse \(shot)/\(shots)")

                if shot < shots {
                    try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                }
            }

            if Task.isCancelled {
                timelapseRunning = false
                timelapseTask = nil
                statusText = "Timelapse stopped."
                return
            }

            timelapseRunning = false
            timelapseTask = nil
            statusText = "Timelapse completed."
        }
    }

    /// Stops the active timelapse task.
    func stopTimelapse() {
        let wasRunning = timelapseTask != nil || timelapseRunning
        timelapseTask?.cancel()
        timelapseTask = nil
        timelapseRunning = false
        if wasRunning {
            statusText = "Timelapse stopped."
        }
    }

    /// Toggles tether event monitoring.
    func toggleTethering() {
        tetheringActive ? stopTethering() : startTethering()
    }

    /// Starts long-poll event monitoring via `--wait-event-and-download`.
    func startTethering() {
        guard let port = selectedCamera?.port else {
            statusText = "Select a camera first."
            return
        }

        guard let interval = Int(tetherIntervalSeconds), interval > 0 else {
            statusText = "Tether interval must be a positive integer."
            return
        }

        if tetherTask != nil {
            return
        }

        stopLiveView()

        tetheringActive = true
        statusText = "Tethered watch started. Waiting for camera events..."

        tetherTask = Task {
            let destination = expandedOutputDirectoryURL

            while !Task.isCancelled {
                do {
                    let downloaded = try await service.waitForEventAndDownload(
                        port: port,
                        destinationDirectory: destination,
                        waitSeconds: interval
                    )

                    for url in downloaded {
                        appendCompletedJob(
                            state: .succeeded,
                            message: "Tethered: saved \(url.lastPathComponent)",
                            outputURL: url
                        )
                    }

                    if let last = downloaded.last {
                        statusText = "Tethered download: \(last.path)"
                    }
                } catch {
                    if Task.isCancelled {
                        break
                    }
                    appendCompletedJob(
                        state: .failed,
                        message: "Tethered: \(error.localizedDescription)",
                        outputURL: nil
                    )
                    statusText = "Tethered error: \(error.localizedDescription)"
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }

            tetherTask = nil
            tetheringActive = false
            statusText = "Tethered watch stopped."
        }
    }

    /// Stops tether polling.
    func stopTethering() {
        let wasRunning = tetherTask != nil || tetheringActive
        tetherTask?.cancel()
        tetherTask = nil
        tetheringActive = false
        if wasRunning {
            statusText = "Tethered watch stopped."
        }
    }

    /// Lets the user choose an output folder using NSOpenPanel.
    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url.path
            statusText = "Output directory set to \(url.path)."
        }
    }

    /// Applies only the non-empty preset fields and returns the names of fields applied.
    private func applyPresetValues(port: String) async throws -> [String] {
        var appliedFields: [String] = []

        if !preset.iso.isEmpty {
            try await service.setConfig(key: "/main/imgsettings/iso", value: preset.iso, port: port)
            appliedFields.append("ISO")
        }

        if !preset.shutterSpeed.isEmpty {
            try await service.setConfig(key: "/main/capturesettings/shutterspeed", value: preset.shutterSpeed, port: port)
            appliedFields.append("Shutter")
        }

        if !preset.aperture.isEmpty {
            try await service.setConfig(key: "/main/capturesettings/aperture", value: preset.aperture, port: port)
            appliedFields.append("Aperture")
        }

        return appliedFields
    }

    /// Executes one capture job end-to-end and records queue status transitions.
    @discardableResult
    private func captureSingleShot(port: String, label: String) async -> Bool {
        let jobID = appendJob(state: .queued, message: "\(label): queued")
        updateJob(jobID, state: .running, message: "\(label): capturing")

        do {
            _ = try await applyPresetValues(port: port)

            let path = expandedOutputDirectoryURL
            let outputURL = try await service.captureImage(port: port, destinationDirectory: path)
            updateJob(
                jobID,
                state: .succeeded,
                message: "\(label): saved \(outputURL.lastPathComponent)",
                outputURL: outputURL
            )
            statusText = "Capture saved: \(outputURL.path)"
            return true
        } catch {
            updateJob(jobID, state: .failed, message: "\(label): \(error.localizedDescription)")
            statusText = error.localizedDescription
            return false
        }
    }

    /// Expands user `~` notation before writing captured files.
    private var expandedOutputDirectoryURL: URL {
        let expandedPath = NSString(string: outputDirectory).expandingTildeInPath
        return URL(fileURLWithPath: expandedPath)
    }

    /// Stops all background tasks that are bound to an active camera selection.
    private func resetCameraBoundTasks() {
        stopLiveView()
        stopTimelapse()
        stopTethering()
    }

    /// Adds a queued/running job record and returns its identifier.
    private func appendJob(state: CaptureJobState, message: String) -> UUID {
        let job = CaptureJob(
            requestedAt: Date(),
            finishedAt: nil,
            outputURL: nil,
            state: state,
            message: message
        )
        jobs.insert(job, at: 0)
        trimJobHistoryIfNeeded()
        return job.id
    }

    /// Inserts a terminal queue event (succeeded/failed).
    private func appendCompletedJob(state: CaptureJobState, message: String, outputURL: URL?) {
        let job = CaptureJob(
            requestedAt: Date(),
            finishedAt: Date(),
            outputURL: outputURL,
            state: state,
            message: message
        )
        jobs.insert(job, at: 0)
        trimJobHistoryIfNeeded()
    }

    /// Updates an existing queue row.
    private func updateJob(_ id: UUID, state: CaptureJobState, message: String, outputURL: URL? = nil) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else {
            return
        }
        jobs[index].state = state
        jobs[index].message = message
        jobs[index].outputURL = outputURL
        if state == .succeeded || state == .failed {
            jobs[index].finishedAt = Date()
        } else {
            jobs[index].finishedAt = nil
        }
    }

    /// Keeps queue size bounded so very long sessions do not grow memory indefinitely.
    private func trimJobHistoryIfNeeded() {
        if jobs.count > Self.maxJobHistory {
            jobs.removeLast(jobs.count - Self.maxJobHistory)
        }
    }
}
