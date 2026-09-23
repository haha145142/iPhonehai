import AVFoundation
import UIKit
import Combine

final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published var lastPhoto: UIImage?
    @Published var errorMessage: String?
    @Published var configLabel: String = "未加载配置"

    var settings = PhotoSettings()

    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.iphonehai.camera.session")
    private var configured = false

    func configure() {
        let store = AgcConfigStore.shared
        settings = PhotoSettings.from(config: store.config)
        configLabel = store.configName

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUpSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.setUpSession()
                } else {
                    DispatchQueue.main.async { self?.errorMessage = "相机权限未开启" }
                }
            }
        default:
            DispatchQueue.main.async {
                self.errorMessage = "相机权限未开启，请在系统设置中允许相机权限"
            }
        }
    }

    private func setUpSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.configured else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async { self.errorMessage = "无法访问后置相机" }
                return
            }

            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }

            if let connection = self.photoOutput.connection(with: .video),
               connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }

            self.session.commitConfiguration()
            self.configured = true
            self.session.startRunning()
        }
    }

    func capture() {
        sessionQueue.async { [weak self] in
            guard let self, self.configured else { return }
            let photoSettings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let ci = CIImage(data: data) else {
            DispatchQueue.main.async {
                self.errorMessage = error?.localizedDescription ?? "照片拍摄失败"
            }
            return
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            let ui = PhotoProcessor.shared.process(ci, settings: self.settings)

            DispatchQueue.main.async {
                self.lastPhoto = ui
                if let ui {
                    UIImageWriteToSavedPhotosAlbum(ui, nil, nil, nil)
                }
            }
        }
    }
}
