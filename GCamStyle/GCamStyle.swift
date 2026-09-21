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
    case photo = "photo"
    case proRAW = "proRAW"
    case livePhoto = "livePhoto"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .photo: return "照片"
        case .proRAW: return "原始"
        case .livePhoto: return "实况照片"
        }
    }
}

struct MetadataDraft: Hashable {
    // Empty values mean "use the selected preset" during export.
    var make = ""
    var model = ""
    var lens = ""
    var artist = ""
    var copyright = ""
    var software = "风格相机"
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

private extension CameraPreset {
    var chineseBrand: String {
        switch brand.uppercased() {
        case "LEICA": return "徕卡"
        case "HASSELBLAD": return "哈苏"
        case "ZEISS": return "蔡司"
        case "VIVO": return "维沃"
        case "XIAOMI": return "小米"
        case "HUAWEI": return "华为"
        case "OPPO": return "欧珀"
        case "GOOGLE": return "谷歌"
        case "APPLE": return "苹果"
        case "SONY": return "索尼"
        case "CANON": return "佳能"
        case "NIKON": return "尼康"
        case "FUJIFILM": return "富士胶片"
        case "RICOH": return "理光"
        case "PANASONIC": return "松下"
        case "SIGMA": return "适马"
        default: return brand
        }
    }

    var chineseStyle: String {
        switch style.lowercased() {
        case "natural": return "自然"
        case "cinematic": return "电影"
        case "portrait": return "人像"
        case "street": return "街拍"
        default: return style
        }
    }

    var chineseModel: String {
        let mappings = [
            "X200 Ultra": "X200 至尊版",
            "X200 Pro": "X200 专业版",
            "X100 Ultra": "X100 至尊版",
            "15 Ultra": "15 至尊版",
            "14 Ultra": "14 至尊版",
            "Pura 70 Ultra": "Pura 70 至尊版",
            "Mate 70 Pro": "Mate 70 专业版",
            "Find X8 Ultra": "Find X8 至尊版",
            "Find X7 Ultra": "Find X7 至尊版",
            "Pixel 10 Pro": "Pixel 10 专业版",
            "Pixel 9 Pro": "Pixel 9 专业版",
            "iPhone 17 Pro Max": "iPhone 17 专业 Max",
            "iPhone 17 Pro": "iPhone 17 专业版",
            "iPhone 16 Pro": "iPhone 16 专业版",
            "EOS R5 Mark II": "EOS R5 Mark II",
            "EOS R6 Mark II": "EOS R6 Mark II",
            "X2D 100C": "X2D 100C",
            "X100VI": "X100VI",
            "GR IIIx": "GR IIIx",
            "S1RII": "S1RII",
            "fp L": "fp L"
        ]
        return mappings[model] ?? model
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
            // Custom Metal preview rotates the CIImage itself. Do not rotate
            // the VideoDataOutput connection as that would apply another
            // hardware rotation and caused the portrait preview to appear sideways.
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
                errorMessage = "当前设备或相机配置不支持苹果原始格式。"
                return
            }

            guard let rawType = photoOutput.availableRawPhotoPixelFormatTypes.first(
                where: { AVCapturePhotoOutput.isAppleProRAWPixelFormat($0) }
            ) else {
                isCapturing = false
                errorMessage = "当前没有可用的原始照片格式。"
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
                errorMessage = "当前设备不支持实况照片。"
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
                errorMessage = "原始照片与风格照片均已保存。原始文件未修改。"
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
                software: "风格相机原始照片",
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
                    self.errorMessage = "原始照片与风格照片均已保存。"
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
            errorMessage = "实况照片保存失败：\(error.localizedDescription)"
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
    private let frameLock = NSLock()
    private var latestImage: CIImage?
    private var lastSubmitTime: CFTimeInterval = 0
    private var drawPending = false
    private let maxPreviewDimension: CGFloat = 1280

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

        let now = CACurrentMediaTime()
        guard now - lastSubmitTime >= (1.0 / 18.0) else { return }
        lastSubmitTime = now

        var source = CIImage(cvPixelBuffer: imageBuffer).oriented(.right)
        let maxDimension = max(source.extent.width, source.extent.height)
        if maxDimension > maxPreviewDimension {
            let scale = maxPreviewDimension / maxDimension
            source = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }

        // Live preview intentionally uses a much lighter pipeline than final export.
        let styled = PhotoProcessor.applyPreviewLook(source, preset: activePreset)

        frameLock.lock()
        latestImage = styled
        frameLock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.drawPending { return }
            self.drawPending = true
            self.drawPending = false
            self.draw()
        }
    }

    override func draw(_ rect: CGRect) {
        frameLock.lock()
        let image = latestImage
        frameLock.unlock()
        guard let image else { return }
        render(image: image)
    }

    private func render(image: CIImage) {
        guard let drawable = currentDrawable else { return }

        let target = CGSize(width: drawableSize.width, height: drawableSize.height)
        let extent = image.extent

        let scale = max(target.width / extent.width, target.height / extent.height)
        var fitted = image.transformed(
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
        output.setSampleBufferDelegate(view, queue: DispatchQueue(label: "风格相机预览"))
        return view
    }

    func updateUIView(_ uiView: LivePreviewView, context: Context) {
        uiView.activePreset = preset
    }
}

// MARK: - Image processing

enum PhotoProcessor {
    static func applyPreviewLook(_ input: CIImage, preset: CameraPreset) -> CIImage {
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
        return highlightShadow.outputImage ?? current
    }

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
            throw NSError(domain: "风格相机", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "无法读取照片"
            ])
        }

        let input = CIImage(cgImage: image)
        let styled = PhotoProcessor.applyLook(input, preset: preset)
        let context = CIContext()
        guard let styledCG = context.createCGImage(styled, from: styled.extent) else {
            throw NSError(domain: "提示", code: 2, userInfo: [
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
            throw NSError(domain: "提示", code: 3, userInfo: [NSLocalizedDescriptionKey: "无法创建 JPEG"])
        }

        CGImageDestinationAddImage(destination, finalImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "提示", code: 4, userInfo: [NSLocalizedDescriptionKey: "JPEG 导出失败"])
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
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))

            switch preset.brand.uppercased() {
            case "LEICA":
                drawLeica(context, size, preset)
            case "HASSELBLAD":
                drawHasselblad(context, size, preset)
            case "ZEISS":
                drawZeiss(context, size, preset)
            case "VIVO":
                drawVivo(context, size, preset)
            case "XIAOMI":
                drawXiaomi(context, size, preset)
            case "HUAWEI":
                drawHuawei(context, size, preset)
            case "OPPO":
                drawOppo(context, size, preset)
            case "GOOGLE":
                drawGoogle(context, size, preset)
            case "APPLE":
                drawApple(context, size, preset)
            case "SONY":
                drawSony(context, size, preset)
            case "CANON":
                drawCanon(context, size, preset)
            case "NIKON":
                drawNikon(context, size, preset)
            case "FUJIFILM":
                drawFujifilm(context, size, preset)
            case "RICOH":
                drawRicoh(context, size, preset)
            default:
                drawGeneric(context, size, preset)
            }
        }
    }

    private static func info(_ preset: CameraPreset) -> String {
        "\(preset.focal)  ·  \(preset.aperture)  ·  (preset.shutter)  ·  (preset.iso)"
    }

    private static func fonts(_ size: CGSize) -> (UIFont, UIFont) {
        (
            UIFont.systemFont(ofSize: max(24, size.width / 58), weight: .bold),
            UIFont.monospacedSystemFont(ofSize: max(13, size.width / 100), weight: .medium)
        )
    }

    private static func drawLeica(_ context: UIGraphicsImageRendererContext, _ size: CGSize, _ p: CameraPreset) {
        let band = CGRect(x: 0, y: 0, width: max(102, size.width * 0.105), height: size.height)
        UIColor.black.withAlphaComponent(0.78).setFill()
        context.fill(band)
        UIColor(red: 0.86, green: 0.08, blue: 0.08, alpha: 1).setFill()
        context.fill(CGRect(x: band.width - 6, y: 0, width: 6, height: band.height))

        context.cgContext.saveGState()
        context.cgContext.translateBy(x: band.width * 0.50, y: size.height - 34)
        context.cgContext.rotate(by: -.pi / 2)
        let (hf, sf) = fonts(size)
        ("\(p.exifMake)  \(p.exifModel)" as NSString).draw(
            at: CGPoint(x: 0, y: -hf.lineHeight),
            withAttributes: [.font: hf, .foregroundColor: UIColor.white]
        )
        (p.lens as NSString).draw(
            at: CGPoint(x: 0, y: 8),
            withAttributes: [.font: sf, .foregroundColor: UIColor.white.withAlphaComponent(0.86)]
        )
        (info(p) as NSString).draw(
            at: CGPoint(x: 0, y: 30),
            withAttributes: [.font: sf, .foregroundColor: UIColor.white.withAlphaComponent(0.72)]
        )
        context.cgContext.restoreGState()
    }

    private static func drawHasselblad(_ context: UIGraphicsImageRendererContext, _ size: CGSize, _ p: CameraPreset) {
        let h = max(132, size.height * 0.11)
        let band = CGRect(x: 0, y: size.height - h, width: size.width, height: h)
        UIColor.black.withAlphaComponent(0.58).setFill()
        context.fill(band)
        let accent = UIColor(red: 0.96, green: 0.55, blue: 0.08, alpha: 1)
        accent.setFill()
        context.fill(CGRect(x: 0, y: band.minY, width: 150, height: 7))
        let (hf, sf) = fonts(size)
        let x = 42.0
        ("\(p.exifMake)  \(p.exifModel)" as NSString).draw(at: CGPoint(x:x, y:band.minY+23),
            withAttributes:[.font:hf,.foregroundColor:UIColor.white])
        ("中画幅  ·  \(p.lens)  ·  \(info(p))" as NSString).draw(at: CGPoint(x:x, y:band.minY+70),
            withAttributes:[.font:sf,.foregroundColor:UIColor.white.withAlphaComponent(0.84)])
        let square = CGRect(x: size.width - 72, y: band.minY + 28, width: 38, height: 38)
        accent.setFill()
        context.fill(square)
    }

    private static func drawZeiss(_ context: UIGraphicsImageRendererContext, _ size: CGSize, _ p: CameraPreset) {
        let w = min(size.width * 0.78, 980)
        let h = 96.0
        let rect = CGRect(x: (size.width-w)/2, y: size.height-h-30, width:w, height:h)
        UIColor.black.withAlphaComponent(0.68).setFill()
        context.cgContext.fillEllipse(in: rect.insetBy(dx: 0, dy: 0))
        UIColor(red: 0.18, green: 0.55, blue: 0.92, alpha: 1).setFill()
        context.fill(CGRect(x: rect.minX + 28, y: rect.minY + 10, width: rect.width - 56, height: 4))
        let (hf,sf)=fonts(size)
        ("\(p.exifMake)  \(p.exifModel)" as NSString).draw(at: CGPoint(x:rect.minX+34,y:rect.minY+23),
            withAttributes:[.font:hf,.foregroundColor:UIColor.white])
        ("自然色彩  ·  \(p.lens)  ·  \(info(p))" as NSString).draw(at: CGPoint(x:rect.minX+36,y:rect.minY+65),
            withAttributes:[.font:sf,.foregroundColor:UIColor.white.withAlphaComponent(0.84)])
    }

    private static func drawVivo(_ context: UIGraphicsImageRendererContext, _ size: CGSize, _ p: CameraPreset) {
        let w = min(size.width * 0.72, 900)
        let h = 116.0
        let rect = CGRect(x: size.width - w - 28, y: size.height - h - 34, width:w, height:h)
        UIColor.black.withAlphaComponent(0.64).setFill()
        context.cgContext.fill(rect)
        UIColor(red:0.18,green:0.55,blue:0.92,alpha:1).setFill()
        context.fill(CGRect(x:rect.minX, y:rect.minY, width:8, height:rect.height))
        let (hf,sf)=fonts(size)
        ("vivo  ·  \(p.exifModel)" as NSString).draw(at: CGPoint(x:rect.minX+28,y:rect.minY+22),
            withAttributes:[.font:hf,.foregroundColor:UIColor.white])
        ("蔡司联合影像  ·  \(p.lens)" as NSString).draw(at: CGPoint(x:rect.minX+30,y:rect.minY+66),
            withAttributes:[.font:sf,.foregroundColor:UIColor.white.withAlphaComponent(0.88)])
        ("\(info(p))" as NSString).draw(at: CGPoint(x:rect.minX+30,y:rect.minY+89),
            withAttributes:[.font:sf,.foregroundColor:UIColor.white.withAlphaComponent(0.72)])
    }

    private static func drawXiaomi(_ context: UIGraphicsImageRendererContext, _ size: CGSize, _ p: CameraPreset) {
        let w = min(size.width * 0.70, 920)
        let h = 124.0
        let rect = CGRect(x: 26, y: size.height-h-30, width:w, height:h)
        UIColor.black.withAlphaComponent(0.67).setFill()
        context.fill(rect)
        UIColor(red:0.95,green:0.35,blue:0.08,alpha:1).setFill()
        context.fill(CGRect(x:rect.minX, y:rect.minY, width:12, height:rect.height))
        let (hf,sf)=fonts(size)
        ("小米  \(p.exifModel)" as NSString).draw(at: CGPoint(x:rect.minX+30,y:rect.minY+20),
            withAttributes:[.font:hf,.foregroundColor:UIColor.white])
        let look = p.style == "Portrait" ? "人像" : "自然"
        ("徕卡影像  ·  \(look)" as NSString).draw(at: CGPoint(x:rect.minX+32,y:rect.minY+64),
            withAttributes:[.font:sf,.foregroundColor:UIColor.white.withAlphaComponent(0.88)])
        ("\(info(p))" as NSString).draw(at: CGPoint(x:rect.minX+32,y:rect.minY+91),
            withAttributes:[.font:sf,.foregroundColor:UIColor.white.withAlphaComponent(0.72)])
    }

    private static func drawHuawei(_ context: UIGraphicsImageRendererContext, _ size: CGSize, _ p: CameraPreset) {
        let h = 106.0
        let rect = CGRect(x: size.width - 470, y: 30, width: 440, height: h)
        UIColor.black.withAlphaComponent(0.48).setFill()
        context.fill(rect)
        UIColor(red:0.88,green:0.08,blue:0.12,alpha:1).setFill()
        context.fill(CGRect(x:rect.minX, y:rect.minY, width:5, height:rect.height))
        let (_,sf)=fonts(size)
        let hf=UIFont.systemFont(ofSize:max(26,size.width/62),weight:.bold)
        ("华为  \(p.exifModel)" as NSString).draw(at: CGPoint(x:rect.minX+24,y:rect.minY+19),
            withAttributes:[.font:hf,.foregroundColor:UIColor.white])
        ("影像风格  ·  \(p.lens)" as NSString).draw(at: CGPoint(x:rect.minX+26,y:rect.minY+59),
            withAttributes:[.font:sf,.foregroundColor:UIColor.white.withAlphaComponent(0.86)])
    }

    private static func drawOppo(_ context: UIGraphicsImageRendererContext, _ size: CGSize, _ p: CameraPreset) {
        let h = 74.0
        UIColor.black.withAlphaComponent(0.52).setFill()
        context.fill(CGRect(x:0,y:size.height-h,width:size.width,height:h))
        UIColor(red:0.35,green:0.80,blue:0.45,alpha:1).setFill()
        context.fill(CGRect(x:0,y:size.height-h,width:size.width,height:3))
        let (_,sf)=fonts(size)
        let text="欧珀  \(p.exifModel)  ·  哈苏人像  ·  \(info(p))"
        (text as NSString).draw(at: CGPoint(x:34,y:size.height-h+27),
            withAttributes:[.font:sf,.foregroundColor:UIColor.white.withAlphaComponent(0.9)])
    }

    private static func drawGoogle(_ context: UIGraphicsImageRendererContext, _ size: CGSize, _ p: CameraPreset) {
        let w = min(640, size.width*0.48)
        let h = 90.0
        let rect = CGRect(x:size.width-w-24,y:size.height-h-28,width:w,height:h)
        UIColor.white.withAlphaComponent(0.88).setFill()
        context.fill(rect)
        let (_,sf)=fonts(size)
        let hf=UIFont.systemFont(ofSize:max(23,size.width/70),weight:.bold)
        ("谷歌  \(p.exifModel)" as NSString).draw(at:CGPoint(x:rect.minX+22,y:rect.minY+15),
            withAttributes:[.font:hf,.foregroundColor:UIColor.black])
        ("计算摄影  ·  \(info(p))" as NSString).draw(at:CGPoint(x:rect.minX+24,y:rect.minY+53),
            withAttributes:[.font:sf,.foregroundColor:UIColor.black.withAlphaComponent(0.72)])
    }

    private static func drawApple(_ context: UIGraphicsImageRendererContext, _ size: CGSize, _ p: CameraPreset) {
        let (_,sf)=fonts(size)
        let text="苹果  \(p.exifModel)  ·  \(info(p))"
        let attrs:[NSAttributedString.Key:Any]=[.font:sf,.foregroundColor:UIColor.white]
        let measured=(text as NSString).size(withAttributes:attrs)
        let rect=CGRect(x:(size.width-measured.width)/2-22,y:size.height-64,width:measured.width+44,height:38)
        UIColor.black.withAlphaComponent(0.46).setFill()
        context.fill(rect)
        (text as NSString).draw(at:CGPoint(x:rect.minX+22,y:rect.minY+10),withAttributes:attrs)
    }

    private static func drawSony(_ context: UIGraphicsImageRendererContext, _ size: CGSize, _ p: CameraPreset) {
        let band=CGRect(x:0,y:0,width:max(110,size.width*0.09),height:size.height)
        UIColor.black.withAlphaComponent(0.72).setFill()
        context.fill(band)
        let (_,sf)=fonts(size)
        context.cgContext.saveGState()
        context.cgContext.translateBy(x:band.width*0.5,y:size.height-28)
        context.cgContext.rotate(by:-.pi/2)
        let hf=UIFont.systemFont(ofSize:max(24,size.width/66),weight:.bold)
        ("索尼  \(p.exifModel)" as NSString).draw(at:CGPoint(x:0,y:-hf.lineHeight),withAttributes:[.font:hf,.foregroundColor:UIColor.white])
        ("\(p.lens)  ·  \(info(p))" as NSString).draw(at:CGPoint(x:0,y:10),withAttributes:[.font:sf,.foregroundColor:UIColor.white.withAlphaComponent(0.8)])
        context.cgContext.restoreGState()
    }

    private static func drawCanon(_ context: UIGraphicsImageRendererContext, _ size: CGSize, _ p: CameraPreset) {
        let w=min(600,size.width*0.45), h=96.0
        let rect=CGRect(x:size.width-w-28,y:size.height-h-28,width:w,height:h)
        UIColor.white.withAlphaComponent(0.90).setFill()
        context.fill(rect)
        UIColor(red:0.75,green:0.10,blue:0.08,alpha:1).setFill()
        context.fill(CGRect(x:rect.minX,y:rect.minY,width:10,height:rect.height))
        let (_,sf)=fonts(size)
        let hf=UIFont.systemFont(ofSize:max(22,size.width/70),weight:.bold)
        ("佳能  \(p.exifModel)" as NSString).draw(at:CGPoint(x:rect.minX+26,y:rect.minY+15),withAttributes:[.font:hf,.foregroundColor:UIColor.black])
        ("\(p.lens)  ·  \(info(p))" as NSString).draw(at:CGPoint(x:rect.minX+28,y:rect.minY+55),withAttributes:[.font:sf,.foregroundColor:UIColor.black.withAlphaComponent(0.72)])
    }

    private static func drawNikon(_ context: UIGraphicsImageRendererContext, _ size: CGSize, _ p: CameraPreset) {
        let rect=CGRect(x:30,y:30,width:min(650,size.width*0.46),height:82)
        UIColor.black.withAlphaComponent(0.46).setFill()
        context.fill(rect)
        UIColor(red:0.95,green:0.78,blue:0.08,alpha:1).setFill()
        context.fill(CGRect(x:rect.minX,y:rect.maxY-5,width:rect.width,height:5))
        let (_,sf)=fonts(size)
        let hf=UIFont.systemFont(ofSize:max(23,size.width/70),weight:.bold)
        ("尼康  \(p.exifModel)" as NSString).draw(at:CGPoint(x:rect.minX+18,y:rect.minY+13),withAttributes:[.font:hf,.foregroundColor:UIColor.white])
        ("\(p.lens)  ·  \(info(p))" as NSString).draw(at:CGPoint(x:rect.minX+20,y:rect.minY+49),withAttributes:[.font:sf,.foregroundColor:UIColor.white.withAlphaComponent(0.8)])
    }

    private static func drawFujifilm(_ context: UIGraphicsImageRendererContext, _ size: CGSize, _ p: CameraPreset) {
        let h=86.0
        UIColor.black.withAlphaComponent(0.60).setFill()
        context.fill(CGRect(x:0,y:size.height-h,width:size.width,height:h))
        let widths:[CGFloat]=[80,30,60,24,110]
        var x:CGFloat=0
        let colors:[UIColor]=[
            UIColor(red:0.20,green:0.72,blue:0.48,alpha:1),
            UIColor.white.withAlphaComponent(0.9),
            UIColor(red:0.20,green:0.55,blue:0.95,alpha:1),
            UIColor.white.withAlphaComponent(0.9),
            UIColor(red:0.90,green:0.20,blue:0.12,alpha:1)
        ]
        for (i,w) in widths.enumerated() {
            colors[i].setFill(); context.fill(CGRect(x:x,y:size.height-h,width:w,height:6)); x += w+12
        }
        let (_,sf)=fonts(size)
        ("富士胶片  \(p.exifModel)  ·  \(p.lens)  ·  \(info(p))" as NSString).draw(
            at:CGPoint(x:30,y:size.height-h+30),withAttributes:[.font:sf,.foregroundColor:UIColor.white])
    }

    private static func drawRicoh(_ context: UIGraphicsImageRendererContext, _ size: CGSize, _ p: CameraPreset) {
        let box=CGRect(x:size.width-430,y:30,width:400,height:112)
        UIColor.black.withAlphaComponent(0.60).setFill()
        context.fill(box)
        UIColor(red:0.90,green:0.20,blue:0.12,alpha:1).setFill()
        context.fill(CGRect(x:box.maxX-8,y:box.minY,width:8,height:box.height))
        let (_,sf)=fonts(size)
        let hf=UIFont.systemFont(ofSize:max(24,size.width/66),weight:.bold)
        ("理光  \(p.exifModel)" as NSString).draw(at:CGPoint(x:box.minX+20,y:box.minY+18),
            withAttributes:[.font:hf,.foregroundColor:UIColor.white])
        ("街拍  ·  \(p.lens)  ·  \(info(p))" as NSString).draw(at:CGPoint(x:box.minX+22,y:box.minY+60),
            withAttributes:[.font:sf,.foregroundColor:UIColor.white.withAlphaComponent(0.82)])
    }

    private static func drawGeneric(_ context: UIGraphicsImageRendererContext, _ size: CGSize, _ p: CameraPreset) {
        let h=86.0
        UIColor.black.withAlphaComponent(0.65).setFill()
        context.fill(CGRect(x:0,y:size.height-h,width:size.width,height:h))
        let (_,sf)=fonts(size)
        ("\(p.chineseBrand)  \(p.chineseModel)  ·  \(p.lens)  ·  \(info(p))" as NSString).draw(
            at:CGPoint(x:28,y:size.height-h+28),withAttributes:[.font:sf,.foregroundColor:UIColor.white.withAlphaComponent(0.88)])
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

func brandChineseName(_ brand: String) -> String {
    switch brand.uppercased() {
    case "LEICA": return "徕卡"
    case "HASSELBLAD": return "哈苏"
    case "ZEISS": return "蔡司"
    case "VIVO": return "维沃"
    case "XIAOMI": return "小米"
    case "HUAWEI": return "华为"
    case "OPPO": return "欧珀"
    case "GOOGLE": return "谷歌"
    case "APPLE": return "苹果"
    case "SONY": return "索尼"
    case "CANON": return "佳能"
    case "NIKON": return "尼康"
    case "FUJIFILM": return "富士胶片"
    case "RICOH": return "理光"
    case "PANASONIC": return "松下"
    case "SIGMA": return "适马"
    default: return brand
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
            "提示",
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
                Text("风格相机")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(1.3)
                Text("\(preset.chineseBrand) · \(preset.chineseModel)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            Button {
                showPresetPicker = true
            } label: {
                HStack(spacing: 5) {
                    Text(preset.chineseBrand)
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
                            Text(brandChineseName(brand))
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
                Text(captureMode == .proRAW ? "原始格式保留 + 风格照片" : "实时风格 · 自动水印")
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
                        Text(mode.title)
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
                        Text(brandChineseName(brand))
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
                                    Text("\(item.chineseBrand) \(item.chineseModel)")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("\(item.chineseStyle) · \(item.lens)")
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
                Section("照片信息") {
                    TextField("厂商", text: $metadata.make)
                    TextField("机型", text: $metadata.model)
                    TextField("镜头", text: $metadata.lens)
                    TextField("作者", text: $metadata.artist)
                    TextField("版权信息", text: $metadata.copyright)
                    TextField("原始拍摄时间", text: $metadata.dateOriginal)
                    Toggle("移除位置", isOn: $metadata.stripGPS)
                }

                Section("快速写入当前预设") {
                    Button("使用 \(preset.chineseBrand) \(preset.chineseModel)") {
                        metadata.make = preset.exifMake
                        metadata.model = preset.exifModel
                        metadata.lens = preset.lens
                    }
                }

                Section("说明") {
                    Text("导出的照片会保留可读取的原始信息，并可覆盖厂商、机型、镜头、焦段、光圈、感光度等项目。原始照片文件不会被修改。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("照片信息")
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
