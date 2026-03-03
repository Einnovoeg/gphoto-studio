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
    }
}
