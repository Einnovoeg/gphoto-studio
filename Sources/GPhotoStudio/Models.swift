import Foundation

/// Represents one camera endpoint reported by `gphoto2 --auto-detect`.
/// A single physical device can expose more than one logical port.
struct CameraDevice: Identifiable, Hashable {
    /// Human-readable camera model returned by gphoto2.
    let model: String
    /// Camera transport endpoint, e.g. `usb:001,042`.
    let port: String

    /// Stable identity used for list selections.
    var id: String { "\(model)|\(port)" }
}

/// Lifecycle state for capture/tether/timelapse jobs shown in the queue.
enum CaptureJobState: String {
    case queued
    case running
    case succeeded
    case failed
}

/// UI-facing capture record used by the queue panel.
struct CaptureJob: Identifiable {
    /// Unique queue item identifier.
    let id = UUID()
    /// Time the job was scheduled.
    let requestedAt: Date
    /// Completion timestamp, only present for terminal states.
    var finishedAt: Date?
    /// Output file path on disk when available.
    var outputURL: URL?
    /// Current job state.
    var state: CaptureJobState
    /// Human-readable status text.
    var message: String
}

/// One camera configuration key and current selection metadata.
struct CameraSetting: Identifiable, Hashable {
    /// Full gphoto2 config path (for example `/main/imgsettings/iso`).
    let key: String
    /// Human-readable label from gphoto2.
    var label: String
    /// Current effective value.
    var current: String
    /// Valid menu options. Empty means read-only/free text presentation.
    var choices: [String]

    var id: String { key }
}

/// Quick preset fields mapped to common DSLR controls.
struct CapturePreset: Hashable {
    var iso: String = ""
    var shutterSpeed: String = ""
    var aperture: String = ""
}
