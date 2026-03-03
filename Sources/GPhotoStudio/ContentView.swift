import SwiftUI

/// Main two-pane desktop interface.
struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    private let buyMeCoffeeURL = URL(string: "https://buymeacoffee.com/einnovoeg")!

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 340, idealWidth: 360)

            mainPanel
                .frame(minWidth: 760, idealWidth: 920)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.97, blue: 0.98), Color(red: 0.92, green: 0.94, blue: 0.97)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .safeAreaInset(edge: .bottom) {
            statusFooter
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                appHeader

                GroupBox("Camera") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Button("Refresh Cameras") {
                                viewModel.refreshCameras()
                            }
                            .disabled(viewModel.isWorking)

                            Spacer()

                            Text("\(viewModel.cameras.count) found")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Picker("Active Camera", selection: Binding(
                            get: { viewModel.selectedCameraID },
                            set: { viewModel.selectCamera(id: $0) }
                        )) {
                            ForEach(viewModel.cameras) { camera in
                                Text("\(camera.model) [\(camera.port)]")
                                    .tag(camera.id)
                            }
                        }
                        .labelsHidden()
                        .disabled(viewModel.cameras.isEmpty)

                        Text(viewModel.selectedCamera?.model ?? "No camera selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Capture") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            TextField("Output folder", text: $viewModel.outputDirectory)
                                .textFieldStyle(.roundedBorder)
                            Button("Browse") {
                                viewModel.chooseOutputDirectory()
                            }
                        }

                        HStack {
                            Button("Capture Now") {
                                viewModel.captureNow()
                            }
                            .disabled(!viewModel.hasSelectedCamera)
                            .keyboardShortcut("c", modifiers: [.command])

                            Button(viewModel.liveViewEnabled ? "Stop Live View" : "Start Live View") {
                                viewModel.toggleLiveView()
                            }
                            .disabled(!viewModel.hasSelectedCamera)
                        }

                        HStack {
                            Button("Open Output Folder") {
                                viewModel.openOutputDirectoryInFinder()
                            }

                            Spacer()

                            if viewModel.isWorking {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Preset (digiCamControl style)") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("ISO (e.g. 100)", text: $viewModel.preset.iso)
                            .textFieldStyle(.roundedBorder)
                        TextField("Shutter (e.g. 1/125)", text: $viewModel.preset.shutterSpeed)
                            .textFieldStyle(.roundedBorder)
                        TextField("Aperture (e.g. 5.6)", text: $viewModel.preset.aperture)
                            .textFieldStyle(.roundedBorder)

                        Button("Apply Preset") {
                            viewModel.applyPreset()
                        }
                        .disabled(!viewModel.hasSelectedCamera)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Timelapse") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Interval seconds", text: $viewModel.timelapseIntervalSeconds)
                            .textFieldStyle(.roundedBorder)
                        TextField("Shot count", text: $viewModel.timelapseShotCount)
                            .textFieldStyle(.roundedBorder)

                        Button(viewModel.timelapseRunning ? "Stop Timelapse" : "Start Timelapse") {
                            viewModel.toggleTimelapse()
                        }
                        .disabled(!viewModel.hasSelectedCamera)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Tethered Watch") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Event wait seconds", text: $viewModel.tetherIntervalSeconds)
                            .textFieldStyle(.roundedBorder)
                        Text("Auto-downloads photos when shutter is triggered on camera.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Button(viewModel.tetheringActive ? "Stop Tethered Watch" : "Start Tethered Watch") {
                            viewModel.toggleTethering()
                        }
                        .disabled(!viewModel.hasSelectedCamera)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Live Preview") {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.87))

                    if let image = viewModel.livePreviewImage {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                    } else {
                        Text("Start live view to display camera preview")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(minHeight: 320)
                .overlay(alignment: .topLeading) {
                    Text(viewModel.liveViewEnabled ? "LIVE" : "IDLE")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(viewModel.liveViewEnabled ? Color.green.opacity(0.8) : Color.gray.opacity(0.75))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .padding(10)
                }
            }

            GroupBox("Camera Settings") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button("Load Common") {
                            viewModel.loadCommonSettings()
                        }

                        Button("Load More") {
                            viewModel.loadMoreSettings()
                        }
                    }

                    List(viewModel.settings) { setting in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(setting.label)
                                Text(setting.key)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if setting.choices.isEmpty {
                                Text(setting.current)
                                    .font(.system(.body, design: .monospaced))
                            } else {
                                Menu(setting.current.isEmpty ? "Choose" : setting.current) {
                                    ForEach(setting.choices, id: \.self) { choice in
                                        Button(choice) {
                                            viewModel.setSetting(setting, to: choice)
                                        }
                                    }
                                }
                                .menuStyle(.borderlessButton)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(minHeight: 170)
                }
            }

            GroupBox("Capture Queue") {
                List(viewModel.jobs) { job in
                    HStack {
                        stateBadge(for: job.state)

                        VStack(alignment: .leading) {
                            Text(job.message)
                            if let outputURL = job.outputURL {
                                Text(outputURL.path)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(minHeight: 140)
            }
        }
    }

    private var appHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("gPhoto Studio")
                .font(.title2.weight(.bold))

            Text("Native macOS GUI for gphoto2 with digiCamControl-style workflow controls.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if viewModel.hasSelectedCamera {
                    Label("Camera Connected", systemImage: "camera.fill")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.16))
                        .clipShape(Capsule())
                } else {
                    Label("No Camera", systemImage: "camera")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.16))
                        .clipShape(Capsule())
                }

                Spacer()

                Link(destination: buyMeCoffeeURL) {
                    Label("Buy Me a Coffee", systemImage: "cup.and.saucer.fill")
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var statusFooter: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(viewModel.hasSelectedCamera ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(viewModel.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func stateBadge(for state: CaptureJobState) -> some View {
        Text(state.rawValue.capitalized)
            .font(.caption.weight(.semibold))
            .frame(width: 82, alignment: .leading)
            .foregroundStyle(color(for: state))
    }

    private func color(for state: CaptureJobState) -> Color {
        switch state {
        case .queued:
            return .orange
        case .running:
            return .blue
        case .succeeded:
            return .green
        case .failed:
            return .red
        }
    }
}
