import SwiftUI

struct CameraRootView: View {
    @StateObject private var camera = CameraManager()
    @State private var mode: CaptureMode = .photo
    @State private var showWatermark = true
    @State private var showFrame = false

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Text(camera.configLabel)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.45))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())

                    Spacer()
                }
                .padding(.top, 8)
                .padding(.horizontal, 12)

                Spacer()

                HStack(spacing: 14) {
                    ForEach(CaptureMode.allCases) { item in
                        Button {
                            mode = item
                            applyMode(item)
                        } label: {
                            Text(item.title)
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(mode == item ? Color.white : Color.black.opacity(0.35))
                                .foregroundStyle(mode == item ? .black : .white)
                                .clipShape(Capsule())
                        }
                    }
                }

                HStack(spacing: 18) {
                    Toggle("水印", isOn: $showWatermark)
                        .toggleStyle(.button)
                        .onChange(of: showWatermark) { _, value in
                            camera.settings.watermark = value
                        }

                    Toggle("相框", isOn: $showFrame)
                        .toggleStyle(.button)
                        .onChange(of: showFrame) { _, value in
                            camera.settings.drawFrame = value
                        }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.bottom, 10)

                HStack {
                    if let photo = camera.lastPhoto {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.white.opacity(0.2))
                            .frame(width: 48, height: 48)
                    }

                    Spacer()

                    Button {
                        camera.capture()
                    } label: {
                        Circle()
                            .fill(.white)
                            .frame(width: 74, height: 74)
                            .overlay(
                                Circle()
                                    .stroke(.black.opacity(0.2), lineWidth: 2)
                            )
                    }

                    Spacer()

                    Color.clear
                        .frame(width: 48, height: 48)
                }
                .padding(.bottom, 24)
                .padding(.horizontal, 24)
            }

            if let err = camera.errorMessage {
                Text(err)
                    .foregroundStyle(.white)
                    .padding()
                    .background(.red.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding()
            }
        }
        .onAppear {
            camera.configure()
        }
    }

    private func applyMode(_ mode: CaptureMode) {
        switch mode {
        case .photo:
            camera.settings.contrast = 1
            camera.settings.vignette = 0
            camera.settings.saturation = 1
        case .night:
            camera.settings.gamma = 1.35
            camera.settings.contrast = 1.15
            camera.settings.vignette = 0.25
        case .portrait:
            camera.settings.gamma = 1.05
            camera.settings.contrast = 1.08
            camera.settings.vignette = 0.45
        }
    }
}

enum CaptureMode: String, CaseIterable, Identifiable {
    case photo, night, portrait

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photo: return "拍照"
        case .night: return "夜景"
        case .portrait: return "人像"
        }
    }
}
