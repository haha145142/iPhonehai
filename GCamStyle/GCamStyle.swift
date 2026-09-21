import SwiftUI
import Combine
@preconcurrency import AVFoundation
@preconcurrency import Photos
import PhotosUI
import ImageIO
import UniformTypeIdentifiers
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import MetalKit
import CoreMedia

// MARK: - Capture / editing models

enum CaptureMode: String, CaseIterable, Identifiable {
    case photo = "PHOTO"
    case proRAW = "ProRAW"
    case livePhoto = "LIVE"

    var id: String { rawValue }
}

struct MetadataDraft: Hashable {
    // Empty values mean "use the selected preset" during export.
    var make = ""
    var model = ""
    var lens = ""
    var artist = ""
    var copyright = ""
    var software = "GCamStyle iOS"
    var dateOriginal = ""
    var stripGPS = false
}

struct CameraPreset: Identifiable, Hashable {
    let id: String
    let brand: String
    let model: String
    let lens: String
    let focal: String
    let aperture: String
    let iso: String
    let shutter: String
    let style: String

    // Fine-grained image look controls.
    let exposure: Float
    let saturation: Float
    let contrast: Float
    let highlights: Float
    let shadows: Float
    let sharpness: Float
    let warmth: Float
    let tint: Float
    let channelBias: Float

    // Metadata / watermark identity.
    let exifMake: String
    let exifModel: String

    var watermarkAccent: WatermarkAccent {
        switch brand.uppercased() {
        case "LEICA": return .leica
        case "HASSELBLAD": return .hasselblad
        case "ZEISS": return .zeiss
        case "VIVO": return .vivo
        case "XIAOMI": return .xiaomi
        case "HUAWEI": return .huawei
        case "OPPO": return .oppo
        case "GOOGLE": return .google
        case "APPLE": return .apple
        case "SONY": return .sony
        case "CANON": return .canon
        case "NIKON": return .nikon
        case "FUJIFILM": return .fujifilm
        case "RICOH": return .ricoh
        default: return .neutral
        }
    }
}

enum WatermarkAccent {
    case leica, hasselblad, zeiss, vivo, xiaomi, huawei, oppo, google, apple, sony, canon, nikon, fujifilm, ricoh, neutral

    var uiColor: UIColor {
        switch self {
        case .leica: return UIColor(red: 0.88, green: 0.10, blue: 0.08, alpha: 1)
        case .hasselblad: return UIColor(red: 0.98, green: 0.55, blue: 0.08, alpha: 1)
        case .zeiss, .vivo: return UIColor(red: 0.18, green: 0.55, blue: 0.92, alpha: 1)
        case .xiaomi: return UIColor(red: 0.95, green: 0.35, blue: 0.08, alpha: 1)
        case .huawei: return UIColor(red: 0.88, green: 0.08, blue: 0.12, alpha: 1)
        case .oppo: return UIColor(red: 0.35, green: 0.80, blue: 0.45, alpha: 1)
        case .google: return UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1)
        case .apple: return UIColor.white
        case .sony: return UIColor(red: 0.45, green: 0.55, blue: 0.82, alpha: 1)
        case .canon: return UIColor(red: 0.75, green: 0.10, blue: 0.08, alpha: 1)
        case .nikon: return UIColor(red: 0.95, green: 0.78, blue: 0.08, alpha: 1)
        case .fujifilm: return UIColor(red: 0.20, green: 0.72, blue: 0.48, alpha: 1)
        case .ricoh: return UIColor(red: 0.90, green: 0.20, blue: 0.12, alpha: 1)
        case .neutral: return UIColor.white
        }
    }
}

// 32 camera identities × 4 rendering templates = 128 selectable presets.
enum PresetLibrary {
    static let all: [CameraPreset] = {
        let bases: [(String,String,String,String,String,String,String,String,String,Float,Float,Float,Float,Float,Float,Float,Float,String,String)] = [
            ("LEICA","Q3","SUMMILUX 1:1.7/28 ASPH.","28mm","F1.7","ISO 100","1/250s","Leica Look","Natural",0,0.92,1.08,0.92,0.10,0.28,0,0,"Leica Camera AG","LEICA Q3"),
            ("LEICA","Q3 43","APO-SUMMICRON 1:2/43 ASPH.","43mm","F2.0","ISO 100","1/250s","Leica Look","Natural",0,0.93,1.08,0.94,0.08,0.25,0,0,"Leica Camera AG","LEICA Q3 43"),
            ("LEICA","M11","SUMMILUX-M 1:1.4/35 ASPH.","35mm","F1.4","ISO 64","1/500s","Leica M","Natural",0,0.92,1.10,0.92,0.09,0.30,0,0,"Leica Camera AG","LEICA M11"),
            ("LEICA","SL3","VARIO-ELMARIT-SL 24-90","50mm","F2.8","ISO 100","1/250s","Leica SL","Natural",-0.02,0.94,1.07,0.95,0.10,0.28,0,0,"Leica Camera AG","LEICA SL3"),
            ("LEICA","D-LUX 8","DC VARIO-SUMMILUX","24mm","F1.7","ISO 100","1/320s","Leica D-Lux","Natural",0,0.90,1.05,0.90,0.08,0.22,0,0,"Leica Camera AG","LEICA D-LUX 8"),
            ("HASSELBLAD","X2D 100C","XCD 2,5/38V","38mm","F2.5","ISO 64","1/320s","Hasselblad Natural","Natural",0,0.86,1.03,0.92,0.14,0.22,0,0,"Hasselblad","X2D 100C"),
            ("HASSELBLAD","X2D 100C","XCD 2,5/55V","55mm","F2.5","ISO 64","1/320s","Hasselblad Portrait","Natural",0,0.87,1.03,0.90,0.16,0.22,0,0,"Hasselblad","X2D 100C"),
            ("HASSELBLAD","907X","XCD 4/45P","45mm","F4.0","ISO 100","1/320s","Hasselblad Medium Format","Natural",0.01,0.87,1.02,0.94,0.14,0.20,0,0,"Hasselblad","907X"),
            ("ZEISS","ZX1","Distagon 2/35","35mm","F2.0","ISO 100","1/250s","ZEISS Natural Color","Natural",0,0.98,1.12,0.90,0.06,0.34,-2,0,"ZEISS","ZX1"),
            ("ZEISS","Otus 55","Otus 1.4/55","55mm","F1.4","ISO 100","1/500s","ZEISS Microcontrast","Natural",0,0.97,1.14,0.92,0.07,0.42,-1,0,"ZEISS","Otus 55"),
            ("vivo","X200 Ultra","ZEISS Master","35mm","F1.2","ISO 50","1/250s","vivo ZEISS","Natural",0.01,1.06,1.06,0.96,0.12,0.26,2,0,"vivo","X200 Ultra"),
            ("vivo","X200 Pro","ZEISS Tele","50mm","F1.6","ISO 50","1/250s","vivo ZEISS Tele","Natural",0.01,1.04,1.05,0.94,0.12,0.28,1,0,"vivo","X200 Pro"),
            ("vivo","X100 Ultra","ZEISS APO Tele","85mm","F2.5","ISO 64","1/320s","vivo ZEISS Portrait","Natural",0,1.03,1.05,0.92,0.18,0.24,1,1,"vivo","X100 Ultra"),
            ("XIAOMI","15 Ultra","Leica Summilux","23mm","F1.63","ISO 50","1/250s","Leica Authentic","Natural",0,0.96,1.10,0.93,0.09,0.30,0,0,"Xiaomi","15 Ultra"),
            ("XIAOMI","15 Ultra","Leica Portrait 75","75mm","F2.5","ISO 64","1/320s","Leica Portrait","Natural",0,0.95,1.08,0.90,0.16,0.25,0,0,"Xiaomi","15 Ultra"),
            ("XIAOMI","14 Ultra","Leica Vario-Summilux","23mm","F1.63","ISO 50","1/250s","Leica Authentic","Natural",0,0.96,1.08,0.93,0.10,0.28,0,0,"Xiaomi","14 Ultra"),
            ("HUAWEI","Pura 70 Ultra","XMAGE","24mm","F1.6","ISO 50","1/200s","XMAGE Natural","Natural",0.01,1.05,1.06,0.93,0.11,0.25,2,1,"HUAWEI","Pura 70 Ultra"),
            ("HUAWEI","Mate 70 Pro","XMAGE","24mm","F1.4","ISO 50","1/200s","XMAGE Master","Natural",0.01,1.04,1.05,0.92,0.11,0.28,2,1,"HUAWEI","Mate 70 Pro"),
            ("OPPO","Find X8 Ultra","Hasselblad","23mm","F1.8","ISO 50","1/250s","Hasselblad Portrait","Natural",0,1.03,1.05,0.92,0.15,0.27,1,0,"OPPO","Find X8 Ultra"),
            ("OPPO","Find X7 Ultra","Hasselblad","23mm","F1.8","ISO 50","1/250s","Hasselblad Natural","Natural",0,1.03,1.05,0.94,0.13,0.25,1,0,"OPPO","Find X7 Ultra"),
            ("GOOGLE","Pixel 10 Pro","Computational","25mm","F1.7","ISO 50","1/250s","Pixel Computational","Natural",0,1.02,1.04,0.92,0.12,0.34,0,0,"Google","Pixel 10 Pro"),
            ("GOOGLE","Pixel 9 Pro","Computational","25mm","F1.7","ISO 50","1/250s","Pixel Computational","Natural",0,1.03,1.04,0.93,0.11,0.32,0,0,"Google","Pixel 9 Pro"),
            ("APPLE","iPhone 17 Pro","Main","24mm","F1.78","ISO 50","1/250s","Apple ProRAW","Natural",0,1.00,1.03,0.95,0.12,0.26,0,0,"Apple","iPhone 17 Pro"),
            ("APPLE","iPhone 17 Pro Max","Main","24mm","F1.78","ISO 50","1/250s","Apple ProRAW","Natural",0,1.00,1.03,0.95,0.12,0.26,0,0,"Apple","iPhone 17 Pro Max"),
            ("SONY","α1 II","G Master","35mm","F1.4","ISO 100","1/500s","Sony G Master","Natural",0,0.98,1.10,0.94,0.08,0.38,-1,0,"SONY","ILCE-1M2"),
            ("SONY","α7R V","G Master","35mm","F1.4","ISO 100","1/500s","Sony G Master","Natural",0,0.98,1.10,0.93,0.08,0.36,-1,0,"SONY","ILCE-7RM5"),
            ("CANON","EOS R5 Mark II","RF L","50mm","F1.2","ISO 100","1/500s","Canon RF L","Natural",0,1.01,1.08,0.93,0.10,0.30,1,0,"Canon","Canon EOS R5 Mark II"),
            ("NIKON","Z8","NIKKOR Z","50mm","F1.8","ISO 64","1/500s","NIKKOR Z","Natural",0,1.00,1.08,0.94,0.10,0.32,0,0,"NIKON CORPORATION","NIKON Z 8"),
            ("FUJIFILM","X100VI","FUJINON","23mm","F2.0","ISO 125","1/250s","Fujifilm Film Look","Natural",0,0.96,1.06,0.90,0.12,0.26,1,-1,"FUJIFILM","X100VI"),
            ("RICOH","GR IIIx","GR Lens","40mm","F2.8","ISO 100","1/500s","Ricoh Street","Natural",0,0.95,1.05,0.91,0.09,0.42,-1,0,"RICOH IMAGING COMPANY, LTD.","RICOH GR IIIx"),
            ("PANASONIC","S1RII","LUMIX S PRO","50mm","F1.8","ISO 100","1/500s","LUMIX Natural","Natural",0,0.98,1.07,0.94,0.11,0.33,0,0,"Panasonic","DC-S1RM2"),
            ("SIGMA","fp L","Contemporary","45mm","F2.8","ISO 100","1/500s","SIGMA Contemporary","Natural",0,0.97,1.06,0.94,0.12,0.34,0,0,"SIGMA","SIGMA fp L")
        ]

        let variants: [(String, Float, Float, Float, Float, Float)] = [
            ("Natural", 1.00, 1.00, 0.00, 0.00, 0.00),
            ("Cinematic", 0.93, 1.10, -0.08, 0.12, 0.55),
            ("Portrait", 1.02, 1.05, 0.06, 0.18, 0.28),
            ("Street", 0.90, 1.12, -0.02, -0.04, 0.70)
        ]

        var result: [CameraPreset] = []
        result.reserveCapacity(bases.count * variants.count)

        for b in bases {
            for v in variants {
                let name = v.0
                result.append(
                    CameraPreset(
                        id: "\(b.0)-\(b.1)-\(name)",
                        brand: b.0,
                        model: b.1,
                        lens: "\(b.2) · \(name)",
                        focal: b.3,
                        aperture: b.4,
                        iso: b.5,
                        shutter: b.6,
                        style: name,
                        exposure: b.9 + v.3,
                        saturation: b.10 * v.1,
                        contrast: b.11 * v.2,
                        highlights: min(1.0, max(0.0, b.12 + v.4)),
                        shadows: min(1.0, max(0.0, b.13)),
                        sharpness: min(1.0, max(0.0, b.14 + v.5)),
                        warmth: b.15,
                        tint: b.16,
                        channelBias: 0,
                        exifMake: b.17,
                        exifModel: b.18
                    )
                )
            }
        }
        return result
    }()

    static var brands: [String] {
        var seen = Set<String>()
        return all.compactMap {
            seen.insert($0.brand).inserted ? $0.brand : nil
        }
    }
}

// MARK: - Camera engine

final class CameraEngine: NSObject, ObservableObject {
    let session = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()

    @Published var ready = false
    @Published var isCapturing = false
    @Published var errorMessage: String?
    @Published var lastImage: UIImage?
    @Published var lastSavedURL: URL?
    @Published var proRAWSupported = false
    @Published var livePhotoSupported = false

    private var currentInput: AVCaptureDeviceInput?
    private var delegates: [Int64: PhotoCaptureDelegate] = [:]

    override init() {
        super.init()
        requestPermissions()
    }

    private func requestPermissions() {
        Task {
            let cameraOK: Bool
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                cameraOK = true
            case .notDetermined:
                cameraOK = await AVCaptureDevice.requestAccess(for: .video)
            default:
                cameraOK = false
            }

            guard cameraOK else {
                errorMessage = "请在设置中允许相机权限。"
                return
            }

            configureSession()
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device)
        else {
            session.commitConfiguration()
            errorMessage = "找不到后置摄像头。"
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            if let connection = videoOutput.connection(with: .video) {
                connection.videoRotationAngle = 90
            }
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
        }

        livePhotoSupported = photoOutput.isLivePhotoCaptureSupported
        proRAWSupported = photoOutput.isAppleProRAWSupported

        if proRAWSupported {
            photoOutput.isAppleProRAWEnabled = true
        }

        if livePhotoSupported {
            photoOutput.isLivePhotoCaptureEnabled = true
        }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async {
                self?.ready = true
            }
        }
    }

    func flipCamera() {
        guard let oldInput = currentInput else { return }
        let newPosition: AVCaptureDevice.Position = oldInput.device.position == .back ? .front : .back

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
            let newInput = try? AVCaptureDeviceInput(device: device)
        else { return }

        session.beginConfiguration()
        session.removeInput(oldInput)
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            currentInput = newInput
        }
        if let connection = videoOutput.connection(with: .video) {
            connection.videoRotationAngle = 90
        }
        session.commitConfiguration()
    }

    func capture(
        preset: CameraPreset,
        mode: CaptureMode,
        watermark: Bool,
        metadata: MetadataDraft
    ) {
        guard !isCapturing else { return }
        guard ready else { return }

        isCapturing = true

        let settings: AVCapturePhotoSettings
        switch mode {
        case .photo:
            let codec: AVVideoCodecType = photoOutput.availablePhotoCodecTypes.contains(.jpeg) ? .jpeg : .hevc
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: codec])

        case .proRAW:
            guard proRAWSupported else {
                isCapturing = false
                errorMessage = "这台 iPhone/当前配置不支持 Apple ProRAW。"
                return
            }

            guard let rawType = photoOutput.availableRawPhotoPixelFormatTypes.first(
                where: { AVCapturePhotoOutput.isAppleProRAWPixelFormat($0) }
            ) else {
                isCapturing = false
                errorMessage = "没有可用的 Apple ProRAW 格式。"
                return
            }

            let processedFormat: [String: Any]
            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                processedFormat = [AVVideoCodecKey: AVVideoCodecType.hevc]
            } else {
                processedFormat = [AVVideoCodecKey: AVVideoCodecType.jpeg]
            }

            settings = AVCapturePhotoSettings(
                rawPixelFormatType: rawType,
                processedFormat: processedFormat
            )
            settings.photoQualityPrioritization = .quality

        case .livePhoto:
            guard livePhotoSupported else {
                isCapturing = false
                errorMessage = "这台 iPhone 不支持 Live Photo 捕获。"
                return
            }

            let codec: AVVideoCodecType = photoOutput.availablePhotoCodecTypes.contains(.jpeg) ? .jpeg : .hevc
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: codec])
            settings.livePhotoMovieFileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("GCamStyle-\(UUID().uuidString).mov")
        }

        settings.photoQualityPrioritization = .quality

        let delegate = PhotoCaptureDelegate(
            owner: self,
            settingsID: settings.uniqueID,
            preset: preset,
            mode: mode,
            watermark: watermark,
            metadata: metadata
        )
        delegates[settings.uniqueID] = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    func processImportedPhoto(
        data: Data,
        preset: CameraPreset,
        watermark: Bool,
        metadata: MetadataDraft
    ) {
        guard let url = try? ExportService.renderToJPEG(
            sourceData: data,
            preset: preset,
            watermark: watermark,
            metadata: metadata
        ) else {
            errorMessage = "照片处理失败。"
            return
        }

        do {
            let finalData = try Data(contentsOf: url)
            guard let image = UIImage(data: finalData) else { return }
            lastImage = image
            lastSavedURL = url
            Task { await PhotoSaver.saveJPEG(url: url) }
        } catch {
            errorMessage = "处理照片失败：\(error.localizedDescription)"
        }
    }

    func clearPreview() {
        lastImage = nil
        lastSavedURL = nil
    }

    fileprivate func finishCapture(id: Int64) {
        delegates[id] = nil
        isCapturing = false
    }

    fileprivate func handleProcessedPhoto(
        data: Data,
        preset: CameraPreset,
        mode: CaptureMode,
        watermark: Bool,
        metadata: MetadataDraft
    ) {
        guard
            let url = try? ExportService.renderToJPEG(
                sourceData: data,
                preset: preset,
                watermark: watermark,
                metadata: metadata
            ),
            let outputData = try? Data(contentsOf: url),
            let image = UIImage(data: outputData)
        else {
            errorMessage = "照片导出失败。"
            return
        }

        lastImage = image
        lastSavedURL = url

        Task {
            await PhotoSaver.saveJPEG(url: url)

            if mode == .proRAW {
                errorMessage = "ProRAW + 风格化 JPEG 已保存。原始 ProRAW 保持未修改。"
            } else if mode == .photo {
                errorMessage = nil
            }
        }
    }

    fileprivate func handleRawPhoto(data: Data, preset: CameraPreset) {
        let rawURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GCamStyle-RAW-\(UUID().uuidString).dng")

        do {
            try data.write(to: rawURL, options: .atomic)

            // Preserve the original ProRAW DNG in Photos.
            Task {
                await PhotoSaver.saveRAW(url: rawURL)
            }

            // Develop the RAW with Apple's CIRAWFilter, then apply the
            // selected look to a companion JPEG. The original DNG is untouched.
            guard let rawFilter = CIRAWFilter(imageURL: rawURL) else { return }

            rawFilter.isDraftModeEnabled = false
            rawFilter.exposure = preset.exposure

            if rawFilter.isContrastSupported {
                rawFilter.contrastAmount = min(1.0, max(0.0, preset.contrast * 0.65))
            }
            if rawFilter.isDetailSupported {
                rawFilter.detailAmount = min(3.0, max(0.0, preset.sharpness * 2.0))
            }
            if rawFilter.isSharpnessSupported {
                rawFilter.sharpnessAmount = min(1.0, max(0.0, preset.sharpness))
            }
            if rawFilter.isLensCorrectionSupported {
                rawFilter.isLensCorrectionEnabled = true
            }
            if rawFilter.isLuminanceNoiseReductionSupported {
                rawFilter.luminanceNoiseReductionAmount = 0.5
            }
            if rawFilter.isColorNoiseReductionSupported {
                rawFilter.colorNoiseReductionAmount = 0.35
            }

            guard let rawImage = rawFilter.outputImage else { return }
            let styled = PhotoProcessor.applyLook(rawImage, preset: preset)
            let context = CIContext()
            guard let cg = context.createCGImage(styled, from: styled.extent) else { return }

            let exportMetadata = MetadataDraft(
                make: preset.exifMake,
                model: preset.exifModel,
                lens: preset.lens,
                artist: "",
                copyright: "",
                software: "GCamStyle iOS ProRAW",
                dateOriginal: "",
                stripGPS: false
            )

            if let styledURL = try? ExportService.writeRenderedJPEG(
                cgImage: cg,
                preset: preset,
                metadata: exportMetadata,
                watermark: false,
                sourceProperties: [:]
            ),
            let styledData = try? Data(contentsOf: styledURL),
            let image = UIImage(data: styledData) {
                DispatchQueue.main.async {
                    self.lastImage = image
                    self.lastSavedURL = styledURL
                    self.errorMessage = "ProRAW 原文件与风格化 JPEG 均已保存。"
                }
                Task { await PhotoSaver.saveJPEG(url: styledURL) }
            }
        } catch {
            errorMessage = "ProRAW 处理失败：\(error.localizedDescription)"
        }
    }
    fileprivate func handleLivePhoto(
        stillData: Data,
        movieURL: URL,
        preset: CameraPreset,
        watermark: Bool,
        metadata: MetadataDraft
    ) {
        let stillURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GCamStyle-Live-\(UUID().uuidString).jpg")

        do {
            try stillData.write(to: stillURL, options: .atomic)
            Task {
                await PhotoSaver.saveLivePhoto(stillURL: stillURL, movieURL: movieURL)
            }
        } catch {
            errorMessage = "Live Photo 保存失败：\(error.localizedDescription)"
        }

        // Also create the user's stylized still copy. The original Live Photo pair stays intact.
        if let styledURL = try? ExportService.renderToJPEG(
            sourceData: stillData,
            preset: preset,
            watermark: watermark,
            metadata: metadata
        ),
        let styledData = try? Data(contentsOf: styledURL),
        let image = UIImage(data: styledData) {
            lastImage = image
            lastSavedURL = styledURL
            Task { await PhotoSaver.saveJPEG(url: styledURL) }
        }
    }
}

// MARK: - Capture delegate

final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    weak var owner: CameraEngine?
    let settingsID: Int64
    let preset: CameraPreset
    let mode: CaptureMode
    let watermark: Bool
    let metadata: MetadataDraft

    private var processedData: Data?
    private var rawData: Data?
    private var liveMovieURL: URL?

    init(
        owner: CameraEngine,
        settingsID: Int64,
        preset: CameraPreset,
        mode: CaptureMode,
        watermark: Bool,
        metadata: MetadataDraft
    ) {
        self.owner = owner
        self.settingsID = settingsID
        self.preset = preset
        self.mode = mode
        self.watermark = watermark
        self.metadata = metadata
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil else { return }
        processedData = photo.fileDataRepresentation()
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingRawPhoto rawPhoto: AVCapturePhoto,
        withError error: Error?
    ) {
        guard error == nil else { return }
        rawData = rawPhoto.fileDataRepresentation()
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
        duration: CMTime,
        photoDisplayTime: CMTime,
        resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        guard error == nil else { return }
        liveMovieURL = outputFileURL
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        DispatchQueue.main.async {
            guard let owner = self.owner else { return }

            if let processedData = self.processedData {
                if self.mode == .livePhoto, let movieURL = self.liveMovieURL {
                    owner.handleLivePhoto(
                        stillData: processedData,
                        movieURL: movieURL,
                        preset: self.preset,
                        watermark: self.watermark,
                        metadata: self.metadata
                    )
                } else {
                    owner.handleProcessedPhoto(
                        data: processedData,
                        preset: self.preset,
                        mode: self.mode,
                        watermark: self.watermark,
                        metadata: self.metadata
                    )
                }
            }

            if let rawData = self.rawData {
                owner.handleRawPhoto(data: rawData, preset: self.preset)
            }

            owner.finishCapture(id: self.settingsID)
        }
    }
}

// MARK: - Live preview

final class LivePreviewView: MTKView, AVCaptureVideoDataOutputSampleBufferDelegate {
    var activePreset: CameraPreset = PresetLibrary.all[0]

    private let commandQueue: MTLCommandQueue
    private let ciContext: CIContext
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    init(frame: CGRect = .zero) {
        let device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()!
        ciContext = CIContext(mtlDevice: device)

        super.init(frame: frame, device: device)

        framebufferOnly = false
        enableSetNeedsDisplay = false
        isPaused = true
        isOpaque = true
        autoResizeDrawable = true
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let source = CIImage(cvPixelBuffer: imageBuffer)
        let styled = PhotoProcessor.applyLook(source, preset: activePreset)

        DispatchQueue.main.async { [weak self] in
            self?.render(image: styled)
        }
    }

    private func render(image: CIImage) {
        guard let drawable = currentDrawable else { return }

        let oriented = image.oriented(.right)
        let target = CGSize(width: drawableSize.width, height: drawableSize.height)
        let extent = oriented.extent

        let scale = max(target.width / extent.width, target.height / extent.height)
        var fitted = oriented.transformed(
            by: CGAffineTransform(scaleX: scale, y: scale)
        )

        let dx = (target.width - fitted.extent.width) * 0.5 - fitted.extent.minX
        let dy = (target.height - fitted.extent.height) * 0.5 - fitted.extent.minY
        fitted = fitted.transformed(
            by: CGAffineTransform(translationX: dx, y: dy)
        )

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        ciContext.render(
            fitted,
            to: drawable.texture,
            commandBuffer: commandBuffer,
            bounds: CGRect(origin: .zero, size: target),
            colorSpace: colorSpace
        )
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

struct LiveCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let output: AVCaptureVideoDataOutput
    let preset: CameraPreset

    func makeUIView(context: Context) -> LivePreviewView {
        let view = LivePreviewView()
        view.activePreset = preset
        output.setSampleBufferDelegate(view, queue: DispatchQueue(label: "GCamStyle.preview"))
        if let connection = output.connection(with: .video) {
            connection.videoRotationAngle = 90
        }
        return view
    }

    func updateUIView(_ uiView: LivePreviewView, context: Context) {
        uiView.activePreset = preset
    }
}

// MARK: - Image processing

enum PhotoProcessor {
    static func applyLook(_ input: CIImage, preset: CameraPreset) -> CIImage {
        var current = input

        let exposure = CIFilter.exposureAdjust()
        exposure.inputImage = current
        exposure.ev = preset.exposure
        current = exposure.outputImage ?? current

        let controls = CIFilter.colorControls()
        controls.inputImage = current
        controls.saturation = preset.saturation
        controls.contrast = preset.contrast
        controls.brightness = 0
        current = controls.outputImage ?? current

        let highlightShadow = CIFilter.highlightShadowAdjust()
        highlightShadow.inputImage = current
        highlightShadow.highlightAmount = preset.highlights
        highlightShadow.shadowAmount = preset.shadows
        current = highlightShadow.outputImage ?? current

        let tint = CIFilter.temperatureAndTint()
        tint.inputImage = current
        tint.neutral = CIVector(x: 6500, y: 0)
        tint.targetNeutral = CIVector(x: CGFloat(6500 + preset.warmth * 90), y: CGFloat(preset.tint * 8))
        current = tint.outputImage ?? current

        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = current
        let bias = preset.channelBias * 0.004
        matrix.rVector = CIVector(x: 1, y: CGFloat(bias), z: 0, w: 0)
        matrix.gVector = CIVector(x: 0, y: 1, z: CGFloat(-bias), w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: 1, w: 0)
        matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        current = matrix.outputImage ?? current

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = current
        sharpen.sharpness = preset.sharpness
        current = sharpen.outputImage ?? current

        return current
    }
}

// MARK: - Export / metadata

enum ExportService {
    static func renderToJPEG(
        sourceData: Data,
        preset: CameraPreset,
        watermark: Bool,
        metadata: MetadataDraft
    ) throws -> URL {
        guard
            let source = CGImageSourceCreateWithData(sourceData as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw NSError(domain: "GCamStyle", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "无法读取照片"
            ])
        }

        let input = CIImage(cgImage: image)
        let styled = PhotoProcessor.applyLook(input, preset: preset)
        let context = CIContext()
        guard let styledCG = context.createCGImage(styled, from: styled.extent) else {
            throw NSError(domain: "GCamStyle", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "风格渲染失败"
            ])
        }

        let sourceProperties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]) ?? [:]
        return try writeRenderedJPEG(
            cgImage: styledCG,
            preset: preset,
            metadata: metadata,
            watermark: watermark,
            sourceProperties: sourceProperties
        )
    }

    static func writeRenderedJPEG(
        cgImage: CGImage,
        preset: CameraPreset,
        metadata: MetadataDraft,
        watermark: Bool,
        sourceProperties: [String: Any]
    ) throws -> URL {
        let finalImage = watermark
            ? WatermarkRenderer.draw(on: cgImage, preset: preset).cgImage!
            : cgImage

        var properties = sourceProperties
        var tiff = (properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]) ?? [:]
        tiff[kCGImagePropertyTIFFMake as String] = metadata.make.isEmpty ? preset.exifMake : metadata.make
        tiff[kCGImagePropertyTIFFModel as String] = metadata.model.isEmpty ? preset.exifModel : metadata.model
        if !metadata.artist.isEmpty { tiff[kCGImagePropertyTIFFArtist as String] = metadata.artist }
        if !metadata.copyright.isEmpty { tiff[kCGImagePropertyTIFFCopyright as String] = metadata.copyright }
        tiff[kCGImagePropertyTIFFSoftware as String] = metadata.software
        properties[kCGImagePropertyTIFFDictionary as String] = tiff

        var exif = (properties[kCGImagePropertyExifDictionary as String] as? [String: Any]) ?? [:]
        if !metadata.lens.isEmpty { exif[kCGImagePropertyExifLensModel as String] = metadata.lens }
        exif[kCGImagePropertyExifFocalLength as String] = Double(preset.focal.replacingOccurrences(of: "mm", with: "")) ?? 28
        exif[kCGImagePropertyExifFNumber as String] = Double(preset.aperture.replacingOccurrences(of: "F", with: "")) ?? 1.8
        exif[kCGImagePropertyExifISOSpeedRatings as String] = [Int(preset.iso.replacingOccurrences(of: "ISO ", with: "")) ?? 100]
        if !metadata.dateOriginal.isEmpty { exif[kCGImagePropertyExifDateTimeOriginal as String] = metadata.dateOriginal }
        properties[kCGImagePropertyExifDictionary as String] = exif

        if metadata.stripGPS {
            properties.removeValue(forKey: kCGImagePropertyGPSDictionary as String)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GCamStyle-\(UUID().uuidString).jpg")

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "GCamStyle", code: 3, userInfo: [NSLocalizedDescriptionKey: "无法创建 JPEG"])
        }

        CGImageDestinationAddImage(destination, finalImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "GCamStyle", code: 4, userInfo: [NSLocalizedDescriptionKey: "JPEG 导出失败"])
        }

        return url
    }
}

// MARK: - Watermarks

enum WatermarkRenderer {
    static func draw(on cgImage: CGImage, preset: CameraPreset) -> UIImage {
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            UIImage(cgImage: cgImage).draw(in: rect)

            let bandHeight = max(110, size.height * 0.095)
            let band = CGRect(
                x: 0,
                y: size.height - bandHeight,
                width: size.width,
                height: bandHeight
            )

            UIColor.black.withAlphaComponent(0.74).setFill()
            context.fill(band)

            let accent = preset.watermarkAccent.uiColor
            accent.setFill()

            switch preset.style {
            case "Cinematic":
                context.fill(CGRect(x: 0, y: band.minY, width: 9, height: band.height))
            case "Portrait":
                context.fill(CGRect(x: 0, y: band.minY, width: band.width, height: 4))
            case "Street":
                context.fill(CGRect(x: band.width - 9, y: band.minY, width: 9, height: band.height))
            default:
                context.fill(CGRect(x: 0, y: band.minY, width: band.width, height: 2))
            }

            let x = max(28, size.width * 0.028)
            let headerY = band.minY + band.height * 0.18
            let footerY = band.minY + band.height * 0.58

            let headerFont = UIFont.systemFont(
                ofSize: max(22, size.width / 58),
                weight: .bold
            )
            let footerFont = UIFont.monospacedSystemFont(
                ofSize: max(13, size.width / 96),
                weight: .medium
            )

            let header = "\(preset.brand)  \(preset.model)"
            let footer = "\(preset.lens)   \(preset.focal)   \(preset.aperture)   \(preset.shutter)   \(preset.iso)"

            (header as NSString).draw(
                at: CGPoint(x: x, y: headerY),
                withAttributes: [
                    .font: headerFont,
                    .foregroundColor: UIColor.white
                ]
            )
            (footer as NSString).draw(
                at: CGPoint(x: x, y: footerY),
                withAttributes: [
                    .font: footerFont,
                    .foregroundColor: UIColor.white.withAlphaComponent(0.86)
                ]
            )
        }
    }
}

// MARK: - Photos

enum PhotoSaver {
    static func requestAddPermission() async -> Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited:
            return true
        case .notDetermined:
            return await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized
        default:
            return false
        }
    }

    static func saveJPEG(url: URL) async {
        guard await requestAddPermission() else { return }
        try? await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: url, options: nil)
        }
    }

    static func saveRAW(url: URL) async {
        guard await requestAddPermission() else { return }
        try? await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: url, options: nil)
        }
    }

    static func saveLivePhoto(stillURL: URL, movieURL: URL) async {
        guard await requestAddPermission() else { return }
        try? await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: stillURL, options: nil)
            request.addResource(with: .pairedVideo, fileURL: movieURL, options: nil)
        }
    }
}

// MARK: - UI

struct ContentView: View {
    @EnvironmentObject private var camera: CameraEngine

    @State private var preset = PresetLibrary.all[0]
    @State private var captureMode: CaptureMode = .photo
    @State private var watermark = true
    @State private var showPresetPicker = false
    @State private var showMetadata = false
    @State private var metadata = MetadataDraft()
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LiveCameraPreview(
                session: camera.session,
                output: camera.videoOutput,
                preset: preset
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.50),
                    Color.clear,
                    Color.black.opacity(0.75)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomBar
            }

            if camera.isCapturing {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.3)
            }

            if let image = camera.lastImage {
                previewOverlay(image)
            }
        }
        .sheet(isPresented: $showPresetPicker) {
            presetPicker
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showMetadata) {
            metadataSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else { return }
                    camera.processImportedPhoto(
                        data: data,
                        preset: preset,
                        watermark: watermark,
                        metadata: metadata
                    )
                } catch {
                    camera.errorMessage = "无法读取照片：\(error.localizedDescription)"
                }
            }
        }
        .alert(
            "GCamStyle",
            isPresented: Binding(
                get: { camera.errorMessage != nil },
                set: { if !$0 { camera.errorMessage = nil } }
            )
        ) {
            Button("好") { camera.errorMessage = nil }
        } message: {
            Text(camera.errorMessage ?? "")
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("GCAM STYLE")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(1.3)
                Text("\(preset.brand) · \(preset.model)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            Button {
                showPresetPicker = true
            } label: {
                HStack(spacing: 5) {
                    Text(preset.brand)
                    Image(systemName: "chevron.down")
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.12)))
            }

            Button {
                showMetadata = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.12)))
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 10)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            modePicker

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(PresetLibrary.brands.prefix(14)), id: \.self) { brand in
                        Button {
                            if let item = PresetLibrary.all.first(where: { $0.brand == brand }) {
                                preset = item
                            }
                        } label: {
                            Text(brand)
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(
                                    preset.brand == brand ? Color.white : Color.black.opacity(0.33),
                                    in: Capsule()
                                )
                                .foregroundStyle(
                                    preset.brand == brand ? Color.black : Color.white
                                )
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            HStack {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 19, weight: .semibold))
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.12)))
                }

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    camera.capture(
                        preset: preset,
                        mode: captureMode,
                        watermark: watermark,
                        metadata: metadata
                    )
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.20))
                            .frame(width: 84, height: 84)
                        Circle()
                            .fill(.white)
                            .frame(width: 68, height: 68)
                    }
                }
                .disabled(!camera.ready || camera.isCapturing)

                Spacer()

                Button {
                    watermark.toggle()
                } label: {
                    Image(systemName: watermark ? "text.viewfinder" : "text.viewfinder.badge.magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.12)))
                }
            }
            .padding(.horizontal, 18)

            HStack(spacing: 7) {
                Image(systemName: captureMode == .proRAW ? "camera.aperture" : "camera")
                    .font(.system(size: 10, weight: .bold))
                Text(captureMode == .proRAW ? "RAW 保持原始 + 风格 JPEG" : "实时风格 · 自动水印")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))

                Spacer()

                Text("\(preset.focal) · \(preset.aperture)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.70))
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .padding(.top, 6)
        .background(.black.opacity(0.22))
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(CaptureMode.allCases) { mode in
                Button {
                    if mode == .proRAW && !camera.proRAWSupported { return }
                    if mode == .livePhoto && !camera.livePhotoSupported { return }
                    captureMode = mode
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(captureMode == mode ? Color.black : Color.white.opacity(0.55))
                            .frame(width: 5, height: 5)
                        Text(mode.rawValue)
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(
                        captureMode == mode ? Color.white : Color.black.opacity(0.30),
                        in: Capsule()
                    )
                    .foregroundStyle(captureMode == mode ? Color.black : Color.white)
                }
                .opacity(
                    mode == .proRAW && !camera.proRAWSupported ||
                    mode == .livePhoto && !camera.livePhotoSupported ? 0.42 : 1
                )
            }
        }
        .padding(.horizontal, 12)
    }

    private func previewOverlay(_ image: UIImage) -> some View {
        ZStack {
            Color.black.opacity(0.84).ignoresSafeArea()

            VStack(spacing: 14) {
                HStack {
                    Text("已生成")
                        .font(.headline)
                    Spacer()
                    Button("关闭") {
                        camera.clearPreview()
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal)

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 10)

                HStack(spacing: 10) {
                    Button("继续拍摄") {
                        camera.clearPreview()
                    }
                    .buttonStyle(.borderedProminent)

                    if let url = camera.lastSavedURL {
                        ShareLink(item: url) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.top, 14)
        }
    }

    private var presetPicker: some View {
        NavigationStack {
            List {
                Section("品牌") {
                    ForEach(PresetLibrary.brands, id: \.self) { brand in
                        Text(brand)
                            .font(.system(size: 13, weight: .bold))
                            .listRowBackground(
                                preset.brand == brand ? Color.white.opacity(0.08) : Color.clear
                            )
                    }
                }

                Section("全部 128 个风格预设") {
                    ForEach(PresetLibrary.all) { item in
                        Button {
                            preset = item
                            showPresetPicker = false
                        } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color(item.watermarkAccent.uiColor))
                                    .frame(width: 7, height: 34)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(item.brand) \(item.model)")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("\(item.style) · \(item.lens)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if item.id == preset.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("相机 / 水印预设")
        }
    }

    private var metadataSheet: some View {
        NavigationStack {
            Form {
                Section("EXIF 机型") {
                    TextField("Make（厂商）", text: $metadata.make)
                    TextField("Model（机型）", text: $metadata.model)
                    TextField("Lens（镜头）", text: $metadata.lens)
                    TextField("Artist", text: $metadata.artist)
                    TextField("Copyright", text: $metadata.copyright)
                    TextField("DateTimeOriginal", text: $metadata.dateOriginal)
                    Toggle("移除 GPS", isOn: $metadata.stripGPS)
                }

                Section("快速写入当前预设") {
                    Button("使用 \(preset.brand) \(preset.model)") {
                        metadata.make = preset.exifMake
                        metadata.model = preset.exifModel
                        metadata.lens = preset.lens
                    }
                }

                Section("说明") {
                    Text("导出的 JPEG 会保留原照片可读取的元数据，并覆盖 Make / Model / 镜头 / 焦段 / 光圈 / ISO 等项目。ProRAW 原文件不修改，避免破坏原始 RAW 数据。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("EXIF 编辑")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { showMetadata = false }
                }
            }
        }
    }
}

@main
struct GCamStyleApp: App {
    @StateObject private var camera = CameraEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(camera)
                .preferredColorScheme(.dark)
        }
    }
}
