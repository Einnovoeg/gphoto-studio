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

    // MARK: Sidebar

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                appHeader

                GroupBox {
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
                } label: {
                    panelLabel("Camera", systemImage: "camera")
                }

                GroupBox {
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
                } label: {
                    panelLabel("Capture", systemImage: "camera.aperture")
                }

                GroupBox {
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
                } label: {
                    panelLabel("Preset", systemImage: "dial.low")
                }

                GroupBox {
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
                } label: {
                    panelLabel("Timelapse", systemImage: "clock.arrow.circlepath")
                }

                GroupBox {
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
                } label: {
                    panelLabel("Tethered Watch", systemImage: "cable.connector")
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Main Panel

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            overviewStrip

            GroupBox {
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
            } label: {
                panelLabel("Live Preview", systemImage: "viewfinder")
            }

            GroupBox {
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
            } label: {
                panelLabel("Camera Settings", systemImage: "slider.horizontal.3")
            }

            GroupBox {
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
            } label: {
                HStack {
                    panelLabel("Capture Queue", systemImage: "list.bullet.rectangle")
                    Spacer()
                    Button("Clear") {
                        viewModel.clearJobs()
                    }
                    .buttonStyle(.link)
                    .disabled(viewModel.jobs.isEmpty)
                }
            }
        }
    }

    /// Branding block with high-level app context and support link.
    private var appHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("gPhoto Studio")
                .font(.system(size: 28, weight: .bold, design: .rounded))

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

    /// Lightweight dashboard cards that summarize the current session state.
    private var overviewStrip: some View {
        HStack(spacing: 12) {
            dashboardCard(
                title: "Camera",
                value: viewModel.hasSelectedCamera ? "Connected" : "Waiting",
                detail: viewModel.selectedCameraSummary,
                tint: viewModel.hasSelectedCamera ? Color.green : Color.orange
            )

            dashboardCard(
                title: "Queue",
                value: "\(viewModel.jobs.count)",
                detail: "\(viewModel.successfulJobCount) completed",
                tint: Color.blue
            )

            dashboardCard(
                title: "Output",
                value: outputDirectoryName,
                detail: viewModel.latestOutputURL?.lastPathComponent ?? "No captures yet",
                tint: Color.teal
            )
        }
    }

    /// Always-visible footer for low-noise operational status feedback.
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

    private var outputDirectoryName: String {
        let expandedPath = NSString(string: viewModel.outputDirectory).expandingTildeInPath
        let lastPathComponent = URL(fileURLWithPath: expandedPath).lastPathComponent
        return lastPathComponent.isEmpty ? expandedPath : lastPathComponent
    }

    /// Shared label styling for panel headers across the app.
    @ViewBuilder
    private func panelLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(.headline, design: .rounded))
    }

    /// Reusable dashboard tile with a strong numeric/value line and softer context text.
    @ViewBuilder
    private func dashboardCard(title: String, value: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.16), Color.white.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    /// Queue badge used to make job state readable at a glance.
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
