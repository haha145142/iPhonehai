import UIKit
import CoreImage

struct PhotoSettings {
    var gamma: Double = 1.0
    var contrast: Double = 1.0
    var saturation: Double = 1.0
    var temperature: Double = 0.0
    var vignette: Double = 0.0
    var sharpness: Double = 0.0
    var watermark: Bool = true
    var drawFrame: Bool = false
    var modelText: String = "谷歌相机 · 影踪追寻"

    static func from(config: AgcConfig?) -> PhotoSettings {
        guard let c = config else { return PhotoSettings() }
        var s = PhotoSettings()

        let gammaPreset = c.int("lib_gamma_curve_preset_key_p15_0", 7)
        s.gamma = 0.9 + Double(gammaPreset) * 0.04

        let black = c.double("lib_contrast_black_key_p11_0", 2.15)
        s.contrast = 0.9 + (black - 1.0) * 0.08

        let sat = c.double("lib_pref_satcct_c_key_p16_0", 1.0)
        s.saturation = max(0.0, sat)

        let tint = c.double("lib_pref_satcct_r_key_p8_0", 1.0)
        s.temperature = (tint - 1.0) * 2.0

        let vigStart = c.double("lib_gpu_vignette_start_key_p3_0", 0.0)
        s.vignette = vigStart > 0 ? 0.35 : 0.0

        let detail = c.double("lib_sabre_detail_key_p12_0", 30.0)
        s.sharpness = max(-1.0, min(1.0, (detail - 30.0) / 60.0))

        return s
    }
}

final class PhotoProcessor {
    static let shared = PhotoProcessor()
    private let context = CIContext()

    func process(_ ciImage: CIImage, settings: PhotoSettings) -> UIImage? {
        var image = ciImage

        if abs(settings.gamma - 1.0) > 0.01,
           let filter = CIFilter(name: "CIGammaAdjust") {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(1.0 / max(settings.gamma, 0.1), forKey: "inputPower")
            if let output = filter.outputImage {
                image = output
            }
        }

        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(settings.contrast, forKey: kCIInputContrastKey)
            filter.setValue(settings.saturation, forKey: kCIInputSaturationKey)
            if let output = filter.outputImage {
                image = output
            }
        }

        if abs(settings.temperature) > 0.01,
           let filter = CIFilter(name: "CIWhitePointAdjust") {
            filter.setValue(image, forKey: kCIInputImageKey)
            let t = CGFloat(max(0.6, min(1.2, 1.0 - settings.temperature * 0.15)))
            let color = CIColor(
                red: t,
                green: 1.0,
                blue: max(0.6, min(1.2, 1.0 + settings.temperature * 0.10))
            )
            filter.setValue(color, forKey: kCIInputColorKey)
            if let output = filter.outputImage {
                image = output
            }
        }

        if settings.vignette > 0.01,
           let filter = CIFilter(name: "CIVignette") {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(settings.vignette, forKey: kCIInputIntensityKey)
            filter.setValue(1.5, forKey: kCIInputRadiusKey)
            if let output = filter.outputImage {
                image = output
            }
        }

        guard let cg = context.createCGImage(image, from: image.extent) else { return nil }

        var output = UIImage(cgImage: cg)
        if settings.drawFrame {
            output = addFrame(output)
        }
        if settings.watermark {
            output = addWatermark(output, text: settings.modelText)
        }
        return output
    }

    private func addFrame(_ image: UIImage) -> UIImage {
        let margin = image.size.width * 0.04
        let size = CGSize(
            width: image.size.width + margin * 2,
            height: image.size.height + margin * 2
        )
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            UIColor.white.setFill()
            CGRect(origin: .zero, size: size).fill()
            image.draw(in: CGRect(
                x: margin,
                y: margin,
                width: image.size.width,
                height: image.size.height
            ))
        }
    }

    private func addWatermark(_ image: UIImage, text: String) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)

        return renderer.image { _ in
            image.draw(at: .zero)

            let inset = image.size.width * 0.05
            let boxHeight = image.size.height * 0.12

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .right

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(
                    ofSize: max(14, image.size.width * 0.042),
                    weight: .medium
                ),
                .foregroundColor: UIColor.white.withAlphaComponent(0.92),
                .paragraphStyle: paragraph
            ]

            let rect = CGRect(
                x: inset,
                y: image.size.height - boxHeight - inset,
                width: image.size.width - inset * 2,
                height: boxHeight
            )

            "(text)  ·  (Self.dateString)"
                .draw(in: rect, withAttributes: attributes)
        }
    }

    private static var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter.string(from: Date())
    }
}
