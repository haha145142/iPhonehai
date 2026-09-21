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

// MARK: - 基础数据

enum GCamProfile: String, CaseIterable, Identifiable {
    case natural = "自然"
    case bright = "明亮"
    case night = "夜景"
    case motion = "运动"

    var id: String { rawValue }
    var title: String { rawValue }

    func applying(to preset: CameraPreset) -> CameraPreset {
        switch self {
        case .natural:
            return preset
        case .bright:
            return CameraPreset(
                id: preset.id + "-bright", brand: preset.brand, model: preset.model, lens: preset.lens,
                focal: preset.focal, aperture: preset.aperture, iso: preset.iso, shutter: preset.shutter,
                style: "明亮",
                exposure: preset.exposure + 0.22,
                saturation: preset.saturation,
                contrast: max(0.80, preset.contrast * 0.94),
                highlights: max(0.0, preset.highlights * 0.78),
                shadows: min(1.0, preset.shadows + 0.12),
                sharpness: preset.sharpness * 0.92,
                warmth: preset.warmth, tint: preset.tint, channelBias: preset.channelBias,
                exifMake: preset.exifMake, exifModel: preset.exifModel, watermarkLayout: preset.watermarkLayout
            )
        case .night:
            return CameraPreset(
                id: preset.id + "-night", brand: preset.brand, model: preset.model, lens: preset.lens,
                focal: preset.focal, aperture: preset.aperture, iso: preset.iso, shutter: preset.shutter,
                style: "夜景",
                exposure: preset.exposure + 0.10,
                saturation: preset.saturation * 0.96,
                contrast: max(0.78, preset.contrast * 0.92),
                highlights: max(0.0, preset.highlights * 0.62),
                shadows: min(1.0, preset.shadows + 0.20),
                sharpness: preset.sharpness * 0.82,
                warmth: preset.warmth, tint: preset.tint, channelBias: preset.channelBias,
                exifMake: preset.exifMake, exifModel: preset.exifModel, watermarkLayout: preset.watermarkLayout
            )
        case .motion:
            return CameraPreset(
                id: preset.id + "-motion", brand: preset.brand, model: preset.model, lens: preset.lens,
                focal: preset.focal, aperture: preset.aperture, iso: preset.iso, shutter: preset.shutter,
                style: "运动",
                exposure: preset.exposure + 0.03,
                saturation: preset.saturation,
                contrast: min(1.25, preset.contrast * 1.05),
                highlights: preset.highlights,
                shadows: preset.shadows,
                sharpness: min(1.0, preset.sharpness + 0.18),
                warmth: preset.warmth, tint: preset.tint, channelBias: preset.channelBias,
                exifMake: preset.exifMake, exifModel: preset.exifModel, watermarkLayout: preset.watermarkLayout
            )
        }
    }
}

enum ScenePreset: String, CaseIterable, Identifiable, Sendable {
    case photo = "照片"
    case portrait = "人像"
    case night = "夜景"

    var id: String { rawValue }

    func applying(to preset: CameraPreset) -> CameraPreset {
        switch self {
        case .photo:
            return preset
        case .portrait:
            return CameraPreset(
                id: preset.id + "-portrait",
                brand: preset.brand,
                model: preset.model,
                lens: preset.lens,
                focal: preset.focal,
                aperture: preset.aperture,
                iso: preset.iso,
                shutter: preset.shutter,
                style: "人像",
                exposure: preset.exposure + 0.08,
                saturation: min(1.35, preset.saturation * 0.97),
                contrast: max(0.80, preset.contrast * 0.88),
                highlights: min(0.95, preset.highlights + 0.04),
                shadows: min(0.80, preset.shadows + 0.10),
                sharpness: max(0.10, preset.sharpness * 0.78),
                warmth: preset.warmth + 0.30,
                tint: preset.tint,
                channelBias: preset.channelBias,
                exifMake: preset.exifMake,
                exifModel: preset.exifModel,
                watermarkLayout: preset.watermarkLayout,
                agcProfile: preset.agcProfile
            )
        case .night:
            return CameraPreset(
                id: preset.id + "-night",
                brand: preset.brand,
                model: preset.model,
                lens: preset.lens,
                focal: preset.focal,
                aperture: preset.aperture,
                iso: preset.iso,
                shutter: preset.shutter,
                style: "夜景",
                exposure: min(1.0, preset.exposure + 0.32),
                saturation: preset.saturation * 0.96,
                contrast: max(0.76, preset.contrast * 0.90),
                highlights: max(0.10, preset.highlights * 0.72),
                shadows: min(0.85, preset.shadows + 0.22),
                sharpness: preset.sharpness * 0.72,
                warmth: preset.warmth - 0.10,
                tint: preset.tint,
                channelBias: preset.channelBias,
                exifMake: preset.exifMake,
                exifModel: preset.exifModel,
                watermarkLayout: preset.watermarkLayout,
                agcProfile: preset.agcProfile
            )
        }
    }
}

enum CaptureMode: CaseIterable, Identifiable, Sendable {
    case photo, proRAW, livePhoto

    var id: String { title }

    var title: String {
        switch self {
        case .photo: return "照片"
        case .proRAW: return "专业原片"
        case .livePhoto: return "实况照片"
        }
    }
}

enum WatermarkLayout: String, CaseIterable, Sendable {
    case verticalLeft
    case verticalRight
    case bottomBand
    case bottomMinimal
    case topRight
    case split

    static func forBrand(_ brand: String, style: String) -> WatermarkLayout {
        switch brand.uppercased() {
        case "LEICA": return style == "Street" ? .verticalRight : .verticalLeft
        case "HASSELBLAD": return style == "Portrait" ? .bottomBand : .verticalLeft
        case "ZEISS": return .bottomMinimal
        case "VIVO": return .bottomBand
        case "XIAOMI": return .verticalLeft
        case "HUAWEI": return .bottomBand
        case "OPPO": return .verticalRight
        case "GOOGLE": return .bottomMinimal
        case "APPLE": return .topRight
        case "SONY": return .split
        case "CANON": return .bottomBand
        case "NIKON": return .split
        case "FUJIFILM": return .bottomMinimal
        case "RICOH": return .verticalLeft
        default: return .bottomBand
        }
    }
}

struct MetadataDraft: Hashable, Sendable {
    var make = ""
    var model = ""
    var lens = ""
    var artist = ""
    var copyright = ""
    var software = "风格相机"
    var dateOriginal = ""
    var stripGPS = false
}

enum CustomWatermarkLayout: String, CaseIterable, Identifiable, Sendable {
    case bottom
    case verticalLeft
    case verticalRight
    case topRight
    case minimal
    case split

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bottom: return "底部参数条"
        case .verticalLeft: return "左侧竖排"
        case .verticalRight: return "右侧竖排"
        case .topRight: return "右上角"
        case .minimal: return "极简"
        case .split: return "分栏"
        }
    }
}

enum CustomFrameStyle: String, CaseIterable, Identifiable, Sendable {
    case none
    case thin
    case bold
    case film
    case rounded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "无相框"
        case .thin: return "细线相框"
        case .bold: return "粗线相框"
        case .film: return "电影边框"
        case .rounded: return "圆角相框"
        }
    }
}

struct CustomWatermarkConfig: Hashable, Sendable {
    var title = ""
    var subtitle = ""
    var showParameters = true
    var usePresetBrand = true
    var layout: CustomWatermarkLayout = .bottom
    var opacity: Double = 0.72
    var frame: CustomFrameStyle = .none
    var frameWidth: Double = 8
    var customFooter = ""
    var logoData: Data? = nil
    var logoScale: Double = 0.18
    var showLogo: Bool = true

    var isCustomized: Bool {
        !title.isEmpty || !subtitle.isEmpty || !customFooter.isEmpty || !usePresetBrand ||
        layout != .bottom || frame != .none || showParameters == false ||
        logoData != nil
    }
}

struct LUT3D: Hashable, Sendable {
    let name: String
    let dimension: Int
    let cubeData: Data
}

enum LUT3DParser {
    static func parse(_ data: Data, name: String) throws -> LUT3D {
        guard let text = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "GCamStyleLUT", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法读取色彩曲线文件。"])
        }

        var dimension: Int?
        var values: [(Float, Float, Float)] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard let first = parts.first else { continue }

            if first.uppercased() == "LUT_3D_SIZE", parts.count >= 2 {
                dimension = Int(parts[1])
                continue
            }

            if parts.count >= 3,
               let r = Float(parts[0]),
               let g = Float(parts[1]),
               let b = Float(parts[2]) {
                values.append((r, g, b))
            }
        }

        guard let size = dimension, (2...64).contains(size) else {
            throw NSError(domain: "GCamStyleLUT", code: 2, userInfo: [NSLocalizedDescriptionKey: "色彩曲线文件缺少有效的三维尺寸。"])
        }

        let expected = size * size * size
        guard values.count >= expected else {
            throw NSError(domain: "GCamStyleLUT", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "色彩曲线数据不完整：需要 \(expected) 个颜色点，实际只有 \(values.count) 个。"
            ])
        }

        var floats = [Float]()
        floats.reserveCapacity(expected * 4)

        for (r, g, b) in values.prefix(expected) {
            floats.append(min(1, max(0, r)))
            floats.append(min(1, max(0, g)))
            floats.append(min(1, max(0, b)))
            floats.append(1)
        }

        let cubeData = floats.withUnsafeBufferPointer { Data(buffer: $0) }
        return LUT3D(name: name, dimension: size, cubeData: cubeData)
    }
}

final class LUTStore {
    static let shared = LUTStore()

    private let lock = NSLock()
    private var lut: LUT3D?

    var current: LUT3D? {
        lock.lock()
        defer { lock.unlock() }
        return lut
    }

    func set(_ lut: LUT3D?) {
        lock.lock()
        self.lut = lut
        lock.unlock()
    }
}

struct AGCRenderProfile: Hashable, Sendable {
    let index: Int
    let title: String

    let red: Float
    let green: Float
    let blue: Float
    let saturation: Float

    let contrast2: Float?
    let blackLevel: Float?
    let hdrPlus: Float?
    let hdrMinus: Float?

    let frameCount: Int?
    let zslFrameCount: Int?
    let nsFrameCount: Int?

    let sharpGain: Float?
    let darkerExposure: Float?

    let tonePreset: Int?
    let gammaPreset: Int?
    let lutIndex: Int?

    // 自定义 AGC 曲线的原始采样。
    let toneCurve: [Float]
    let gammaCurve: [Float]
}

struct CameraPreset: Identifiable, Hashable, Sendable {
    let id: String
    let brand: String
    let model: String
    let lens: String
    let focal: String
    let aperture: String
    let iso: String
    let shutter: String
    let style: String

    let exposure: Float
    let saturation: Float
    let contrast: Float
    let highlights: Float
    let shadows: Float
    let sharpness: Float
    let warmth: Float
    let tint: Float
    let channelBias: Float

    let exifMake: String
    let exifModel: String
    let watermarkLayout: WatermarkLayout
    let watermarkBrand: String?
    let agcProfile: AGCRenderProfile?

    init(
        id: String,
        brand: String,
        model: String,
        lens: String,
        focal: String,
        aperture: String,
        iso: String,
        shutter: String,
        style: String,
        exposure: Float,
        saturation: Float,
        contrast: Float,
        highlights: Float,
        shadows: Float,
        sharpness: Float,
        warmth: Float,
        tint: Float,
        channelBias: Float,
        exifMake: String,
        exifModel: String,
        watermarkLayout: WatermarkLayout,
        watermarkBrand: String? = nil,
        agcProfile: AGCRenderProfile? = nil
    ) {
        self.id = id
        self.brand = brand
        self.model = model
        self.lens = lens
        self.focal = focal
        self.aperture = aperture
        self.iso = iso
        self.shutter = shutter
        self.style = style
        self.exposure = exposure
        self.saturation = saturation
        self.contrast = contrast
        self.highlights = highlights
        self.shadows = shadows
        self.sharpness = sharpness
        self.warmth = warmth
        self.tint = tint
        self.channelBias = channelBias
        self.exifMake = exifMake
        self.exifModel = exifModel
        self.watermarkLayout = watermarkLayout
        self.watermarkBrand = watermarkBrand
        self.agcProfile = agcProfile
    }

    var displayBrand: String {
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
        case "FUJIFILM": return "富士"
        case "RICOH": return "理光"
        case "PANASONIC": return "松下"
        case "SIGMA": return "适马"
        default: return brand
        }
    }

    var watermarkAccent: UIColor {
        switch (watermarkBrand ?? brand).uppercased() {
        case "LEICA": return UIColor(red: 0.90, green: 0.10, blue: 0.07, alpha: 1)
        case "HASSELBLAD": return UIColor(red: 1.00, green: 0.54, blue: 0.06, alpha: 1)
        case "ZEISS", "VIVO": return UIColor(red: 0.14, green: 0.52, blue: 0.95, alpha: 1)
        case "XIAOMI": return UIColor(red: 0.96, green: 0.37, blue: 0.08, alpha: 1)
        case "HUAWEI": return UIColor(red: 0.86, green: 0.08, blue: 0.12, alpha: 1)
        case "OPPO": return UIColor(red: 0.40, green: 0.82, blue: 0.50, alpha: 1)
        case "NIKON": return UIColor(red: 0.96, green: 0.78, blue: 0.08, alpha: 1)
        case "CANON": return UIColor(red: 0.80, green: 0.12, blue: 0.08, alpha: 1)
        default: return .white
        }
    }
}

// 32 个相机身份 × 4 套风格 = 128 个可选预设。
// 参数不是厂商内部算法，而是本 App 的可解释渲染参数。
enum PresetLibrary {
    static let all: [CameraPreset] = {
        let bases: [(String,String,String,String,String,String,String,String,Double,Double,Double,Double,Double,Double,Double,Double,String,String)] = [
            ("LEICA","Q3","SUMMILUX 1:1.7/28 ASPH.","28mm","F1.7","ISO 100","1/250s", "徕卡经典", 0.92,1.08,0.92,0.10,0.28,0,0,0.0,"Leica Camera AG","LEICA Q3"),
            ("LEICA","Q3 43","APO-SUMMICRON 1:2/43 ASPH.","43mm","F2.0","ISO 100","1/250s", "徕卡 43", 0.93,1.08,0.94,0.08,0.25,0,0,0.0,"Leica Camera AG","LEICA Q3 43"),
            ("LEICA","M11","SUMMILUX-M 1:1.4/35 ASPH.","35mm","F1.4","ISO 64","1/500s", "徕卡 M", 0.92,1.10,0.92,0.09,0.30,0,0,0.0,"Leica Camera AG","LEICA M11"),
            ("LEICA","SL3","VARIO-ELMARIT-SL 24-90","50mm","F2.8","ISO 100","1/250s", "徕卡 SL", 0.94,1.07,0.95,0.10,0.28,0,0,0.0,"Leica Camera AG","LEICA SL3"),
            ("LEICA","D-LUX 8","DC VARIO-SUMMILUX","24mm","F1.7","ISO 100","1/320s", "徕卡 D-LUX", 0.90,1.05,0.90,0.08,0.22,0,0,0.0,"Leica Camera AG","LEICA D-LUX 8"),
            ("HASSELBLAD","X2D 100C","XCD 2,5/38V","38mm","F2.5","ISO 64","1/320s", "哈苏自然", 0.86,1.03,0.92,0.14,0.22,0,0,0.0,"Hasselblad","X2D 100C"),
            ("HASSELBLAD","X2D 100C","XCD 2,5/55V","55mm","F2.5","ISO 64","1/320s", "哈苏人像", 0.87,1.03,0.90,0.16,0.22,0,0,0.0,"Hasselblad","X2D 100C"),
            ("HASSELBLAD","907X","XCD 4/45P","45mm","F4.0","ISO 100","1/320s", "哈苏中画幅", 0.87,1.02,0.94,0.14,0.20,0,0,0.0,"Hasselblad","907X"),
            ("ZEISS","ZX1","Distagon 2/35","35mm","F2.0","ISO 100","1/250s", "蔡司自然色", 0.98,1.12,0.90,0.06,0.34,-2,0,0.0,"ZEISS","ZX1"),
            ("ZEISS","Otus 55","Otus 1.4/55","55mm","F1.4","ISO 100","1/500s", "蔡司微反差", 0.97,1.14,0.92,0.07,0.42,-1,0,0.0,"ZEISS","Otus 55"),
            ("VIVO","X200 Ultra","ZEISS Master","35mm","F1.2","ISO 50","1/250s", "vivo 蔡司大师", 1.06,1.06,0.96,0.12,0.26,2,0,0.0,"vivo","X200 Ultra"),
            ("VIVO","X200 Pro","ZEISS Tele","50mm","F1.6","ISO 50","1/250s", "vivo 蔡司长焦", 1.04,1.05,0.94,0.12,0.28,1,0,0.0,"vivo","X200 Pro"),
            ("VIVO","X100 Ultra","ZEISS APO Tele","85mm","F2.5","ISO 64","1/320s", "vivo 蔡司人像", 1.03,1.05,0.92,0.18,0.24,1,1,0.0,"vivo","X100 Ultra"),
            ("XIAOMI","15 Ultra","Leica Summilux","23mm","F1.63","ISO 50","1/250s", "小米徕卡", 0.96,1.10,0.93,0.09,0.30,0,0,0.0,"Xiaomi","15 Ultra"),
            ("XIAOMI","15 Ultra","Leica Portrait 75","75mm","F2.5","ISO 64","1/320s", "小米徕卡人像", 0.95,1.08,0.90,0.16,0.25,0,0,0.0,"Xiaomi","15 Ultra"),
            ("XIAOMI","14 Ultra","Leica Vario-Summilux","23mm","F1.63","ISO 50","1/250s", "小米徕卡经典", 0.96,1.08,0.93,0.10,0.28,0,0,0.0,"Xiaomi","14 Ultra"),
            ("HUAWEI","Pura 70 Ultra","XMAGE","24mm","F1.6","ISO 50","1/200s", "华为 XMAGE", 1.05,1.06,0.93,0.11,0.25,2,1,0.0,"HUAWEI","Pura 70 Ultra"),
            ("HUAWEI","Mate 70 Pro","XMAGE","24mm","F1.4","ISO 50","1/200s", "华为 XMAGE 大师", 1.04,1.05,0.92,0.11,0.28,2,1,0.0,"HUAWEI","Mate 70 Pro"),
            ("OPPO","Find X8 Ultra","Hasselblad","23mm","F1.8","ISO 50","1/250s", "OPPO 哈苏", 1.03,1.05,0.92,0.15,0.27,1,0,0.0,"OPPO","Find X8 Ultra"),
            ("OPPO","Find X7 Ultra","Hasselblad","23mm","F1.8","ISO 50","1/250s", "OPPO 哈苏自然", 1.03,1.05,0.94,0.13,0.25,1,0,0.0,"OPPO","Find X7 Ultra"),
            ("GOOGLE","Pixel 10 Pro","Computational","25mm","F1.7","ISO 50","1/250s", "谷歌计算摄影", 1.02,1.04,0.92,0.12,0.34,0,0,0.0,"Google","Pixel 10 Pro"),
            ("GOOGLE","Pixel 9 Pro","Computational","25mm","F1.7","ISO 50","1/250s", "谷歌自然", 1.03,1.04,0.93,0.11,0.32,0,0,0.0,"Google","Pixel 9 Pro"),
            ("APPLE","iPhone 17 Pro","Main","24mm","F1.78","ISO 50","1/250s", "苹果专业", 1.00,1.03,0.95,0.12,0.26,0,0,0.0,"Apple","iPhone 17 Pro"),
            ("APPLE","iPhone 17 Pro Max","Main","24mm","F1.78","ISO 50","1/250s", "苹果专业", 1.00,1.03,0.95,0.12,0.26,0,0,0.0,"Apple","iPhone 17 Pro Max"),
            ("SONY","α1 II","G Master","35mm","F1.4","ISO 100","1/500s", "索尼 G Master", 0.98,1.10,0.94,0.08,0.38,-1,0,0.0,"SONY","ILCE-1M2"),
            ("SONY","α7R V","G Master","35mm","F1.4","ISO 100","1/500s", "索尼高解析", 0.98,1.10,0.93,0.08,0.36,-1,0,0.0,"SONY","ILCE-7RM5"),
            ("CANON","EOS R5 Mark II","RF L","50mm","F1.2","ISO 100","1/500s", "佳能 RF L", 1.01,1.08,0.93,0.10,0.30,1,0,0.0,"Canon","Canon EOS R5 Mark II"),
            ("NIKON","Z8","NIKKOR Z","50mm","F1.8","ISO 64","1/500s", "尼康 NIKKOR Z", 1.00,1.08,0.94,0.10,0.32,0,0,0.0,"NIKON CORPORATION","NIKON Z 8"),
            ("FUJIFILM","X100VI","FUJINON","23mm","F2.0","ISO 125","1/250s", "富士胶片", 0.96,1.06,0.90,0.12,0.26,1,-1,0.0,"FUJIFILM","X100VI"),
            ("RICOH","GR IIIx","GR Lens","40mm","F2.8","ISO 100","1/500s", "理光街拍", 0.95,1.05,0.91,0.09,0.42,-1,0,0.0,"RICOH IMAGING COMPANY, LTD.","RICOH GR IIIx"),
            ("PANASONIC","S1RII","LUMIX S PRO","50mm","F1.8","ISO 100","1/500s", "松下自然", 0.98,1.07,0.94,0.11,0.33,0,0,0.0,"Panasonic","DC-S1RM2"),
            ("SIGMA","fp L","Contemporary","45mm","F2.8","ISO 100","1/500s", "适马", 0.97,1.06,0.94,0.12,0.34,0,0,0.0,"SIGMA","SIGMA fp L")
        ]

        let variants: [(String,Double,Double,Double,Double,Double)] = [
            ("自然",1.00,1.00,0.00,0.00,0.00),
            ("电影",0.93,1.10,-0.08,0.12,0.55),
            ("人像",1.02,1.05,0.06,0.18,0.28),
            ("街拍",0.90,1.12,-0.02,-0.04,0.70)
        ]

        var output: [CameraPreset] = []
        output.reserveCapacity(bases.count * variants.count)

        for b in bases {
            for v in variants {
                output.append(
                    CameraPreset(
                        id: "\(b.0)-\(b.1)-\(v.0)",
                        brand: b.0,
                        model: b.1,
                        lens: "\(b.2) · \(v.0)",
                        focal: b.3,
                        aperture: b.4,
                        iso: b.5,
                        shutter: b.6,
                        style: v.0,
                        exposure: Float(b.8 + v.3),
                        saturation: Float(b.9 * v.1),
                        contrast: Float(b.10 * v.2),
                        highlights: Float(min(1.0, max(0.0, b.11 + v.4))),
                        shadows: Float(min(1.0, max(0.0, b.12))),
                        sharpness: Float(min(1.0, max(0.0, b.13 + v.5))),
                        warmth: Float(b.14),
                        tint: Float(b.15),
                        channelBias: 0,
                        exifMake: b.16,
                        exifModel: b.17,
                        watermarkLayout: WatermarkLayout.forBrand(b.0, style: v.0)
                    )
                )
            }
        }
        return output
    }()

    static var brands: [String] {
        var result: [String] = []
        for p in all where !result.contains(p.brand) { result.append(p.brand) }
        return result
    }
}

// MARK: - 安卓谷歌相机配置兼容层
//
// 真实 AGC 文件是 Android SharedPreferences 风格的 XML。
// 它不是简单的“几个滤镜参数”，而是包含大量 libpatch、色彩、降噪、
// HDR、帧数、LUT、Profile 等配置。iPhone 不能直接执行安卓 .so，
// 因此这里做“配置读取 → iOS 成像参数映射”，并逐个恢复 AGC Profile。

struct AGCConfig {
    var values: [String: String] = [:]
    var sets: [String: [String]] = [:]

    func string(_ key: String) -> String? {
        guard let value = values[key] else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    func number(_ key: String) -> Double? {
        guard let raw = string(key) else { return nil }
        return Double(raw.replacingOccurrences(of: ",", with: "."))
    }

    func int(_ key: String) -> Int? {
        guard let raw = string(key) else { return nil }
        return Int(raw)
    }

    func bool(_ key: String) -> Bool? {
        guard let raw = string(key)?.lowercased() else { return nil }
        switch raw {
        case "1", "true", "on", "yes": return true
        case "0", "false", "off", "no": return false
        default: return nil
        }
    }

    func profileValue(_ key: String, profile: Int, cameraIndex: Int = 0) -> String? {
        let exact = "\(key)_p\(profile)_\(cameraIndex)"
        if let value = string(exact) { return value }

        let noCameraSuffix = "\(key)_p\(profile)"
        return string(noCameraSuffix)
    }

    func profileNumber(_ key: String, profile: Int, cameraIndex: Int = 0) -> Double? {
        guard let value = profileValue(key, profile: profile, cameraIndex: cameraIndex) else { return nil }
        return Double(value)
    }

    func profileInt(_ key: String, profile: Int, cameraIndex: Int = 0) -> Int? {
        guard let value = profileValue(key, profile: profile, cameraIndex: cameraIndex) else { return nil }
        return Int(value)
    }

    func profileIndices() -> [Int] {
        var ids = Set<Int>()

        if let count = int("pref_patch_profile_count_key"), count > 0, count <= 256 {
            ids.formUnion(0..<count)
        }

        let pattern = #"^lib_profile_title_key_p(\d+)_0$"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            for key in values.keys {
                let ns = key as NSString
                let range = NSRange(location: 0, length: ns.length)
                guard
                    let match = regex.firstMatch(in: key, range: range),
                    let numberRange = Range(match.range(at: 1), in: key),
                    let id = Int(key[numberRange]),
                    id >= 0,
                    id <= 63
                else { continue }
                ids.insert(id)
            }
        }

        return ids.sorted()
    }

    func profileTitle(_ index: Int) -> String {
        profileValue("lib_profile_title_key", profile: index)
            ?? profileValue("pref_patch_profile_title_key", profile: index)
            ?? profileValue("lib_profile_name_key", profile: index)
            ?? "配置 \(index + 1)"
    }

    func profileTitles() -> [String] {
        profileIndices().map(profileTitle)
    }
}

final class AGCXMLParser: NSObject, XMLParserDelegate {
    private var config = AGCConfig()
    private var currentName: String?
    private var currentText = ""
    private var currentSetName: String?
    private var currentSetValues: [String] = []
    private var capturingSet = false

    func parse(_ data: Data) throws -> AGCConfig {
        let parser = XMLParser(data: data)
        parser.delegate = self

        guard parser.parse() else {
            throw NSError(
                domain: "GCamStyleAGC",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        parser.parserError?.localizedDescription ??
                        "安卓配置文件无法读取，请确认这是有效的 AGC 配置文件。"
                ]
            )
        }

        return config
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        switch elementName {
        case "string", "int", "long", "float", "double", "boolean":
            currentName = attributeDict["name"]
            currentText = ""

            if let value = attributeDict["value"], let currentName {
                config.values[currentName] = value
                self.currentName = nil
            }

        case "set":
            currentSetName = attributeDict["name"]
            currentSetValues = []
            capturingSet = true

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "string":
            if let name = currentName {
                config.values[name] = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                currentName = nil
                currentText = ""
            } else if capturingSet {
                let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    currentSetValues.append(value)
                }
                currentText = ""
            }

        case "int", "long", "float", "double", "boolean":
            if let name = currentName {
                config.values[name] = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                currentName = nil
                currentText = ""
            }

        case "set":
            if let name = currentSetName {
                config.sets[name] = currentSetValues
            }
            currentSetName = nil
            currentSetValues = []
            capturingSet = false

        default:
            break
        }
    }
}

enum AGCCurveDecoder {
    static func decode(hex: String, title: String) -> (tone: [Float], gamma: [Float]) {
        guard hex.count >= 32 else { return ([], []) }

        var values: [Float] = []
        values.reserveCapacity(hex.count / 16)

        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 16, limitedBy: hex.endIndex) ?? hex.endIndex
            guard next > index else { break }
            let chunk = String(hex[index..<next])
            if chunk.count == 16,
               let bytes = Data(hexString: chunk) {
                let value = bytes.withUnsafeBytes { raw -> Double in
                    raw.load(as: Double.self)
                }
                if value.isFinite {
                    values.append(Float(min(1.0, max(0.0, value))))
                }
            }
            if next == hex.endIndex { break }
            index = next
        }

        switch (values.count, title.lowercased()) {
        case (17, let t) where t.contains("tone curve"):
            return (values, [])
        case (33, let t) where t.contains("gamma"):
            return ([], values)
        case (50, let t) where t.contains("tone") && t.contains("gamma"):
            return (Array(values.prefix(25)), Array(values.suffix(25)))
        case (57, _):
            // 这类 AGC Curve 数据包含额外的控制点；最后 33 个值是最稳定的
            // 输出段，在 iOS 曲线引擎中作为一维色调曲线。
            return (Array(values.suffix(33)), [])
        default:
            return (values, [])
        }
    }
}

private extension Data {
    init?(hexString: String) {
        self.init()
        let chars = Array(hexString.utf8)
        guard chars.count % 2 == 0 else { return nil }
        var index = 0
        while index < chars.count {
            let hi = Self.hexValue(chars[index])
            let lo = Self.hexValue(chars[index + 1])
            guard hi >= 0, lo >= 0 else { return nil }
            append(UInt8((hi << 4) | lo))
            index += 2
        }
    }

    static func hexValue(_ c: UInt8) -> Int {
        switch c {
        case 48...57: return Int(c - 48)
        case 65...70: return Int(c - 65 + 10)
        case 97...102: return Int(c - 97 + 10)
        default: return -1
        }
    }
}


enum AGCMapper {
    private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(high, max(low, value))
    }

    private static func finite(_ value: Double, fallback: Double) -> Double {
        value.isFinite ? value : fallback
    }

    private static func firstNumber(_ config: AGCConfig, _ keys: [String], profile: Int, cameraIndex: Int = 0) -> Double? {
        for key in keys {
            if let value = config.profileNumber(key, profile: profile, cameraIndex: cameraIndex) {
                return value
            }
        }
        return nil
    }

    private static func firstInt(_ config: AGCConfig, _ keys: [String], profile: Int, cameraIndex: Int = 0) -> Int? {
        for key in keys {
            if let value = config.profileInt(key, profile: profile, cameraIndex: cameraIndex) {
                return value
            }
        }
        return nil
    }

    private static func cameraTitle(_ config: AGCConfig) -> String {
        config.string("pref_config_filename_key")?.replacingOccurrences(of: ".agc", with: "") ?? "安卓配置"
    }

    private static func curve(for config: AGCConfig, profile: Int, cameraIndex: Int = 0) -> (tone: [Float], gamma: [Float]) {
        for customIndex in 1...10 {
            for slotIndex in 0...5 {
                let enabledKey = "lib_custom_\(customIndex)_key_p\(profile)_\(slotIndex)_enabled"
                guard config.string(enabledKey) == "1" else { continue }
                let title = config.string("lib_custom_\(customIndex)_key_p\(profile)_\(slotIndex)_title") ?? ""
                let value = config.string("lib_custom_\(customIndex)_key_p\(profile)_\(slotIndex)_value") ?? ""
                if !value.isEmpty {
                    return AGCCurveDecoder.decode(hex: value, title: title)
                }
            }
        }

        // Some configs keep the active curve in a camera-specific slot.
        for slot in 0...5 {
            let value = config.string("lib_custom_1_key_p\(profile)_\(slot)_value") ?? ""
            if !value.isEmpty {
                let title = config.string("lib_custom_1_key_p\(profile)_\(slot)_title") ?? ""
                return AGCCurveDecoder.decode(hex: value, title: title)
            }
        }

        return ([], [])
    }

    static func makePresets(from config: AGCConfig, fileName: String) -> [CameraPreset] {
        let sourceName = cameraTitle(config)
        let watermarkType = config.int("pref_watermark_type_key") ?? 0
        let ids = config.profileIndices()
        let profileIDs = ids.isEmpty ? [0] : ids

        let globalHue = config.number("lib_gpu_hue_key") ?? 0
        let globalVibrance = config.number("lib_gpu_vibrance_key") ?? 1
        let globalContrast = config.number("lib_gpu_contrast_key") ?? 1

        return profileIDs.map { index in
            let title = config.profileTitle(index)

            let red = Float(firstNumber(config, ["lib_pref_satcct_r_key"], profile: index) ?? 1)
            let green = Float(firstNumber(config, ["lib_pref_satcct_g_key"], profile: index) ?? 1)
            let blue = Float(firstNumber(config, ["lib_pref_satcct_b_key"], profile: index) ?? 1)
            let sat = Float(clamp(
                (firstNumber(config, ["lib_pref_satcct_c_key", "lib_gpu_saturation_key"], profile: index) ?? 1)
                * (0.90 + globalVibrance * 0.10),
                0.55, 1.55
            ))

            let contrast2 = firstNumber(config, ["lib_contrast_2_key"], profile: index)
            let black = firstNumber(config, ["lib_contrast_black_key"], profile: index)
            let contrast = Float(clamp(
                globalContrast * (0.92 + ((contrast2 ?? 0.46) - 0.46) * 0.70 + ((black ?? 0.85) - 0.85) * 0.12),
                0.65, 1.45
            ))

            let hdrPlus = firstNumber(config, ["lib_hdr_range_plus_key"], profile: index)
            let hdrMinus = firstNumber(config, ["lib_hdr_range_minus_key"], profile: index)

            let highlights = Float(clamp(
                0.85 - (hdrPlus ?? 5.0) * 0.038,
                0.08, 0.92
            ))
            let shadows = Float(clamp(
                0.16 + abs(hdrMinus ?? -2.0) * 0.060,
                0.04, 0.75
            ))

            let frames = firstInt(config, [
                "lib_pref_frame_count_key",
                "lib_pref_frame_count_zsl_key",
                "lib_pref_frame_count_ns_key"
            ], profile: index)

            let sharp = firstNumber(config, [
                "lib_sharp_gain_key",
                "lib_sharpness_a_key",
                "lib_gpu_sharpness_key",
                "lib_sharp_gain_micro_key",
                "lib_sharp_gain_macro_key"
            ], profile: index)

            let denoise = firstNumber(config, [
                "lib_denoise_smoothing_key",
                "lib_sabre_denoise_control_key",
                "lib_noise_reduction_adjust_key"
            ], profile: index) ?? 0

            let darker = firstNumber(config, ["lib_exposure_darker_key"], profile: index)
            let tonePreset = firstInt(config, ["lib_tone_curve_preset_key"], profile: index)
            let gammaPreset = firstInt(config, ["lib_gamma_curve_preset_key"], profile: index)
            let lutIndex = firstInt(config, ["lib_lut_key"], profile: index)

            let tone = firstNumber(config, ["lib_tone_key"], profile: index) ?? 15
            let gamma = firstNumber(config, ["lib_gamma_key"], profile: index) ?? 5
            let exposure = Float(clamp(
                finite((darker ?? 0) * 0.028 + (tone - 15) * 0.004 + (gamma - 5) * 0.003, fallback: 0),
                -1.20, 1.20
            ))

            let warmth = Float(clamp(Double(red - blue) * 7.5 + globalHue / 36.0, -12, 12))
            let tint = Float(clamp(Double(green - (red + blue) / 2) * 6.0, -8, 8))
            let sharpness = Float(clamp(
                (sharp ?? 0.24) - denoise * 0.012,
                0.05, 1.0
            ))

            let curves = curve(for: config, profile: index)

            let layout: WatermarkLayout
            switch watermarkType {
            case 1: layout = .verticalLeft
            case 2: layout = .verticalRight
            case 3: layout = .topRight
            default: layout = .bottomBand
            }

            let profile = AGCRenderProfile(
                index: index,
                title: title,
                red: red,
                green: green,
                blue: blue,
                saturation: sat,
                contrast2: contrast2.map(Float.init),
                blackLevel: black.map(Float.init),
                hdrPlus: hdrPlus.map(Float.init),
                hdrMinus: hdrMinus.map(Float.init),
                frameCount: frames,
                zslFrameCount: config.profileInt("lib_pref_frame_count_zsl_key", profile: index),
                nsFrameCount: config.profileInt("lib_pref_frame_count_ns_key", profile: index),
                sharpGain: sharp.map(Float.init),
                darkerExposure: darker.map(Float.init),
                tonePreset: tonePreset,
                gammaPreset: gammaPreset,
                lutIndex: lutIndex,
                toneCurve: curves.tone,
                gammaCurve: curves.gamma
            )

            return CameraPreset(
                id: "agc-(fileName)-p(index)-(UUID().uuidString)",
                brand: "AGC",
                model: title,
                lens: sourceName,
                focal: "主摄",
                aperture: "自动",
                iso: "自动",
                shutter: "自动",
                style: "安卓配置",
                exposure: exposure,
                saturation: sat,
                contrast: contrast,
                highlights: highlights,
                shadows: shadows,
                sharpness: sharpness,
                warmth: warmth,
                tint: tint,
                channelBias: 0,
                exifMake: "AGC",
                exifModel: sourceName,
                watermarkLayout: layout,
                agcProfile: profile
            )
        }
    }

    static func defaultWatermarkConfig(from config: AGCConfig) -> (enabled: Bool, title: String, layout: CustomWatermarkLayout) {
        let enabled = config.string("pref_photo_watermark_key") == "1"
        let title = config.string("pref_watermark_title_key") ?? ""
        let type = config.int("pref_watermark_type_key") ?? 0
        let layout: CustomWatermarkLayout
        switch type {
        case 1: layout = .verticalLeft
        case 2: layout = .verticalRight
        case 3: layout = .topRight
        default: layout = .bottom
        }
        return (enabled, title, layout)
    }
}

struct AGCProfileDefinition: Sendable {
    let index: Int
    let title: String
    let tonePreset: Int?
    let gammaPreset: Int?
    let sectPreset: Int?
    let tone: Float
    let gamma: Float
    let saturation: Float
    let red: Float
    let green: Float
    let blue: Float
    let hdrPlus: Float
    let hdrMinus: Float
    let frameCount: Int
    let zslFrameCount: Int
    let nsFrameCount: Int
    let denoise: Float
    let sharp: Float
}

enum AGCProfileLibrary {
    private static let definitions: [AGCProfileDefinition] = [
        .init(index: 0, title: "标准低噪 🖼", tonePreset: 8, gammaPreset: 3, sectPreset: 3, tone: 15, gamma: 8, saturation: 1, red: 1, green: 1, blue: 1, hdrPlus: 5, hdrMinus: -3, frameCount: 0, zslFrameCount: 20, nsFrameCount: 0, denoise: 0.46875, sharp: 0),
        .init(index: 1, title: "柔和细节 🍄", tonePreset: 19, gammaPreset: 7, sectPreset: 2, tone: 23, gamma: 11, saturation: 1, red: 1, green: 1, blue: 1, hdrPlus: 13.5, hdrMinus: -1.25, frameCount: 0, zslFrameCount: 0, nsFrameCount: 0, denoise: 0.46875, sharp: 1),
        .init(index: 2, title: "亮丽HDR 🌅", tonePreset: nil, gammaPreset: 7, sectPreset: 3, tone: 14, gamma: 7, saturation: 1, red: 1, green: 1, blue: 1, hdrPlus: 14.5, hdrMinus: -3.5, frameCount: 0, zslFrameCount: 0, nsFrameCount: 0, denoise: 0.46875, sharp: 1.35),
        .init(index: 3, title: "夜色花火 🎆", tonePreset: nil, gammaPreset: nil, sectPreset: nil, tone: 15, gamma: 8, saturation: 1, red: 1, green: 1, blue: 1, hdrPlus: 5, hdrMinus: -3, frameCount: 0, zslFrameCount: 0, nsFrameCount: 0, denoise: 0.46875, sharp: 0),
        .init(index: 4, title: "数码CCD 📸", tonePreset: 8, gammaPreset: 3, sectPreset: nil, tone: 8, gamma: 3, saturation: 1.15, red: 1.04, green: 1.06, blue: 1.26, hdrPlus: 15, hdrMinus: -0.875, frameCount: 0, zslFrameCount: 0, nsFrameCount: 0, denoise: 0.46875, sharp: 0.6),
        .init(index: 5, title: "运动抓拍 🚴‍♂️", tonePreset: 8, gammaPreset: 3, sectPreset: 3, tone: 32, gamma: 11, saturation: 1, red: 0.92, green: 1.02, blue: 1, hdrPlus: 14.5, hdrMinus: -2, frameCount: 5, zslFrameCount: 7, nsFrameCount: 5, denoise: 0.46875, sharp: 0),
        .init(index: 6, title: "鲜艳徕卡 🌈", tonePreset: 8, gammaPreset: 3, sectPreset: 3, tone: 15, gamma: 8, saturation: 1.1, red: 1.02, green: 1, blue: 0.96, hdrPlus: 14.5, hdrMinus: -1.25, frameCount: 0, zslFrameCount: 0, nsFrameCount: 0, denoise: 0.46875, sharp: 0),
        .init(index: 7, title: "复古徕卡 📽", tonePreset: 19, gammaPreset: 7, sectPreset: 2, tone: 15, gamma: 8, saturation: 0.9, red: 1.04, green: 1.02, blue: 1.04, hdrPlus: 3.5, hdrMinus: -2, frameCount: 0, zslFrameCount: 0, nsFrameCount: 0, denoise: 0.46875, sharp: 1.4),
        .init(index: 8, title: "金属徕卡 ⚓️", tonePreset: nil, gammaPreset: nil, sectPreset: nil, tone: 2, gamma: 3, saturation: 1, red: 1.08, green: 1, blue: 0.92, hdrPlus: 10.5, hdrMinus: -0.25, frameCount: 0, zslFrameCount: 0, nsFrameCount: 0, denoise: 0.46875, sharp: 0.9),
        .init(index: 9, title: "糖果轻颜 🧝‍♀️", tonePreset: nil, gammaPreset: 7, sectPreset: 3, tone: 2, gamma: 11, saturation: 1.15, red: 0.94, green: 1.16, blue: 1.12, hdrPlus: 7, hdrMinus: -1.75, frameCount: 28, zslFrameCount: 12, nsFrameCount: 0, denoise: 0.46875, sharp: 0),
        .init(index: 10, title: "普罗维亚 🌆", tonePreset: 19, gammaPreset: 7, sectPreset: 2, tone: 2, gamma: 8, saturation: 0.85, red: 1.32, green: 1.32, blue: 1.08, hdrPlus: 7, hdrMinus: -1.5, frameCount: 0, zslFrameCount: 0, nsFrameCount: 0, denoise: 0.46875, sharp: 0.35),
        .init(index: 11, title: "浪漫电影 🎊", tonePreset: 8, gammaPreset: 3, sectPreset: nil, tone: 28, gamma: 7, saturation: 1.06, red: 1.06, green: 0.84, blue: 0.74, hdrPlus: 14.5, hdrMinus: -1.5, frameCount: 0, zslFrameCount: 0, nsFrameCount: 0, denoise: 0.46875, sharp: 1.1),
        .init(index: 12, title: "暗调负片 🎞", tonePreset: 19, gammaPreset: 7, sectPreset: 2, tone: 15, gamma: 8, saturation: 0.75, red: 0.98, green: 0.8, blue: 1.18, hdrPlus: 10.5, hdrMinus: 1.25, frameCount: 0, zslFrameCount: 0, nsFrameCount: 0, denoise: 0.46875, sharp: 0.45),
        .init(index: 13, title: "柯达多彩 🌸", tonePreset: 19, gammaPreset: 7, sectPreset: 2, tone: 15, gamma: 8, saturation: 1, red: 0.8, green: 1, blue: 0.8, hdrPlus: 3.5, hdrMinus: -9, frameCount: 0, zslFrameCount: 0, nsFrameCount: 0, denoise: 0.46875, sharp: 0.45),
        .init(index: 14, title: "日光胶片 ☀️", tonePreset: 19, gammaPreset: 7, sectPreset: 2, tone: 15, gamma: 8, saturation: 0.75, red: 0.94, green: 1.16, blue: 1.14, hdrPlus: 16, hdrMinus: -0.625, frameCount: 0, zslFrameCount: 0, nsFrameCount: 0, denoise: 0.46875, sharp: 0.45),
        .init(index: 15, title: "LUT+超细节", tonePreset: 19, gammaPreset: 7, sectPreset: 2, tone: 15, gamma: 8, saturation: 1, red: 1, green: 1, blue: 1, hdrPlus: 5, hdrMinus: -3, frameCount: 0, zslFrameCount: 50, nsFrameCount: 0, denoise: 0.46875, sharp: 0),
        .init(index: 16, title: "LUT+低动态", tonePreset: 19, gammaPreset: 7, sectPreset: 2, tone: 15, gamma: 8, saturation: 0.9, red: 1, green: 1, blue: 1, hdrPlus: 6.5, hdrMinus: -0.375, frameCount: 0, zslFrameCount: 0, nsFrameCount: 0, denoise: 0.46875, sharp: 0),
        .init(index: 17, title: "LUT+高动态", tonePreset: 19, gammaPreset: 7, sectPreset: 2, tone: 22, gamma: 1, saturation: 1.15, red: 1, green: 1, blue: 1, hdrPlus: 6, hdrMinus: -2, frameCount: 0, zslFrameCount: 0, nsFrameCount: 0, denoise: 0.46875, sharp: 0.375)
    ]

    static let shadowChasing: [CameraPreset] = definitions.map { d in
        let warmth = Float(max(-12, min(12, Double(d.red - d.blue) * 8.0)))
        let tint = Float(max(-8, min(8, Double(d.green - (d.red + d.blue) / 2.0) * 7.0)))
        let exposure = Float(max(-0.8, min(0.8, (Double(d.tone) - 15.0) * 0.008 + (Double(d.gamma) - 8.0) * 0.006)))
        let highlights = Float(max(0.12, min(0.92, 0.84 - Double(d.hdrPlus) * 0.032)))
        let shadows = Float(max(0.06, min(0.82, 0.18 + abs(Double(d.hdrMinus)) * 0.065)))
        let contrast = Float(max(0.78, min(1.42, 0.94 + (d.tonePreset == 19 ? 0.07 : 0) + abs(Double(d.hdrMinus)) * 0.010)))
        let sharp = Float(max(0.06, min(0.92, Double(d.sharp))))

        let render = AGCRenderProfile(
            index: d.index,
            title: d.title,
            red: d.red,
            green: d.green,
            blue: d.blue,
            saturation: d.saturation,
            contrast2: nil,
            blackLevel: nil,
            hdrPlus: d.hdrPlus,
            hdrMinus: d.hdrMinus,
            frameCount: d.frameCount,
            zslFrameCount: d.zslFrameCount,
            nsFrameCount: d.nsFrameCount,
            sharpGain: d.sharp,
            darkerExposure: nil,
            tonePreset: d.tonePreset,
            gammaPreset: d.gammaPreset,
            lutIndex: 0,
            toneCurve: [],
            gammaCurve: []
        )

        return CameraPreset(
            id: "agc-shadowchasing-\(d.index)",
            brand: "AGC",
            model: d.title,
            lens: "影踪追寻 · 通用配置",
            focal: "主摄",
            aperture: "自动",
            iso: "自动",
            shutter: "自动",
            style: "AGC",
            exposure: exposure,
            saturation: d.saturation,
            contrast: contrast,
            highlights: highlights,
            shadows: shadows,
            sharpness: sharp,
            warmth: warmth,
            tint: tint,
            channelBias: 0,
            exifMake: "安卓配置",
            exifModel: d.title,
            watermarkLayout: .verticalLeft,
            watermarkBrand: "LEICA",
            agcProfile: render
        )
    }
}

//// MARK: - 相机引擎

@MainActor
final class CameraEngine: NSObject, ObservableObject {
    let session = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()

    @Published var ready = false
    @Published var isCapturing = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    private var processingCount = 0
    @Published var lastImage: UIImage?
    @Published var lastSavedURL: URL?
    @Published var proRAWSupported = false
    @Published var livePhotoSupported = false
    @Published private(set) var previewRotationAngle: CGFloat = 0

    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var previewRotationObservation: NSKeyValueObservation?

    var currentPresetForPreview: CameraPreset = PresetLibrary.all[0]

    private var currentInput: AVCaptureDeviceInput?
    private var delegates: [Int64: CaptureProcessorDelegate] = [:]
    private var orientationObserver: NSObjectProtocol?

    override init() {
        super.init()
        Task { await prepare() }
    }

    deinit {
        previewRotationObservation?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    private func prepare() async {
        let granted = await requestCamera()
        guard granted else {
            errorMessage = "没有相机权限，请到系统设置中允许“GCam 风格相机”使用相机。"
            return
        }
        configure()
    }

    private func requestCamera() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    private func configure() {
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

        if #available(iOS 17.0, *) {
            let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
            rotationCoordinator = coordinator
            previewRotationAngle = coordinator.videoRotationAngleForHorizonLevelPreview
            previewRotationObservation = coordinator.observe(
                \AVCaptureDevice.RotationCoordinator.videoRotationAngleForHorizonLevelPreview,
                options: [.initial, .new]
            ) { [weak self] coordinator, _ in
                let angle = coordinator.videoRotationAngleForHorizonLevelPreview
                Task { @MainActor in
                    self?.previewRotationAngle = angle
                }
            }
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
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
            proRAWSupported = photoOutput.isAppleProRAWEnabled || photoOutput.isAppleProRAWSupported
            if proRAWSupported {
                photoOutput.isAppleProRAWEnabled = true
            }
            livePhotoSupported = photoOutput.isLivePhotoCaptureSupported
            if livePhotoSupported {
                photoOutput.isLivePhotoCaptureEnabled = true
            }
        }

        session.commitConfiguration()
        updateCameraRotation()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async { self?.ready = true }
        }
    }

    func flipCamera() {
        guard let old = currentInput else { return }
        let position: AVCaptureDevice.Position = old.device.position == .back ? .front : .back
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
            let input = try? AVCaptureDeviceInput(device: device)
        else { return }

        session.beginConfiguration()
        session.removeInput(old)
        if session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
        }
        session.commitConfiguration()
        updateCameraRotation()
    }

    private func updateCameraRotation() {
        let fallback: CGFloat = 0
        let captureAngle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture ?? fallback
        let previewAngle = rotationCoordinator?.videoRotationAngleForHorizonLevelPreview ?? fallback
        previewRotationAngle = previewAngle

        // 自定义取景使用 AVCaptureVideoDataOutput；根据 Apple 的建议，
        // 不在连接层旋转每一帧，而是在取景渲染层做旋转。
        if let videoConnection = videoOutput.connection(with: .video),
           videoConnection.isVideoRotationAngleSupported(0) {
            videoConnection.videoRotationAngle = 0
        }

        if let photoConnection = photoOutput.connection(with: .video),
           photoConnection.isVideoRotationAngleSupported(captureAngle) {
            photoConnection.videoRotationAngle = captureAngle
        }
    }

    func capture(
        preset: CameraPreset,
        mode: CaptureMode,
        watermark: Bool,
        metadata: MetadataDraft,
        watermarkConfig: CustomWatermarkConfig = CustomWatermarkConfig()
    ) {
        guard ready, !isCapturing, !isProcessing else { return }
        isCapturing = true

        let settings: AVCapturePhotoSettings

        switch mode {
        case .photo:
            let codec: AVVideoCodecType = photoOutput.availablePhotoCodecTypes.contains(.hevc) ? .hevc : .jpeg
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: codec])

        case .proRAW:
            guard proRAWSupported,
                  let rawType = photoOutput.availableRawPhotoPixelFormatTypes.first(where: {
                      AVCapturePhotoOutput.isAppleProRAWPixelFormat($0)
                  }) else {
                isCapturing = false
                errorMessage = "当前 iPhone 或当前相机不支持专业 RAW。"
                return
            }
            let codec: AVVideoCodecType = photoOutput.availablePhotoCodecTypes.contains(.hevc) ? .hevc : .jpeg
            settings = AVCapturePhotoSettings(
                rawPixelFormatType: rawType,
                processedFormat: [AVVideoCodecKey: codec]
            )

        case .livePhoto:
            guard livePhotoSupported else {
                isCapturing = false
                errorMessage = "当前设备不支持实况照片。"
                return
            }
            let codec: AVVideoCodecType = photoOutput.availablePhotoCodecTypes.contains(.hevc) ? .hevc : .jpeg
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: codec])
            settings.livePhotoMovieFileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("GCamStyle-\(UUID().uuidString).mov")
        }

        settings.photoQualityPrioritization = .quality

        let delegate = CaptureProcessorDelegate(
            owner: self,
            settingsID: settings.uniqueID,
            preset: preset,
            mode: mode,
            watermark: watermark,
            metadata: metadata,
            watermarkConfig: watermarkConfig
        )

        delegates[settings.uniqueID] = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    private func beginProcessing() {
        processingCount += 1
        isProcessing = true
    }

    private func endProcessing() {
        processingCount = max(0, processingCount - 1)
        isProcessing = processingCount > 0
    }

    func clearPreview() {
        lastImage = nil
        lastSavedURL = nil
        errorMessage = nil
    }

    func importPhoto(
        _ data: Data,
        preset: CameraPreset,
        watermark: Bool,
        metadata: MetadataDraft,
        watermarkConfig: CustomWatermarkConfig = CustomWatermarkConfig()
    ) {
        beginProcessing()

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result {
                    try ExportService.renderToJPEG(
                        sourceData: data,
                        preset: preset,
                        watermark: watermark,
                        metadata: metadata,
                        watermarkConfig: watermarkConfig
                    )
                }
            }.value

            switch result {
            case .success(let url):
                do {
                    self.lastImage = try PreviewImageFactory.makeThumbnail(from: url, maxPixel: 1600)
                    self.lastSavedURL = url
                    await PhotoSaver.saveJPEG(url: url)
                } catch {
                    self.errorMessage = "照片处理失败：\(error.localizedDescription)"
                }
            case .failure(let error):
                self.errorMessage = "照片处理失败：\(error.localizedDescription)"
            }

            self.endProcessing()
        }
    }

    func showProcessedStill(
        data: Data,
        preset: CameraPreset,
        watermark: Bool,
        metadata: MetadataDraft,
        watermarkConfig: CustomWatermarkConfig = CustomWatermarkConfig()
    ) {
        beginProcessing()

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result {
                    try ExportService.renderToJPEG(
                        sourceData: data,
                        preset: preset,
                        watermark: watermark,
                        metadata: metadata,
                        watermarkConfig: watermarkConfig
                    )
                }
            }.value

            switch result {
            case .success(let url):
                do {
                    self.lastImage = try PreviewImageFactory.makeThumbnail(from: url, maxPixel: 1600)
                    self.lastSavedURL = url
                    await PhotoSaver.saveJPEG(url: url)
                } catch {
                    self.errorMessage = "照片预览生成失败：\(error.localizedDescription)"
                }
            case .failure(let error):
                self.errorMessage = "照片导出失败：\(error.localizedDescription)"
            }

            self.endProcessing()
        }
    }

    fileprivate func finish(id: Int64) {
        delegates[id] = nil
        isCapturing = false
    }

    fileprivate func handleRaw(
        data: Data,
        preset: CameraPreset,
        watermark: Bool,
        metadata: MetadataDraft,
        watermarkConfig: CustomWatermarkConfig
    ) {
        beginProcessing()

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result {
                    let rawURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("风格相机-原片-\(UUID().uuidString).dng")
                    try data.write(to: rawURL, options: .atomic)

                    guard let rawFilter = CIRAWFilter(imageURL: rawURL) else {
                        throw NSError(domain: "GCamStyle", code: 30, userInfo: [
                            NSLocalizedDescriptionKey: "原片已保存，但当前设备无法开发此原片。"
                        ])
                    }

                    rawFilter.isDraftModeEnabled = false
                    rawFilter.exposure = preset.exposure
                    if rawFilter.isLensCorrectionSupported { rawFilter.isLensCorrectionEnabled = true }
                    if rawFilter.isLuminanceNoiseReductionSupported { rawFilter.luminanceNoiseReductionAmount = 0.45 }
                    if rawFilter.isColorNoiseReductionSupported { rawFilter.colorNoiseReductionAmount = 0.30 }
                    if rawFilter.isSharpnessSupported {
                        rawFilter.sharpnessAmount = min(1, max(0.05, preset.sharpness))
                    }

                    guard let rawImage = rawFilter.outputImage else {
                        throw NSError(domain: "GCamStyle", code: 31, userInfo: [
                            NSLocalizedDescriptionKey: "原片开发失败。"
                        ])
                    }

                    let styled = PhotoProcessor.applyLook(rawImage, preset: preset)
                    let context = CIContext()
                    guard let cg = context.createCGImage(styled, from: styled.extent) else {
                        throw NSError(domain: "GCamStyle", code: 32, userInfo: [
                            NSLocalizedDescriptionKey: "原片风格渲染失败。"
                        ])
                    }

                    let styledURL = try ExportService.writeRenderedJPEG(
                        cgImage: cg,
                        preset: preset,
                        metadata: metadata,
                        watermark: watermark,
                        watermarkConfig: watermarkConfig,
                        sourceProperties: [:]
                    )

                    return (rawURL, styledURL)
                }
            }.value

            switch result {
            case .success(let urls):
                await PhotoSaver.saveRAW(url: urls.0)
                await PhotoSaver.saveJPEG(url: urls.1)
                do {
                    self.lastImage = try PreviewImageFactory.makeThumbnail(from: urls.1, maxPixel: 1600)
                    self.lastSavedURL = urls.1
                    self.errorMessage = "原片和风格化照片都已保存。"
                } catch {
                    self.errorMessage = "原片已保存，但预览生成失败。"
                }
            case .failure(let error):
                self.errorMessage = "原片处理失败：\(error.localizedDescription)"
            }

            self.endProcessing()
        }
    }

    fileprivate func handleLivePhoto(
        stillData: Data,
        movieURL: URL,
        preset: CameraPreset,
        watermark: Bool,
        metadata: MetadataDraft,
        watermarkConfig: CustomWatermarkConfig
    ) {
        beginProcessing()

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result {
                    let originalStillURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("风格相机-实况原图-\(UUID().uuidString).jpg")
                    try stillData.write(to: originalStillURL, options: .atomic)

                    let styledURL = try ExportService.renderToJPEG(
                        sourceData: stillData,
                        preset: preset,
                        watermark: watermark,
                        metadata: metadata,
                        watermarkConfig: watermarkConfig
                    )

                    return (originalStillURL, styledURL)
                }
            }.value

            switch result {
            case .success(let urls):
                // 保留 AVFoundation 原始静态图 + 原始视频的配对信息；
                // 风格化照片单独保存，避免破坏实况照片的配对标识。
                await PhotoSaver.saveLivePhoto(stillURL: urls.0, movieURL: movieURL)
                await PhotoSaver.saveJPEG(url: urls.1)

                do {
                    self.lastImage = try PreviewImageFactory.makeThumbnail(from: urls.1, maxPixel: 1600)
                    self.lastSavedURL = urls.1
                } catch {
                    self.errorMessage = "实况照片已保存，但预览生成失败。"
                }

            case .failure(let error):
                self.errorMessage = "实况照片处理失败：\(error.localizedDescription)"
            }

            self.endProcessing()
        }
    }

}

// MARK: - 拍照代理

final class CaptureProcessorDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    weak var owner: CameraEngine?
    let settingsID: Int64
    let preset: CameraPreset
    let mode: CaptureMode
    let watermark: Bool
    let metadata: MetadataDraft
    let watermarkConfig: CustomWatermarkConfig

    private var processedData: Data?
    private var rawData: Data?
    private var liveMovieURL: URL?

    init(
        owner: CameraEngine,
        settingsID: Int64,
        preset: CameraPreset,
        mode: CaptureMode,
        watermark: Bool,
        metadata: MetadataDraft,
        watermarkConfig: CustomWatermarkConfig
    ) {
        self.owner = owner
        self.settingsID = settingsID
        self.preset = preset
        self.mode = mode
        self.watermark = watermark
        self.metadata = metadata
        self.watermarkConfig = watermarkConfig
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
                        metadata: self.metadata,
                        watermarkConfig: self.watermarkConfig
                    )
                } else {
                    owner.showProcessedStill(
                        data: processedData,
                        preset: self.preset,
                        watermark: self.watermark,
                        metadata: self.metadata,
                        watermarkConfig: self.watermarkConfig
                    )
                }
            }

            if let rawData = self.rawData {
                owner.handleRaw(
                    data: rawData,
                    preset: self.preset,
                    watermark: self.watermark,
                    metadata: self.metadata,
                    watermarkConfig: self.watermarkConfig
                )
            }

            owner.finish(id: self.settingsID)
        }
    }
}

// MARK: - 实时取景

final class LivePreviewView: MTKView, AVCaptureVideoDataOutputSampleBufferDelegate {
    var activePreset: CameraPreset = PresetLibrary.all[0]
    var isFrozen = false
    var rotationAngle: CGFloat = 0

    private let commandQueue: MTLCommandQueue
    private let ciContext: CIContext
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private let frameLock = NSLock()
    private var latestImage: CIImage?
    private var lastSubmit: CFTimeInterval = 0

    init(frame: CGRect = .zero) {
        let device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()!
        ciContext = CIContext(mtlDevice: device)
        super.init(frame: frame, device: device)
        framebufferOnly = false
        enableSetNeedsDisplay = false
        isPaused = true
        autoResizeDrawable = true
    }

    required init(coder: NSCoder) {
        fatalError("不支持故事板初始化")
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !isFrozen else { return }

        let now = CACurrentMediaTime()
        guard now - lastSubmit > (1.0 / 18.0) else { return }
        lastSubmit = now

        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // 方向由相机连接统一处理，避免取景层二次旋转。
        var source = CIImage(cvPixelBuffer: buffer)
        if abs(rotationAngle) > 0.5 {
            source = source.transformed(by: CGAffineTransform(rotationAngle: rotationAngle * .pi / 180.0))
        }

        let maxDimension = max(source.extent.width, source.extent.height)
        if maxDimension > 1280 {
            let scale = 1280 / maxDimension
            source = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }

        let styled = PhotoProcessor.applyPreviewLook(source, preset: activePreset)

        frameLock.lock()
        latestImage = styled
        frameLock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.draw()
        }
    }

    override func draw(_ rect: CGRect) {
        frameLock.lock()
        let image = latestImage
        frameLock.unlock()
        guard let image, let drawable = currentDrawable else { return }

        let target = CGSize(width: drawableSize.width, height: drawableSize.height)
        let extent = image.extent
        let scale = max(target.width / extent.width, target.height / extent.height)
        var fitted = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let dx = (target.width - fitted.extent.width) * 0.5 - fitted.extent.minX
        let dy = (target.height - fitted.extent.height) * 0.5 - fitted.extent.minY
        fitted = fitted.transformed(by: CGAffineTransform(translationX: dx, y: dy))

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
    let isFrozen: Bool
    let rotationAngle: CGFloat

    func makeUIView(context: Context) -> LivePreviewView {
        let view = LivePreviewView()
        view.activePreset = preset
        view.isFrozen = isFrozen
        view.rotationAngle = rotationAngle
        output.setSampleBufferDelegate(view, queue: DispatchQueue(label: "GCamStyle.preview", qos: .userInitiated))
        return view
    }

    func updateUIView(_ uiView: LivePreviewView, context: Context) {
        uiView.activePreset = preset
        uiView.isFrozen = isFrozen
        uiView.rotationAngle = rotationAngle
    }
}

// MARK: - 图像处理

enum PhotoProcessor {
    static func applyPreviewLook(_ input: CIImage, preset: CameraPreset) -> CIImage {
        let exposure = CIFilter.exposureAdjust()
        exposure.inputImage = input
        exposure.ev = preset.exposure

        let controls = CIFilter.colorControls()
        controls.inputImage = exposure.outputImage ?? input
        controls.saturation = preset.saturation
        controls.contrast = preset.contrast
        controls.brightness = 0

        var output = controls.outputImage ?? input

        if let agc = preset.agcProfile {
            output = applyAGCTone(output, tonePreset: agc.tonePreset, amount: agc.gammaPreset ?? 0, gammaValue: agc.gammaPreset ?? 0)

            let matrix = CIFilter.colorMatrix()
            matrix.inputImage = output
            matrix.rVector = CIVector(x: CGFloat(agc.red), y: 0, z: 0, w: 0)
            matrix.gVector = CIVector(x: 0, y: CGFloat(agc.green), z: 0, w: 0)
            matrix.bVector = CIVector(x: 0, y: 0, z: CGFloat(agc.blue), w: 0)
            matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            output = matrix.outputImage ?? output

            if let g = agc.gammaPreset {
                let gamma = CIFilter.gammaAdjust()
                gamma.inputImage = output
                gamma.power = max(0.78, min(1.24, 1.0 + Float(g - 5) * 0.016))
                output = gamma.outputImage ?? output
            }
        }

        if let lut = LUTStore.shared.current {
            output = applyLUT(output, lut: lut)
        }
        return output
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

        if let agc = preset.agcProfile {
            let matrix = CIFilter.colorMatrix()
            matrix.inputImage = current
            matrix.rVector = CIVector(x: CGFloat(agc.red), y: 0, z: 0, w: 0)
            matrix.gVector = CIVector(x: 0, y: CGFloat(agc.green), z: 0, w: 0)
            matrix.bVector = CIVector(x: 0, y: 0, z: CGFloat(agc.blue), w: 0)
            matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            current = matrix.outputImage ?? current

            current = applyAGCTone(current, tonePreset: agc.tonePreset, amount: agc.gammaPreset ?? 0, gammaValue: agc.gammaPreset ?? 0)

            if let black = agc.blackLevel {
                let lifted = CIFilter.colorControls()
                lifted.inputImage = current
                lifted.brightness = clampAGC(black)
                lifted.saturation = 1
                lifted.contrast = 1
                current = lifted.outputImage ?? current
            }

            if let g = agc.gammaPreset {
                let gamma = CIFilter.gammaAdjust()
                gamma.inputImage = current
                gamma.power = max(0.78, min(1.24, 1.0 + Float(g - 5) * 0.016))
                current = gamma.outputImage ?? current
            }

            if !agc.toneCurve.isEmpty {
                current = applyOneDimensionalCurve(current, points: agc.toneCurve)
            }
            if !agc.gammaCurve.isEmpty {
                current = applyOneDimensionalCurve(current, points: agc.gammaCurve)
            }
        }

        let hs = CIFilter.highlightShadowAdjust()
        hs.inputImage = current
        hs.highlightAmount = preset.highlights
        hs.shadowAmount = preset.shadows
        current = hs.outputImage ?? current

        let temperature = CIFilter.temperatureAndTint()
        temperature.inputImage = current
        temperature.neutral = CIVector(x: 6500, y: 0)
        temperature.targetNeutral = CIVector(
            x: CGFloat(6500 + preset.warmth * 90),
            y: CGFloat(preset.tint * 8)
        )
        current = temperature.outputImage ?? current

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = current
        sharpen.sharpness = preset.sharpness
        current = sharpen.outputImage ?? current

        if let lut = LUTStore.shared.current {
            current = applyLUT(current, lut: lut)
        }
        return current
    }

    private static func applyAGCTone(
        _ image: CIImage,
        tonePreset: Int?,
        amount: Int,
        gammaValue: Int
    ) -> CIImage {
        guard let filter = CIFilter(name: "CIToneCurve") else { return image }

        let points: [(CGFloat, CGFloat)]
        switch tonePreset ?? 8 {
        case 19:
            // AGC 影踪追寻中大量胶片/负片 Profile 使用的 19 号曲线：
            // 保留黑位，同时让中间调更有层次，高光柔和收尾。
            points = [
                (0.00, 0.015),
                (0.25, 0.205),
                (0.50, 0.515),
                (0.75, 0.805),
                (1.00, 0.975)
            ]
        case 8:
            points = [
                (0.00, 0.008),
                (0.25, 0.225),
                (0.50, 0.500),
                (0.75, 0.785),
                (1.00, 0.990)
            ]
        case 2:
            points = [
                (0.00, 0.02),
                (0.25, 0.19),
                (0.50, 0.49),
                (0.75, 0.82),
                (1.00, 0.995)
            ]
        default:
            points = [
                (0.00, 0.01),
                (0.25, 0.225),
                (0.50, 0.50),
                (0.75, 0.78),
                (1.00, 0.99)
            ]
        }

        let strength = CGFloat(max(0.35, min(1.20, Double(abs(amount)) / 8.0 + 0.35)))
        let center = 0.50 + (points[2].1 - 0.50) * (strength - 0.35) * 0.20
        let p2 = CIVector(x: 0.50, y: center)

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: points[0].0, y: points[0].1), forKey: "inputPoint0")
        filter.setValue(CIVector(x: points[1].0, y: points[1].1), forKey: "inputPoint1")
        filter.setValue(p2, forKey: "inputPoint2")
        filter.setValue(CIVector(x: points[3].0, y: points[3].1), forKey: "inputPoint3")
        filter.setValue(CIVector(x: points[4].0, y: points[4].1), forKey: "inputPoint4")
        return filter.outputImage ?? image
    }

    private static func clampAGC(_ value: Float) -> Float {
        // AGC 的黑位/对比参数并不是 iOS brightness 的同一量纲；
        // 使用一个很小的可解释映射，避免把画面直接推爆。
        return max(-0.18, min(0.18, (value - 0.85) * 0.035))
    }

    private static func applyOneDimensionalCurve(_ image: CIImage, points: [Float]) -> CIImage {
        guard points.count >= 2 else { return image }
        let dimension = 32
        var cube = [Float]()
        cube.reserveCapacity(dimension * dimension * dimension * 4)

        for z in 0..<dimension {
            let b = Float(z) / Float(dimension - 1)
            for y in 0..<dimension {
                let g = Float(y) / Float(dimension - 1)
                for x in 0..<dimension {
                    let r = Float(x) / Float(dimension - 1)
                    let rr = sampleCurve(points, r)
                    let gg = sampleCurve(points, g)
                    let bb = sampleCurve(points, b)
                    cube.append(rr)
                    cube.append(gg)
                    cube.append(bb)
                    cube.append(1)
                }
            }
        }

        let data = cube.withUnsafeBufferPointer { Data(buffer: $0) }
        guard let filter = CIFilter(name: "CIColorCube") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(dimension, forKey: "inputCubeDimension")
        filter.setValue(data, forKey: "inputCubeData")
        return filter.outputImage ?? image
    }

    private static func sampleCurve(_ points: [Float], _ value: Float) -> Float {
        let x = max(0, min(1, value)) * Float(points.count - 1)
        let index = Int(floor(x))
        if index >= points.count - 1 { return points.last ?? value }
        let t = x - Float(index)
        return points[index] + (points[index + 1] - points[index]) * t
    }

    private static func applyLUT(_ image: CIImage, lut: LUT3D) -> CIImage {
        guard let filter = CIFilter(name: "CIColorCube") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(lut.dimension, forKey: "inputCubeDimension")
        filter.setValue(lut.cubeData, forKey: "inputCubeData")
        return filter.outputImage ?? image
    }
}

// MARK: - 导出 / EXIF

enum ExportService {
    static func renderToJPEG(
        sourceData: Data,
        preset: CameraPreset,
        watermark: Bool,
        metadata: MetadataDraft,
        watermarkConfig: CustomWatermarkConfig = CustomWatermarkConfig()
    ) throws -> URL {
        guard
            let source = CGImageSourceCreateWithData(sourceData as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw NSError(domain: "GCamStyle", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "无法读取照片。"
            ])
        }

        let input = CIImage(cgImage: image)
        let styled = PhotoProcessor.applyLook(input, preset: preset)
        let context = CIContext()

        guard let styledCG = context.createCGImage(styled, from: styled.extent) else {
            throw NSError(domain: "GCamStyle", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "风格渲染失败。"
            ])
        }

        let sourceProperties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]) ?? [:]

        return try writeRenderedJPEG(
            cgImage: styledCG,
            preset: preset,
            metadata: metadata,
            watermark: watermark,
            watermarkConfig: watermarkConfig,
            sourceProperties: sourceProperties
        )
    }

    static func writeRenderedJPEG(
        cgImage: CGImage,
        preset: CameraPreset,
        metadata: MetadataDraft,
        watermark: Bool,
        watermarkConfig: CustomWatermarkConfig,
        sourceProperties: [String: Any]
    ) throws -> URL {
        var properties = sourceProperties

        var tiff = (properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]) ?? [:]
        tiff[kCGImagePropertyTIFFMake as String] = metadata.make.isEmpty ? preset.exifMake : metadata.make
        tiff[kCGImagePropertyTIFFModel as String] = metadata.model.isEmpty ? preset.exifModel : metadata.model
        tiff[kCGImagePropertyTIFFSoftware as String] = metadata.software
        if !metadata.artist.isEmpty { tiff[kCGImagePropertyTIFFArtist as String] = metadata.artist }
        if !metadata.copyright.isEmpty { tiff[kCGImagePropertyTIFFCopyright as String] = metadata.copyright }
        properties[kCGImagePropertyTIFFDictionary as String] = tiff

        var exif = (properties[kCGImagePropertyExifDictionary as String] as? [String: Any]) ?? [:]
        exif[kCGImagePropertyExifFocalLength as String] =
            Double(preset.focal.replacingOccurrences(of: "mm", with: "")) ?? 28
        exif[kCGImagePropertyExifFNumber as String] =
            Double(preset.aperture.replacingOccurrences(of: "F", with: "")) ?? 1.8
        exif[kCGImagePropertyExifISOSpeedRatings as String] =
            [Int(preset.iso.replacingOccurrences(of: "ISO ", with: "")) ?? 100]
        if !metadata.lens.isEmpty { exif[kCGImagePropertyExifLensModel as String] = metadata.lens }
        if !metadata.dateOriginal.isEmpty { exif[kCGImagePropertyExifDateTimeOriginal as String] = metadata.dateOriginal }
        properties[kCGImagePropertyExifDictionary as String] = exif

        if metadata.stripGPS {
            properties.removeValue(forKey: kCGImagePropertyGPSDictionary as String)
        }

        let watermarked = watermark
            ? WatermarkRenderer.draw(on: cgImage, preset: preset, config: watermarkConfig)
            : UIImage(cgImage: cgImage)
        let finalImage: CGImage = watermarked.cgImage ?? cgImage
        let framedImage = FrameRenderer.apply(to: finalImage, style: watermarkConfig.frame, width: CGFloat(watermarkConfig.frameWidth))
        let exportImage = framedImage

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GCamStyle-\(UUID().uuidString).jpg")

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "GCamStyle", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "无法创建 JPEG。"
            ])
        }

        CGImageDestinationAddImage(destination, exportImage, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "GCamStyle", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "JPEG 导出失败。"
            ])
        }

        return url
    }
}

// MARK: - 水印

enum WatermarkRenderer {
    static func draw(on cgImage: CGImage, preset: CameraPreset, config: CustomWatermarkConfig = CustomWatermarkConfig()) -> UIImage {
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))

            let titleFont = UIFont.systemFont(ofSize: max(20, size.width / 58), weight: .bold)
            let infoFont = UIFont.monospacedSystemFont(ofSize: max(12, size.width / 94), weight: .medium)
            let accent = preset.watermarkAccent

            let titleText: String
            if !config.title.isEmpty {
                titleText = config.title
            } else if config.usePresetBrand {
                titleText = "\(preset.brand)  \(preset.model)"
            } else {
                titleText = ""
            }

            let parameterText = "\(preset.lens)   \(preset.focal)   \(preset.aperture)   \(preset.shutter)   \(preset.iso)"
            let subtitleText = config.subtitle.isEmpty ? parameterText : config.subtitle
            let footerText: String
            if !config.customFooter.isEmpty {
                footerText = config.customFooter
            } else if config.showParameters {
                footerText = subtitleText
            } else {
                footerText = ""
            }

            let opacity = CGFloat(min(0.95, max(0.15, config.opacity)))
            let selectedLayout: CustomWatermarkLayout
            if config.isCustomized {
                selectedLayout = config.layout
            } else {
                switch preset.watermarkLayout {
                case .verticalLeft: selectedLayout = .verticalLeft
                case .verticalRight: selectedLayout = .verticalRight
                case .bottomBand: selectedLayout = .bottom
                case .bottomMinimal: selectedLayout = .minimal
                case .topRight: selectedLayout = .topRight
                case .split: selectedLayout = .split
                }
            }

            if config.usePresetBrand && config.title.isEmpty {
                // 使用预设品牌与机型。
            }

            switch selectedLayout {
            case .verticalLeft:
                drawCustomVertical(ctx: ctx.cgContext, size: size, title: titleText, subtitle: footerText, x: 18, fromLeft: true, titleFont: titleFont, infoFont: infoFont, accent: accent, opacity: opacity)
            case .verticalRight:
                drawCustomVertical(ctx: ctx.cgContext, size: size, title: titleText, subtitle: footerText, x: size.width - 18, fromLeft: false, titleFont: titleFont, infoFont: infoFont, accent: accent, opacity: opacity)
            case .bottom:
                drawCustomBottom(ctx: ctx.cgContext, size: size, title: titleText, subtitle: footerText, titleFont: titleFont, infoFont: infoFont, accent: accent, opacity: opacity, band: true)
            case .minimal:
                drawCustomBottom(ctx: ctx.cgContext, size: size, title: titleText, subtitle: footerText, titleFont: titleFont, infoFont: infoFont, accent: accent, opacity: opacity, band: false)
            case .topRight:
                let x = size.width - min(size.width * 0.55, 650)
                let y = max(22, size.height * 0.028)
                UIColor.black.withAlphaComponent(opacity * 0.80).setFill()
                ctx.cgContext.fill(CGRect(x: x - 18, y: y - 12, width: min(size.width * 0.55, 650), height: 104))
                (titleText as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: titleFont, .foregroundColor: UIColor.white])
                if config.showParameters || !config.subtitle.isEmpty || !config.customFooter.isEmpty {
                    (footerText as NSString).draw(at: CGPoint(x: x, y: y + titleFont.lineHeight + 8), withAttributes: [.font: infoFont, .foregroundColor: UIColor.white.withAlphaComponent(0.88)])
                }
            case .split:
                let y = size.height - max(92, size.height * 0.082)
                let line = UIBezierPath()
                line.move(to: CGPoint(x: 24, y: y - 12))
                line.addLine(to: CGPoint(x: size.width - 24, y: y - 12))
                accent.setStroke()
                line.lineWidth = 3
                line.stroke()
                (titleText as NSString).draw(at: CGPoint(x: 24, y: y), withAttributes: [.font: titleFont, .foregroundColor: UIColor.white])
                if config.showParameters || !config.subtitle.isEmpty || !config.customFooter.isEmpty {
                    (footerText as NSString).draw(at: CGPoint(x: 24, y: y + titleFont.lineHeight + 8), withAttributes: [.font: infoFont, .foregroundColor: UIColor.white.withAlphaComponent(0.86)])
                }
            }
        }
    }

    private static func drawCustomBottom(
        ctx: CGContext,
        size: CGSize,
        title: String,
        subtitle: String,
        titleFont: UIFont,
        infoFont: UIFont,
        accent: UIColor,
        opacity: CGFloat,
        band: Bool
    ) {
        let h = band ? max(106, size.height * 0.095) : max(84, size.height * 0.075)
        let y = size.height - h
        if band {
            UIColor.black.withAlphaComponent(opacity).setFill()
            ctx.fill(CGRect(x: 0, y: y, width: size.width, height: h))
        } else {
            UIColor.black.withAlphaComponent(opacity * 0.78).setFill()
            ctx.fill(CGRect(x: 0, y: y - 12, width: size.width, height: h + 12))
        }
        accent.setFill()
        ctx.fill(CGRect(x: 0, y: y, width: size.width, height: band ? 4 : 2))
        (title as NSString).draw(at: CGPoint(x: max(24, size.width * 0.028), y: y + 16), withAttributes: [.font: titleFont, .foregroundColor: UIColor.white])
        (subtitle as NSString).draw(at: CGPoint(x: max(24, size.width * 0.028), y: y + 18 + titleFont.lineHeight), withAttributes: [.font: infoFont, .foregroundColor: UIColor.white.withAlphaComponent(0.86)])
    }

    private static func drawCustomVertical(
        ctx: CGContext,
        size: CGSize,
        title: String,
        subtitle: String,
        x: CGFloat,
        fromLeft: Bool,
        titleFont: UIFont,
        infoFont: UIFont,
        accent: UIColor,
        opacity: CGFloat
    ) {
        let width = max(220, size.height * 0.34)
        let y = size.height * 0.10
        ctx.saveGState()

        if fromLeft {
            ctx.translateBy(x: x, y: y + width)
            ctx.rotate(by: -.pi / 2)
        } else {
            ctx.translateBy(x: x, y: y)
            ctx.rotate(by: .pi / 2)
        }

        UIColor.black.withAlphaComponent(opacity * 0.72).setFill()
        ctx.fill(CGRect(x: -14, y: 0, width: width + 24, height: 88))

        accent.setFill()
        ctx.fill(CGRect(x: -8, y: 0, width: 5, height: width))

        (title as NSString).draw(at: CGPoint(x: 10, y: 4), withAttributes: [.font: titleFont, .foregroundColor: UIColor.white])
        (subtitle as NSString).draw(at: CGPoint(x: 10, y: 8 + titleFont.lineHeight), withAttributes: [.font: infoFont, .foregroundColor: UIColor.white.withAlphaComponent(0.86)])

        ctx.restoreGState()
    }

    private static func drawVertical(
        ctx: CGContext,
        size: CGSize,
        preset: CameraPreset,
        x: CGFloat,
        fromLeft: Bool,
        titleFont: UIFont,
        infoFont: UIFont,
        accent: UIColor
    ) {
        let textSize = CGSize(width: max(200, size.height * 0.34), height: 90)
        let y = size.height * 0.10

        ctx.saveGState()
        if fromLeft {
            ctx.translateBy(x: x, y: y + textSize.width)
            ctx.rotate(by: -.pi / 2)
        } else {
            ctx.translateBy(x: x, y: y)
            ctx.rotate(by: .pi / 2)
        }

        accent.setFill()
        ctx.fill(CGRect(x: -8, y: 0, width: 5, height: textSize.width))

        let title = "\(preset.brand)  \(preset.model)" as NSString
        let info = "\(preset.lens)   \(preset.focal)   \(preset.aperture)   \(preset.shutter)   \(preset.iso)" as NSString

        title.draw(at: CGPoint(x: 10, y: 4), withAttributes: [.font: titleFont, .foregroundColor: UIColor.white])
        info.draw(at: CGPoint(x: 10, y: 8 + titleFont.lineHeight), withAttributes: [.font: infoFont, .foregroundColor: UIColor.white.withAlphaComponent(0.86)])

        ctx.restoreGState()
    }

    private static func drawBottomText(
        preset: CameraPreset,
        x: CGFloat,
        y: CGFloat,
        titleFont: UIFont,
        infoFont: UIFont
    ) {
        let title = "\(preset.brand)  \(preset.model)" as NSString
        let info = "\(preset.lens)   \(preset.focal)   \(preset.aperture)   \(preset.shutter)   \(preset.iso)" as NSString

        title.draw(at: CGPoint(x: x, y: y), withAttributes: [.font: titleFont, .foregroundColor: UIColor.white])
        info.draw(at: CGPoint(x: x, y: y + titleFont.lineHeight + 8), withAttributes: [.font: infoFont, .foregroundColor: UIColor.white.withAlphaComponent(0.86)])
    }
}

enum FrameRenderer {
    static func apply(to image: CGImage, style: CustomFrameStyle, width: CGFloat) -> CGImage {
        guard style != .none else { return image }

        let size = CGSize(width: image.width, height: image.height)
        let margin: CGFloat

        switch style {
        case .none: margin = 0
        case .thin: margin = max(8, width)
        case .bold: margin = max(18, width * 1.8)
        case .film: margin = max(24, width * 2.4)
        case .rounded: margin = max(18, width * 1.7)
        }

        let output = CGSize(width: size.width + margin * 2, height: size.height + margin * 2)
        let renderer = UIGraphicsImageRenderer(size: output)

        return renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: output))

            let photoRect = CGRect(x: margin, y: margin, width: size.width, height: size.height)

            if style == .rounded {
                let path = UIBezierPath(roundedRect: photoRect, cornerRadius: min(48, margin * 1.5))
                path.addClip()
            }

            UIImage(cgImage: image).draw(in: photoRect)

            let borderWidth = max(2, width / 2)
            if style == .film {
                UIColor.white.withAlphaComponent(0.90).setStroke()
                let border = UIBezierPath(rect: photoRect.insetBy(dx: borderWidth / 2, dy: borderWidth / 2))
                border.lineWidth = borderWidth
                border.stroke()

                let hole = max(8, margin * 0.25)
                UIColor.white.withAlphaComponent(0.85).setFill()
                for side in 0..<2 {
                    let x = side == 0 ? margin * 0.22 : output.width - margin * 0.22
                    var y: CGFloat = margin * 0.18
                    while y < output.height - margin * 0.18 {
                        ctx.fill(CGRect(x: x - hole / 2, y: y, width: hole, height: hole * 0.65))
                        y += hole * 1.65
                    }
                }
            } else {
                UIColor.white.withAlphaComponent(0.94).setStroke()
                let path = UIBezierPath(rect: photoRect.insetBy(dx: borderWidth / 2, dy: borderWidth / 2))
                path.lineWidth = borderWidth
                path.stroke()
            }
        }.cgImage ?? image
    }
}

// MARK: - 照片保存

enum PreviewImageFactory {
    static func makeThumbnail(from url: URL, maxPixel: Int) throws -> UIImage {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ] as CFDictionary
            )
        else {
            throw NSError(domain: "GCamStyle", code: 40, userInfo: [
                NSLocalizedDescriptionKey: "无法生成照片预览。"
            ])
        }
        return UIImage(cgImage: image)
    }
}

enum PhotoSaver {
    static func requestPermission() async -> Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited: return true
        case .notDetermined:
            return await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized
        default: return false
        }
    }

    static func saveJPEG(url: URL) async {
        guard await requestPermission() else { return }
        try? await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: url, options: nil)
        }
    }

    static func saveRAW(url: URL) async {
        guard await requestPermission() else { return }
        try? await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: url, options: nil)
        }
    }

    static func saveLivePhoto(stillURL: URL, movieURL: URL) async {
        guard await requestPermission() else { return }
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
    @StateObject private var agcStore = AGCStore()

    @State private var preset = AGCProfileLibrary.shadowChasing[0]
    @State private var mode: CaptureMode = .photo
    @State private var watermark = true
    @State private var metadata = MetadataDraft()
    @State private var showPresetPicker = false
    @State private var showSettings = false
    @State private var showAGCImporter = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var watermarkConfig = CustomWatermarkConfig()
    @State private var scene: ScenePreset = .photo
    @State private var showLUTImporter = false
    @State private var showLogoImporter = false
    @State private var activeLUTName = ""

    private var effectivePreset: CameraPreset { scene.applying(to: preset) }

    var allPresets: [CameraPreset] {
        agcStore.imported + PresetLibrary.all
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LiveCameraPreview(
                session: camera.session,
                output: camera.videoOutput,
                preset: effectivePreset,
                isFrozen: camera.isProcessing,
                rotationAngle: camera.previewRotationAngle
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.44), .clear, .black.opacity(0.72)],
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

            if camera.isProcessing {
                Color.black.opacity(0.42).ignoresSafeArea()
                VStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Text("正在处理照片…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                }
                .allowsHitTesting(true)
            } else if let image = camera.lastImage {
                previewOverlay(image)
            }
        }
        .sheet(isPresented: $showPresetPicker) {
            presetPicker
        }
        .sheet(isPresented: $showSettings) {
            settingsSheet
        }
        .fileImporter(
            isPresented: $showAGCImporter,
            allowedContentTypes: [
                .data,
                .xml
            ],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .failure(let error):
                camera.errorMessage = "安卓配置导入失败：\(error.localizedDescription)"
            case .success(let urls):
                guard !urls.isEmpty else { return }

                Task {
                    let loaded = await Task.detached(priority: .userInitiated) {
                        Result {
                            var allImported: [CameraPreset] = []
                            var names: [String] = []

                            for url in urls {
                                let accessing = url.startAccessingSecurityScopedResource()
                                defer { if accessing { url.stopAccessingSecurityScopedResource() } }

                                let data = try Data(contentsOf: url)
                                let config = try AGCXMLParser().parse(data)
                                let imported = AGCMapper.makePresets(from: config, fileName: url.lastPathComponent)

                                if !imported.isEmpty {
                                    allImported.append(contentsOf: imported)
                                    names.append(url.deletingPathExtension().lastPathComponent)
                                }
                            }

                            guard !allImported.isEmpty else {
                                throw NSError(
                                    domain: "GCamStyleAGC",
                                    code: 9,
                                    userInfo: [NSLocalizedDescriptionKey: "没有识别出可用的安卓配置档案。"]
                                )
                            }

                            return (allImported, names)
                        }
                    }.value

                    switch loaded {
                    case .success(let result):
                        agcStore.imported.insert(contentsOf: result.0, at: 0)
                        agcStore.sourceName = result.1.joined(separator: "、")
                        agcStore.enabled = true
                        preset = result.0[0]
                                camera.errorMessage = "已加载 \(result.0.count) 个安卓配置档案。"
                    case .failure(let error):
                        camera.errorMessage = "安卓配置导入失败：\(error.localizedDescription)"
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showLUTImporter,
            allowedContentTypes: [UTType(filenameExtension: "cube") ?? .text, .text],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let lut = try LUT3DParser.parse(Data(contentsOf: url), name: url.deletingPathExtension().lastPathComponent)
                LUTStore.shared.set(lut)
                activeLUTName = lut.name
            } catch {
                camera.errorMessage = "色彩曲线加载失败：(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $showLogoImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                guard UIImage(data: data) != nil else {
                    throw NSError(domain: "GCamStyle", code: 5, userInfo: [NSLocalizedDescriptionKey: "图片格式无法读取。"])
                }
                watermarkConfig.logoData = data
            } catch {
                camera.errorMessage = "自定义标志加载失败：(error.localizedDescription)"
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else { return }
                    camera.importPhoto(data, preset: effectivePreset, watermark: watermark, metadata: metadata, watermarkConfig: watermarkConfig)
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
            Button("知道了") { camera.errorMessage = nil }
        } message: {
            Text(camera.errorMessage ?? "")
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("谷歌相机风格")
                    .font(.system(size: 16, weight: .bold))
                Text("\(preset.displayBrand) · \(preset.model)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            Button {
                showPresetPicker = true
            } label: {
                HStack(spacing: 5) {
                    Text(preset.displayBrand)
                    Image(systemName: "chevron.down")
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.13)))
            }

            Button {
                showPresetPicker = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "folder.badge.plus")
                    Text("配置")
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.13)))
            }

            Button {
                showSettings = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "slider.horizontal.3")
                    Text("设置")
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.13)))
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 10)
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                ForEach([0.5, 1.0, 2.5, 5.0], id: \.self) { zoom in
                    Button {
                        camera.setZoom(CGFloat(zoom))
                    } label: {
                        Text(zoom == 1.0 ? "1×" : String(format: "%.1f×", zoom))
                            .font(.system(size: 11, weight: .bold))
                            .frame(minWidth: 46, minHeight: 34)
                            .background(
                                abs(camera.zoomFactor - CGFloat(zoom)) < 0.12
                                ? Color.white.opacity(0.94)
                                : Color.black.opacity(0.35),
                                in: Capsule()
                            )
                            .foregroundStyle(abs(camera.zoomFactor - CGFloat(zoom)) < 0.12 ? Color.black : Color.white)
                    }
                }

                Spacer()

                Button {
                    camera.isGridEnabled.toggle()
                } label: {
                    Image(systemName: camera.isGridEnabled ? "grid" : "grid.circle")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 38, height: 34)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Button {
                    camera.flipCamera()
                } label: {
                    Image(systemName: "camera.rotate")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 38, height: 34)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.horizontal, 16)


            HStack(spacing: 8) {
                ForEach(ScenePreset.allCases) { item in
                    Button {
                        scene = item
                    } label: {
                        Text(item.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(scene == item ? Color.white : Color.black.opacity(0.32), in: Capsule())
                            .foregroundStyle(scene == item ? Color.black : Color.white)
                    }
                }
            }

            HStack(spacing: 8) {
                ForEach(CaptureMode.allCases) { item in
                    Button {
                        if item == .proRAW && !camera.proRAWSupported { return }
                        if item == .livePhoto && !camera.livePhotoSupported { return }
                        mode = item
                    } label: {
                        Text(item.title)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                mode == item ? Color.white : Color.black.opacity(0.32),
                                in: Capsule()
                            )
                            .foregroundStyle(mode == item ? Color.black : Color.white)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(GCamProfile.allCases) { item in
                        Button {
                            profile = item
                        } label: {
                            Text(item.title)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(profile == item ? Color.white.opacity(0.94) : Color.black.opacity(0.30), in: Capsule())
                                .foregroundStyle(profile == item ? Color.black : Color.white)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PresetLibrary.brands, id: \.self) { brand in
                        Button {
                            if let item = PresetLibrary.all.first(where: { $0.brand == brand }) {
                                preset = item
                            }
                        } label: {
                            Text(itemBrandName(brand))
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(
                                    preset.brand == brand ? Color.white : Color.black.opacity(0.32),
                                    in: Capsule()
                                )
                                .foregroundStyle(preset.brand == brand ? Color.black : Color.white)
                        }
                    }

                    if !agcStore.imported.isEmpty {
                        Button {
                            if let item = agcStore.imported.first { preset = item }
                        } label: {
                            Text("已加载安卓配置")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule())
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
                }

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    camera.capture(
                        preset: effectivePreset,
                        mode: mode,
                        watermark: watermark,
                        metadata: metadata,
                        watermarkConfig: watermarkConfig
                    )
                } label: {
                    ZStack {
                        Circle().fill(.white.opacity(0.22)).frame(width: 84, height: 84)
                        Circle().fill(.white).frame(width: 68, height: 68)
                    }
                }
                .disabled(!camera.ready || camera.isCapturing || camera.isProcessing)

                Spacer()

                Button {
                    watermark.toggle()
                } label: {
                    Image(systemName: watermark ? "text.viewfinder" : "text.viewfinder.badge.magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding(.horizontal, 18)

            HStack {
                Text(scene.rawValue + (mode == .photo ? " · 实时风格 · 自动水印" : mode == .proRAW ? " · 保留专业原片" : " · 保留原始实况"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                Spacer()
                Text("\(effectivePreset.focal) · \(effectivePreset.aperture)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.70))
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .padding(.top, 7)
        .background(.black.opacity(0.24))
    }

    private func itemBrandName(_ brand: String) -> String {
        switch brand.uppercased() {
        case "LEICA": return "徕卡"
        case "HASSELBLAD": return "哈苏"
        case "ZEISS": return "蔡司"
        case "VIVO": return "维沃"
        case "XIAOMI": return "小米"
        case "HUAWEI": return "华为"
        case "GOOGLE": return "谷歌"
        case "APPLE": return "苹果"
        case "SONY": return "索尼"
        case "CANON": return "佳能"
        case "NIKON": return "尼康"
        case "FUJIFILM": return "富士"
        case "RICOH": return "理光"
        case "PANASONIC": return "松下"
        case "SIGMA": return "适马"
        default: return brand
        }
    }

    private func previewOverlay(_ image: UIImage) -> some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()

            VStack(spacing: 14) {
                HStack {
                    Text("已生成")
                        .font(.headline)
                    Spacer()
                    Button("关闭") { camera.clearPreview() }
                }
                .padding(.horizontal)

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 10)

                HStack(spacing: 10) {
                    Button("继续拍摄") { camera.clearPreview() }
                        .buttonStyle(.borderedProminent)

                    if let url = camera.lastSavedURL {
                        ShareLink(item: url) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.top, 12)
        }
    }

    private var presetPicker: some View {
        NavigationStack {
            List {
                Section("已加载的安卓配置") {
                    if !agcStore.imported.isEmpty {
                        Text("已加载 \(agcStore.imported.count) 个配置档案")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if agcStore.imported.isEmpty {
                        Text("还没有导入配置文件。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(agcStore.imported) { item in
                            Button {
                                preset = item
                                showPresetPicker = false
                            } label: {
                                presetRow(item)
                            }
                        }
                    }

                    Button {
                        showPresetPicker = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showAGCImporter = true
                        }
                    } label: {
                        Label("＋ 添加安卓配置文件", systemImage: "folder.badge.plus")
                    }
                    if !agcStore.imported.isEmpty {
                        Button("清空已加载配置", role: .destructive) {
                            agcStore.imported.removeAll()
                            agcStore.sourceName = ""
                            agcStore.enabled = false
                            preset = PresetLibrary.all[0]
                            profile = .natural
                        }
                    }
                }

                Section("内置 128 个风格") {
                    ForEach(PresetLibrary.all) { item in
                        Button {
                            preset = item
                            showPresetPicker = false
                        } label: {
                            presetRow(item)
                        }
                    }
                }
            }
            .navigationTitle("相机 / 风格 / 配置")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { showPresetPicker = false }
                }
            }
        }
    }

    private func presetRow(_ item: CameraPreset) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(item.watermarkAccent))
                .frame(width: 6, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(item.displayBrand)  \(item.model)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(item.lens) · \(item.focal) · \(item.aperture)")
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

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("安卓配置文件") {
                    Toggle(
                        "启用当前安卓配置",
                        isOn: Binding(
                            get: { agcStore.enabled },
                            set: { enabled in
                                agcStore.enabled = enabled
                                if enabled, let item = agcStore.imported.first {
                                    preset = item
                                } else if preset.id.hasPrefix("agc-") {
                                    preset = PresetLibrary.all[0]
                                }
                            }
                        )
                    )
                    .disabled(agcStore.imported.isEmpty)

                    if !agcStore.sourceName.isEmpty {
                        Text("当前配置：\(agcStore.sourceName)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showSettings = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showAGCImporter = true
                        }
                    } label: {
                        Label("＋ 添加安卓配置文件", systemImage: "folder.badge.plus")
                    }

                    Text("支持直接选择 .agc 文件。每个文件里的多个配置档案都会加入列表。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("水印") {
                    Toggle("拍照后自动加水印", isOn: $watermark)

                    Text("不同品牌使用不同布局：竖排、底栏、极简、右上角、分栏等，不再全部使用同一种模板。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("自定义水印") {
                    TextField("水印主标题", text: $watermarkConfig.title)
                    TextField("水印副标题", text: $watermarkConfig.subtitle)
                    TextField("水印底部文字", text: $watermarkConfig.customFooter)
                    Toggle("显示拍摄参数", isOn: $watermarkConfig.showParameters)
                    Toggle("使用当前机型名称", isOn: $watermarkConfig.usePresetBrand)

                    Picker("水印版式", selection: $watermarkConfig.layout) {
                        ForEach(CustomWatermarkLayout.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }

                    Picker("相框样式", selection: $watermarkConfig.frame) {
                        ForEach(CustomFrameStyle.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }

                    Stepper(
                        "相框宽度 \(Int(watermarkConfig.frameWidth))",
                        value: $watermarkConfig.frameWidth,
                        in: 2...40,
                        step: 2
                    )

                    Slider(value: $watermarkConfig.opacity, in: 0.15...0.95) {
                        Text("水印透明度")
                    }

                    Toggle("显示自定义标志", isOn: $watermarkConfig.showLogo)

                    Button("加载自定义标志图片") {
                        showLogoImporter = true
                    }

                    if watermarkConfig.logoData != nil {
                        Button("移除自定义标志") {
                            watermarkConfig.logoData = nil
                        }
                    }

                    Stepper(
                        "标志大小 \(Int(watermarkConfig.logoScale * 100))%",
                        value: $watermarkConfig.logoScale,
                        in: 0.08...0.40,
                        step: 0.02
                    )

                    Button("恢复当前预设水印") {
                        watermarkConfig = CustomWatermarkConfig()
                    }
                }

                Section("色彩曲线") {
                    if activeLUTName.isEmpty {
                        Text("当前没有加载色彩曲线。")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("当前：\(activeLUTName)")
                            .foregroundStyle(.secondary)
                    }

                    Button("加载三维色彩曲线") {
                        showLUTImporter = true
                    }

                    if !activeLUTName.isEmpty {
                        Button("关闭当前色彩曲线") {
                            LUTStore.shared.set(nil)
                            activeLUTName = ""
                        }
                    }
                }

                Section("照片信息") {
                    TextField("厂商", text: $metadata.make)
                    TextField("机型", text: $metadata.model)
                    TextField("镜头", text: $metadata.lens)
                    TextField("摄影者", text: $metadata.artist)
                    TextField("版权", text: $metadata.copyright)
                    TextField("拍摄时间", text: $metadata.dateOriginal)
                    Toggle("移除位置坐标", isOn: $metadata.stripGPS)

                    Button("使用当前预设信息") {
                        metadata.make = effectivePreset.exifMake
                        metadata.model = effectivePreset.exifModel
                        metadata.lens = effectivePreset.lens
                    }

                    Button("把机型写入水印标题") {
                        watermarkConfig.title = metadata.model.isEmpty ? effectivePreset.exifModel : metadata.model
                        watermarkConfig.usePresetBrand = false
                    }
                }

                Section("说明") {
                    Text("照片信息修改只作用于导出的照片；专业原片保持原始数据。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { showSettings = false }
                }
            }
        }
    }
}

@MainActor
final class AGCStore: ObservableObject {
    @Published var imported: [CameraPreset] = AGCProfileLibrary.shadowChasing
    @Published var enabled = true
    @Published var sourceName = "影踪追寻_通用配置"
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
