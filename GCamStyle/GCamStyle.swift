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

enum CaptureMode: CaseIterable, Identifiable {
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

enum WatermarkLayout: String, CaseIterable {
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

struct MetadataDraft: Hashable {
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
        switch brand.uppercased() {
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

        if let count = int("pref_patch_profile_count_key"), count > 0 {
            ids.formUnion(0..<count)
        }

        let pattern = #"^lib_profile_title_key_p(\\d+)_0$"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            for key in values.keys {
                let ns = key as NSString
                let range = NSRange(location: 0, length: ns.length)
                if let match = regex.firstMatch(in: key, range: range),
                   let numberRange = Range(match.range(at: 1), in: key),
                   let id = Int(key[numberRange]) {
                    ids.insert(id)
                }
            }
        }

        return ids.sorted()
    }

    func profileTitle(_ index: Int) -> String {
        profileValue("lib_profile_title_key", profile: index) ?? "配置 \(index + 1)"
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

enum AGCMapper {
    private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(high, max(low, value))
    }

    private static func finite(_ value: Double, fallback: Double) -> Double {
        value.isFinite ? value : fallback
    }

    static func makePresets(from config: AGCConfig, fileName: String) -> [CameraPreset] {
        let brand = config.string("info_brand_key") ?? config.string("info_manuf_key") ?? "安卓配置"
        let model = config.string("info_model_key") ?? "通用配置"
        let watermarkType = config.int("pref_watermark_type_key")

        let globalSaturation = config.number("lib_gpu_saturation_key") ?? 1.0
        let globalVibrance = config.number("lib_gpu_vibrance_key") ?? 1.0
        let globalContrast = config.number("lib_gpu_contrast_key") ?? 1.0
        let globalHue = config.number("lib_gpu_hue_key") ?? 0.0

        let profileIDs = config.profileIndices()
        let ids = profileIDs.isEmpty ? [0] : profileIDs

        return ids.map { index in
            let title = config.profileTitle(index)

            let baseSaturation =
                config.profileNumber("lib_pref_satcct_key", profile: index) ??
                globalSaturation
            let r =
                config.profileNumber("lib_pref_red_coeff_key", profile: index) ??
                config.profileNumber("lib_pref_satcct_r_key", profile: index) ??
                1.0
            let g =
                config.profileNumber("lib_pref_green_coeff_key", profile: index) ??
                config.profileNumber("lib_pref_satcct_g_key", profile: index) ??
                1.0
            let b =
                config.profileNumber("lib_pref_blue_coeff_key", profile: index) ??
                config.profileNumber("lib_pref_satcct_b_key", profile: index) ??
                1.0

            let saturation = clamp(
                baseSaturation * (0.90 + globalVibrance * 0.10),
                0.60,
                1.45
            )

            let c2 = config.profileNumber("lib_contrast_2_key", profile: index) ?? 0.46
            let cb = config.profileNumber("lib_contrast_black_key", profile: index) ?? 0.85
            let contrast = clamp(
                globalContrast * (0.96 + (c2 - 0.46) * 0.55 + (cb - 0.85) * 0.18),
                0.78,
                1.30
            )

            let darkExposure =
                config.profileNumber("lib_exposure_darker_key", profile: index) ??
                config.number("lib_gpu_brightness_key") ?? 0.0

            let tone = config.profileNumber("lib_tone_key", profile: index) ?? 15.0
            let gamma = config.profileNumber("lib_gamma_key", profile: index) ?? 5.0

            let exposure = clamp(
                finite(darkExposure * 0.02 + (tone - 15.0) * 0.006 + (gamma - 5.0) * 0.004, fallback: 0),
                -1.0,
                1.0
            )

            let hdrPlus =
                config.profileNumber("lib_hdr_range_plus_key", profile: index) ??
                config.number("lib_hdr_range_plus_key") ?? 5.0
            let hdrMinus =
                config.profileNumber("lib_hdr_range_minus_key", profile: index) ??
                config.number("lib_hdr_range_minus_key") ?? -3.0

            let highlights = clamp(0.78 - hdrPlus * 0.045, 0.18, 0.90)
            let shadows = clamp(0.18 + abs(hdrMinus) * 0.055, 0.05, 0.65)

            let sharp =
                config.profileNumber("lib_sharp_gain_key", profile: index) ??
                config.profileNumber("lib_sharp_gain_micro_key", profile: index) ??
                config.profileNumber("lib_sharp_gain_macro_key", profile: index) ??
                config.profileNumber("lib_luma_denoise_new_a", profile: index) ??
                0.25

            let sharpness = clamp(sharp, 0.05, 1.0)

            let denoise =
                config.profileNumber("lib_denoise_smoothing_key", profile: index) ??
                config.profileNumber("lib_smoothing_sabre_key", profile: index) ??
                0.0

            let warmth = clamp((r - b) * 8.0 + globalHue / 30.0, -12.0, 12.0)
            let tint = clamp((g - ((r + b) / 2.0)) * 6.0, -8.0, 8.0)

            let frameCount =
                config.profileInt("lib_pref_frame_count_key", profile: index) ??
                config.profileInt("lib_pref_frame_count_zsl_key", profile: index) ??
                config.profileInt("lib_pref_frame_count_ns_key", profile: index)

            let isoValue = config.profileValue("lib_iso_key", profile: index)
                ?? config.string("pref_iso_key")
                ?? "自动"

            let focal = config.string("pref_lens_title_key_2")
                ?? config.string("pref_lens_title_key_4")
                ?? "主摄"

            let layout: WatermarkLayout
            switch watermarkType {
            case 1: layout = .verticalLeft
            case 2: layout = .verticalRight
            case 3: layout = .topRight
            default: layout = .bottomBand
            }

            let suffix = frameCount.map { " · 合成 \(String($0)) 帧" } ?? ""

            return CameraPreset(
                id: "agc-\(fileName)-p\(index)-\(UUID().uuidString)",
                brand: brand,
                model: "\(model) · \(title)",
                lens: "\(focal) · \(fileName)",
                focal: focal.contains("75") ? "75mm" : "28mm",
                aperture: "F1.8",
                iso: "ISO \(isoValue)",
                shutter: "自动",
                style: "安卓配置 · \(title)",
                exposure: Float(exposure),
                saturation: Float(saturation),
                contrast: Float(contrast),
                highlights: Float(highlights),
                shadows: Float(shadows),
                sharpness: Float(clamp(sharpness - denoise * 0.02, 0.05, 1.0)),
                warmth: Float(warmth),
                tint: Float(tint),
                channelBias: 0,
                exifMake: brand,
                exifModel: model,
                watermarkLayout: layout
            )
        }
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
    @Published var errorMessage: String?
    @Published var lastImage: UIImage?
    @Published var lastSavedURL: URL?
    @Published var proRAWSupported = false
    @Published var livePhotoSupported = false

    var currentPresetForPreview: CameraPreset = PresetLibrary.all[0]

    private var currentInput: AVCaptureDeviceInput?
    private var delegates: [Int64: CaptureProcessorDelegate] = [:]
    private var orientationObserver: NSObjectProtocol?

    override init() {
        super.init()
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()

        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateCameraRotation()
            }
        }

        Task { await prepare() }
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
        let orientation = UIDevice.current.orientation
        let angle: CGFloat

        switch orientation {
        case .portrait:
            angle = 90
        case .portraitUpsideDown:
            angle = 270
        case .landscapeLeft:
            angle = 180
        case .landscapeRight:
            angle = 0
        default:
            angle = 90
        }

        if let videoConnection = videoOutput.connection(with: .video),
           videoConnection.isVideoRotationAngleSupported(angle) {
            videoConnection.videoRotationAngle = angle
        }

        if let photoConnection = photoOutput.connection(with: .video),
           photoConnection.isVideoRotationAngleSupported(angle) {
            photoConnection.videoRotationAngle = angle
        }
    }

    func capture(preset: CameraPreset, mode: CaptureMode, watermark: Bool, metadata: MetadataDraft) {
        guard ready, !isCapturing else { return }
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
            metadata: metadata
        )

        delegates[settings.uniqueID] = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    func clearPreview() {
        lastImage = nil
        lastSavedURL = nil
        errorMessage = nil
    }

    func importPhoto(_ data: Data, preset: CameraPreset, watermark: Bool, metadata: MetadataDraft) {
        do {
            let url = try ExportService.renderToJPEG(
                sourceData: data,
                preset: preset,
                watermark: watermark,
                metadata: metadata
            )
            let bytes = try Data(contentsOf: url)
            guard let image = UIImage(data: bytes) else { return }
            lastImage = image
            lastSavedURL = url
            Task { await PhotoSaver.saveJPEG(url: url) }
        } catch {
            errorMessage = "照片处理失败：\(error.localizedDescription)"
        }
    }

    func showProcessedStill(
        data: Data,
        preset: CameraPreset,
        watermark: Bool,
        metadata: MetadataDraft
    ) {
        do {
            let url = try ExportService.renderToJPEG(
                sourceData: data,
                preset: preset,
                watermark: watermark,
                metadata: metadata
            )
            let bytes = try Data(contentsOf: url)
            guard let image = UIImage(data: bytes) else { return }
            lastImage = image
            lastSavedURL = url
            Task { await PhotoSaver.saveJPEG(url: url) }
        } catch {
            errorMessage = "照片导出失败：\(error.localizedDescription)"
        }
    }

    fileprivate func finish(id: Int64) {
        delegates[id] = nil
        isCapturing = false
    }

    fileprivate func handleRaw(data: Data, preset: CameraPreset, metadata: MetadataDraft) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GCamStyle-RAW-\(UUID().uuidString).dng")

        do {
            try data.write(to: url, options: .atomic)
            Task { await PhotoSaver.saveRAW(url: url) }

            guard let rawFilter = CIRAWFilter(imageURL: url) else {
                errorMessage = "专业 RAW 已保存，但本机 RAW 开发器无法继续处理。"
                return
            }

            rawFilter.isDraftModeEnabled = false
            rawFilter.exposure = preset.exposure
            if rawFilter.isLensCorrectionSupported {
                rawFilter.isLensCorrectionEnabled = true
            }
            if rawFilter.isLuminanceNoiseReductionSupported {
                rawFilter.luminanceNoiseReductionAmount = 0.45
            }
            if rawFilter.isColorNoiseReductionSupported {
                rawFilter.colorNoiseReductionAmount = 0.30
            }
            if rawFilter.isSharpnessSupported {
                rawFilter.sharpnessAmount = min(1, max(0.05, preset.sharpness))
            }

            guard let rawImage = rawFilter.outputImage else {
                errorMessage = "专业 RAW 开发失败。"
                return
            }

            let styled = PhotoProcessor.applyLook(rawImage, preset: preset)
            let context = CIContext()
            guard let cg = context.createCGImage(styled, from: styled.extent) else { return }

            let styledURL = try ExportService.writeRenderedJPEG(
                cgImage: cg,
                preset: preset,
                metadata: metadata,
                watermark: true,
                sourceProperties: [:]
            )
            let styledData = try Data(contentsOf: styledURL)

            if let image = UIImage(data: styledData) {
                lastImage = image
                lastSavedURL = styledURL
            }
            Task { await PhotoSaver.saveJPEG(url: styledURL) }
            errorMessage = "专业 RAW 原文件和风格化照片都已保存。"
        } catch {
            errorMessage = "专业 RAW 处理失败：\(error.localizedDescription)"
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
            Task { await PhotoSaver.saveLivePhoto(stillURL: stillURL, movieURL: movieURL) }
            showProcessedStill(data: stillData, preset: preset, watermark: watermark, metadata: metadata)
        } catch {
            errorMessage = "实况照片保存失败：\(error.localizedDescription)"
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
                    owner.showProcessedStill(
                        data: processedData,
                        preset: self.preset,
                        watermark: self.watermark,
                        metadata: self.metadata
                    )
                }
            }

            if let rawData = self.rawData {
                owner.handleRaw(data: rawData, preset: self.preset, metadata: self.metadata)
            }

            owner.finish(id: self.settingsID)
        }
    }
}

// MARK: - 实时取景

final class LivePreviewView: MTKView, AVCaptureVideoDataOutputSampleBufferDelegate {
    var activePreset: CameraPreset = PresetLibrary.all[0]

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
        let now = CACurrentMediaTime()
        guard now - lastSubmit > (1.0 / 18.0) else { return }
        lastSubmit = now

        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // 方向由相机连接统一处理，避免取景层二次旋转。
        var source = CIImage(cvPixelBuffer: buffer)
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

    func makeUIView(context: Context) -> LivePreviewView {
        let view = LivePreviewView()
        view.activePreset = preset
        output.setSampleBufferDelegate(view, queue: DispatchQueue(label: "GCamStyle.preview", qos: .userInitiated))
        return view
    }

    func updateUIView(_ uiView: LivePreviewView, context: Context) {
        uiView.activePreset = preset
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

        return controls.outputImage ?? input
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

        return current
    }
}

// MARK: - 导出 / EXIF

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

        let finalImage = watermark
            ? WatermarkRenderer.draw(on: cgImage, preset: preset).cgImage!
            : cgImage

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

        CGImageDestinationAddImage(destination, finalImage, properties as CFDictionary)

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
    static func draw(on cgImage: CGImage, preset: CameraPreset) -> UIImage {
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))

            let titleFont = UIFont.systemFont(ofSize: max(20, size.width / 58), weight: .bold)
            let infoFont = UIFont.monospacedSystemFont(ofSize: max(12, size.width / 94), weight: .medium)
            let accent = preset.watermarkAccent

            switch preset.watermarkLayout {
            case .verticalLeft:
                drawVertical(ctx: ctx.cgContext, size: size, preset: preset, x: 18, fromLeft: true, titleFont: titleFont, infoFont: infoFont, accent: accent)

            case .verticalRight:
                drawVertical(ctx: ctx.cgContext, size: size, preset: preset, x: size.width - 18, fromLeft: false, titleFont: titleFont, infoFont: infoFont, accent: accent)

            case .bottomBand:
                let h = max(104, size.height * 0.095)
                let band = CGRect(x: 0, y: size.height - h, width: size.width, height: h)
                UIColor.black.withAlphaComponent(0.74).setFill()
                ctx.cgContext.fill(band)
                accent.setFill()
                ctx.cgContext.fill(CGRect(x: 0, y: band.minY, width: size.width, height: 4))
                drawBottomText(preset: preset, x: max(24, size.width * 0.028), y: band.minY + 18, titleFont: titleFont, infoFont: infoFont)

            case .bottomMinimal:
                let x = max(24, size.width * 0.028)
                let y = size.height - max(84, size.height * 0.075)
                UIColor.black.withAlphaComponent(0.60).setFill()
                ctx.cgContext.fill(CGRect(x: 0, y: y - 12, width: size.width, height: size.height - y + 12))
                drawBottomText(preset: preset, x: x, y: y, titleFont: titleFont, infoFont: infoFont)

            case .topRight:
                let title = "\(preset.brand)  \(preset.model)" as NSString
                let info = "\(preset.focal) · \(preset.aperture) · \(preset.shutter) · \(preset.iso)" as NSString
                let x = size.width - min(size.width * 0.52, 620)
                let y = max(22, size.height * 0.028)
                UIColor.black.withAlphaComponent(0.52).setFill()
                ctx.cgContext.fill(CGRect(x: x - 18, y: y - 12, width: min(size.width * 0.52, 620), height: 96))
                title.draw(at: CGPoint(x: x, y: y), withAttributes: [.font: titleFont, .foregroundColor: UIColor.white])
                info.draw(at: CGPoint(x: x, y: y + titleFont.lineHeight + 8), withAttributes: [.font: infoFont, .foregroundColor: UIColor.white.withAlphaComponent(0.86)])

            case .split:
                let y = size.height - max(92, size.height * 0.082)
                let line = UIBezierPath()
                line.move(to: CGPoint(x: 24, y: y - 12))
                line.addLine(to: CGPoint(x: size.width - 24, y: y - 12))
                accent.setStroke()
                line.lineWidth = 3
                line.stroke()
                drawBottomText(preset: preset, x: 24, y: y, titleFont: titleFont, infoFont: infoFont)
            }
        }
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

// MARK: - 照片保存

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

    @State private var preset = PresetLibrary.all[0]
    @State private var mode: CaptureMode = .photo
    @State private var watermark = true
    @State private var metadata = MetadataDraft()
    @State private var showPresetPicker = false
    @State private var showSettings = false
    @State private var showAGCImporter = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profile: GCamProfile = .natural

    private var effectivePreset: CameraPreset { profile.applying(to: preset) }

    var allPresets: [CameraPreset] {
        agcStore.imported + PresetLibrary.all
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LiveCameraPreview(
                session: camera.session,
                output: camera.videoOutput,
                preset: effectivePreset
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

            if let image = camera.lastImage {
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
                UTType(filenameExtension: "agc") ?? .xml,
                .xml
            ],
            allowsMultipleSelection: false
        ) { result in
            do {
                let urls = try result.get()
                guard let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                let config = try AGCXMLParser().parse(data)
                let imported = AGCMapper.makePresets(from: config, fileName: url.lastPathComponent)

                // 一个 .agc 可能包含十几个甚至二十多个 Profile，
                // 这里全部导入，而不是只拿第一个。
                agcStore.imported.insert(contentsOf: imported, at: 0)
                if let first = imported.first {
                    preset = first
                }
                profile = .natural
            } catch {
                camera.errorMessage = "AGC 导入失败：\(error.localizedDescription)"
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else { return }
                    camera.importPhoto(data, preset: preset, watermark: watermark, metadata: metadata)
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
                showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.13)))
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 10)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
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
                        metadata: metadata
                    )
                } label: {
                    ZStack {
                        Circle().fill(.white.opacity(0.22)).frame(width: 84, height: 84)
                        Circle().fill(.white).frame(width: 68, height: 68)
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
                }
            }
            .padding(.horizontal, 18)

            HStack {
                Text(mode == .photo ? "实时风格 · 自动水印" : mode == .proRAW ? "保留专业原片 · 生成风格照片" : "保留原始实况 · 生成风格照片")
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

                    Button("加载安卓配置文件") {
                        showPresetPicker = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showAGCImporter = true
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
                    Button("加载安卓配置文件") {
                        showSettings = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showAGCImporter = true
                        }
                    }

                    Text("这里用于导入安卓谷歌相机配置文件。应用会把能够对应到 iPhone 图像处理链的参数转换成当前配置；安卓专用算法库不会直接在 iPhone 上运行。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("水印") {
                    Toggle("拍照后自动加水印", isOn: $watermark)

                    Text("不同品牌使用不同布局：竖排、底栏、极简、右上角、分栏等，不再全部使用同一种模板。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("EXIF") {
                    TextField("厂商", text: $metadata.make)
                    TextField("机型", text: $metadata.model)
                    TextField("镜头", text: $metadata.lens)
                    TextField("摄影者", text: $metadata.artist)
                    TextField("版权", text: $metadata.copyright)
                    TextField("拍摄时间", text: $metadata.dateOriginal)
                    Toggle("移除 GPS", isOn: $metadata.stripGPS)

                    Button("使用当前预设信息") {
                        metadata.make = preset.exifMake
                        metadata.model = preset.exifModel
                        metadata.lens = preset.lens
                    }
                }

                Section("说明") {
                    Text("EXIF 修改只作用于导出的 JPEG。专业 RAW 原文件保持原始数据，不直接修改。")
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
    @Published var imported: [CameraPreset] = []
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
