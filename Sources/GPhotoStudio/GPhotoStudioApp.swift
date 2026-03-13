import SwiftUI

/// Application entry point for the native macOS app target.
@main
struct GPhotoStudioApp: App {
    /// Shared view model for the single-window app lifecycle.
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup("gPhoto Studio") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 1150, minHeight: 800)
                .onAppear {
                    viewModel.bootstrap()
                }
        }
        .commands {
            CommandMenu("Camera") {
                Button("Refresh Cameras") {
                    viewModel.refreshCameras()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Capture Now") {
                    viewModel.captureNow()
                }
                .keyboardShortcut("c", modifiers: [.command])
                .disabled(!viewModel.hasSelectedCamera)

                Button(viewModel.liveViewEnabled ? "Stop Live View" : "Start Live View") {
                    viewModel.toggleLiveView()
                }
                .keyboardShortcut("l", modifiers: [.command])
                .disabled(!viewModel.hasSelectedCamera)
            }
        }
    }
}
