import SwiftUI
import AVFoundation
import Photos
import ImageIO
import UniformTypeIdentifiers
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct CameraPreset: Identifiable, Hashable {
    let id: String
    let brand: String
    let model: String
    let lens: String
    let focal: String
    let aperture: String
    let iso: String
    let shutter: String
    let saturation: Float
    let contrast: Float
    let warmth: Float
    let make: String
}

enum Presets {
    static let all: [CameraPreset] = {
        let base: [(String,String,String,String,String,String,String,String,Float,Float,Float,String)] = [
            ("LEICA","Q3","SUMMILUX 28","28mm","F1.7","ISO 100","1/250s","Leica Camera AG",0.92,1.08,0,"Leica Camera AG"),
            ("LEICA","Q3 43","APO-SUMMICRON 43","43mm","F2.0","ISO 100","1/250s","Leica Camera AG",0.93,1.08,0,"Leica Camera AG"),
            ("LEICA","M11","SUMMILUX-M 35","35mm","F1.4","ISO 64","1/500s","Leica Camera AG",0.92,1.10,0,"Leica Camera AG"),
            ("HASSELBLAD","X2D 100C","XCD 2,5/38V","38mm","F2.5","ISO 64","1/320s","Hasselblad",0.86,1.03,0,"Hasselblad"),
            ("HASSELBLAD","X2D 100C","XCD 2,5/55V","55mm","F2.5","ISO 64","1/320s","Hasselblad",0.87,1.03,0,"Hasselblad"),
            ("ZEISS","ZX1","Distagon 35","35mm","F2.0","ISO 100","1/250s","ZEISS",0.98,1.12,0,"ZEISS"),
            ("vivo","X200 Ultra","ZEISS Master","35mm","F1.2","ISO 50","1/250s","vivo",1.06,1.06,0,"vivo"),
            ("vivo","X200 Pro","ZEISS Tele","50mm","F1.6","ISO 50","1/250s","vivo",1.04,1.05,0,"vivo"),
            ("XIAOMI","15 Ultra","Leica Summilux","23mm","F1.63","ISO 50","1/250s","Xiaomi",0.96,1.10,0,"Xiaomi"),
            ("XIAOMI","14 Ultra","Leica Vario-Summilux","23mm","F1.63","ISO 50","1/250s","Xiaomi",0.96,1.08,0,"Xiaomi"),
            ("HUAWEI","Pura 70 Ultra","XMAGE","24mm","F1.6","ISO 50","1/200s","HUAWEI",1.05,1.06,0,"HUAWEI"),
            ("HUAWEI","Mate 70 Pro","XMAGE","24mm","F1.4","ISO 50","1/200s","HUAWEI",1.04,1.05,0,"HUAWEI"),
            ("OPPO","Find X8 Ultra","Hasselblad","23mm","F1.8","ISO 50","1/250s","OPPO",1.03,1.05,0,"OPPO"),
            ("OPPO","Find X7 Ultra","Hasselblad","23mm","F1.8","ISO 50","1/250s","OPPO",1.03,1.05,0,"OPPO"),
            ("GOOGLE","Pixel 10 Pro","Computational","25mm","F1.7","ISO 50","1/250s","Google",1.02,1.04,0,"Google"),
            ("GOOGLE","Pixel 9 Pro","Computational","25mm","F1.7","ISO 50","1/250s","Google",1.03,1.04,0,"Google"),
            ("APPLE","iPhone 17 Pro","Apple ProRAW","24mm","F1.78","ISO 50","1/250s","Apple",1.00,1.03,0,"Apple"),
            ("APPLE","iPhone 17 Pro Max","Apple ProRAW","24mm","F1.78","ISO 50","1/250s","Apple",1.00,1.03,0,"Apple"),
            ("SONY","α1 II","G Master","35mm","F1.4","ISO 100","1/500s","SONY",0.98,1.10,0,"SONY"),
            ("SONY","α7R V","G Master","35mm","F1.4","ISO 100","1/500s","SONY",0.98,1.10,0,"SONY"),
            ("CANON","EOS R5 Mark II","RF L","50mm","F1.2","ISO 100","1/500s","Canon",1.01,1.08,0,"Canon"),
            ("CANON","EOS R6 Mark II","RF L","35mm","F1.8","ISO 100","1/320s","Canon",1.02,1.07,0,"Canon"),
            ("NIKON","Z8","NIKKOR Z","50mm","F1.8","ISO 64","1/500s","NIKON CORPORATION",1.00,1.08,0,"NIKON CORPORATION"),
            ("NIKON","Zf","NIKKOR Z","40mm","F2.0","ISO 64","1/320s","NIKON CORPORATION",1.01,1.07,0,"NIKON CORPORATION"),
            ("FUJIFILM","X100VI","FUJINON","23mm","F2.0","ISO 125","1/250s","FUJIFILM",0.96,1.06,0,"FUJIFILM"),
            ("FUJIFILM","X-T5","XF 23","23mm","F2.0","ISO 125","1/250s","FUJIFILM",0.97,1.07,0,"FUJIFILM"),
            ("RICOH","GR IIIx","GR Lens","40mm","F2.8","ISO 100","1/500s","RICOH",0.95,1.05,0,"RICOH"),
            ("PANASONIC","S1RII","LUMIX S PRO","50mm","F1.8","ISO 100","1/500s","Panasonic",0.98,1.07,0,"Panasonic"),
            ("SIGMA","fp L","Contemporary","45mm","F2.8","ISO 100","1/500s","SIGMA",0.97,1.06,0,"SIGMA"),
            ("LEICA","D-LUX 8","DC VARIO-SUMMILUX","24mm","F1.7","ISO 100","1/320s","Leica Camera AG",0.90,1.05,0,"Leica Camera AG"),
            ("vivo","X100 Ultra","ZEISS APO Tele","85mm","F2.5","ISO 64","1/320s","vivo",1.03,1.05,0,"vivo"),
            ("XIAOMI","14 Ultra","Leica Authentic","75mm","F2.5","ISO 64","1/320s","Xiaomi",0.93,1.09,0,"Xiaomi")
        ]
        let variants = [
            ("Natural",1.00,1.00),
            ("Cinematic",0.93,1.10),
            ("Portrait",1.02,1.06),
            ("Street",0.90,1.12)
        ]
        var result:[CameraPreset] = []
        for b in base {
            for v in variants {
                result.append(CameraPreset(
                    id: "\(b.0)_\(b.1)_\(v.0)",
                    brand: b.0, model: b.1, lens: "\(b.2) · \(v.0)",
                    focal: b.3, aperture: b.4, iso: b.5, shutter: b.6,
                    saturation: b.8 * Float(v.1), contrast: b.9 * Float(v.2), warmth: b.10,
                    make: b.11
                ))
            }
        }
        return result
    }()
}

final class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    @Published var isReady = false
    @Published var isCapturing = false
    @Published var errorMessage: String?
    @Published var lastImage: UIImage?

    override init() {
        super.init()
        requestPermission()
    }

    private func requestPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configure() }
                    else { self?.errorMessage = "请允许相机权限" }
                }
            }
        default:
            errorMessage = "请在设置中允许相机权限"
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        defer {
            session.commitConfiguration()
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
                DispatchQueue.main.async { self.isReady = true }
            }
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            errorMessage = "找不到后置摄像头"; return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.maxPhotoQualityPrioritization = .quality
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func capture(preset: CameraPreset, watermark: Bool, writeEXIF: Bool) {
        guard !isCapturing else { return }
        isCapturing = true
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .quality
        output.capturePhoto(with: settings, delegate: PhotoDelegate(owner: self, preset: preset, watermark: watermark, writeEXIF: writeEXIF))
    }

    final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
        weak var owner: CameraController?
        let preset: CameraPreset
        let watermark: Bool
        let writeEXIF: Bool
        init(owner: CameraController, preset: CameraPreset, watermark: Bool, writeEXIF: Bool) {
            self.owner = owner; self.preset = preset; self.watermark = watermark; self.writeEXIF = writeEXIF
        }

        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            DispatchQueue.main.async {
                guard let owner = self.owner else { return }
                defer { owner.isCapturing = false }
                guard error == nil, let data = photo.fileDataRepresentation(),
                      let image = UIImage(data: data) else {
                    owner.errorMessage = error?.localizedDescription ?? "拍照失败"; return
                }
                let rendered = PhotoProcessor.render(image, preset: self.preset, watermark: self.watermark, writeEXIF: self.writeEXIF)
                owner.lastImage = rendered
                Task { await PhotoSaver.save(rendered) }
            }
        }
    }

    func resetPreview() { lastImage = nil }
}

enum PhotoProcessor {
    static func render(_ image: UIImage, preset: CameraPreset, watermark: Bool, writeEXIF: Bool) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let ci = CIImage(cgImage: cg)
        let controls = CIFilter.colorControls()
        controls.inputImage = ci
        controls.saturation = preset.saturation
        controls.contrast = preset.contrast
        controls.brightness = 0
        let styled = controls.outputImage ?? ci
        let context = CIContext()
        guard let styledCG = context.createCGImage(styled, from: styled.extent) else { return image }
        return watermark ? drawWatermark(UIImage(cgImage: styledCG), preset: preset) : UIImage(cgImage: styledCG)
    }

    static func drawWatermark(_ image: UIImage, preset: CameraPreset) -> UIImage {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
            let h = max(95, size.height * 0.10)
            let rect = CGRect(x: 0, y: size.height-h, width: size.width, height: h)
            UIColor.black.withAlphaComponent(0.72).setFill()
            UIRectFill(rect)
            let x = max(24, size.width * 0.028)
            let titleFont = UIFont.systemFont(ofSize: max(20, size.width/58), weight: .bold)
            let infoFont = UIFont.monospacedSystemFont(ofSize: max(12, size.width/95), weight: .medium)
            ("\(preset.brand)  \(preset.model)" as NSString).draw(at: CGPoint(x:x, y:size.height-h+18),
                withAttributes:[.font:titleFont,.foregroundColor:UIColor.white])
            let info = "\(preset.lens)   \(preset.focal)   \(preset.aperture)   \(preset.shutter)   \(preset.iso)"
            (info as NSString).draw(at: CGPoint(x:x, y:size.height-h+58),
                withAttributes:[.font:infoFont,.foregroundColor:UIColor.white.withAlphaComponent(0.86)])
        }
    }
}

enum PhotoSaver {
    static func save(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.94) else { return }
        if PHPhotoLibrary.authorizationStatus(for: .addOnly) == .notDetermined {
            _ = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        }
        guard let url = try? writeTemp(data) else { return }
        try? await PHPhotoLibrary.shared().performChanges {
            let req = PHAssetCreationRequest.forAsset()
            req.addResource(with: .photo, fileURL: url, options: nil)
        }
    }

    static func writeTemp(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("GCamStyle-\(UUID().uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.preview.session = session
        view.preview.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}
    final class PreviewView: UIView {
        let preview = AVCaptureVideoPreviewLayer()
        override init(frame: CGRect) {
            super.init(frame: frame)
            layer.addSublayer(preview)
        }
        required init?(coder: NSCoder) { fatalError() }
        override func layoutSubviews() { super.layoutSubviews(); preview.frame = bounds }
    }
}

@main
struct GCamStyleApp: App {
    @StateObject private var camera = CameraController()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(camera) }
    }
}

struct ContentView: View {
    @EnvironmentObject private var camera: CameraController
    @State private var preset = Presets.all[0]
    @State private var watermark = true
    @State private var exif = false
    @State private var showPicker = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: camera.session).ignoresSafeArea()
                .overlay(topBar, alignment: .top)
                .overlay(bottomBar, alignment: .bottom)

            if let image = camera.lastImage {
                Color.black.opacity(0.90).ignoresSafeArea()
                VStack(spacing:16) {
                    Text("已生成").font(.headline)
                    Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 22)).padding(.horizontal)
                    Button("继续拍摄") { camera.resetPreview() }.buttonStyle(.borderedProminent)
                }.padding()
            }
        }
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                List(Presets.all) { item in
                    Button {
                        preset = item
                        showPicker = false
                    } label: {
                        HStack {
                            VStack(alignment:.leading) {
                                Text("\(item.brand)  \(item.model)").font(.headline)
                                Text("\(item.lens) · \(item.focal) · \(item.aperture)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if item.id == preset.id { Image(systemName:"checkmark.circle.fill") }
                        }
                    }
                }
                .navigationTitle("相机风格")
            }
        }
    }

    private var topBar: some View {
        HStack {
            Text("GCAM STYLE").font(.system(size:16,weight:.bold)).tracking(1.2)
            Spacer()
            Button { showPicker = true } label: {
                Text("\(preset.brand) · \(preset.model)").font(.system(size:12,weight:.semibold))
                    .padding(.horizontal,12).padding(.vertical,9)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }.padding(.horizontal,16).padding(.top,12)
    }

    private var bottomBar: some View {
        VStack(spacing:12) {
            ScrollView(.horizontal,showsIndicators:false) {
                HStack(spacing:8) {
                    ForEach(Presets.all.prefix(32)) { item in
                        Button { preset = item } label: {
                            Text(item.brand).font(.system(size:11,weight:.bold))
                                .padding(.horizontal,11).padding(.vertical,8)
                                .background(item.id == preset.id ? Color.white : Color.black.opacity(0.35), in: Capsule())
                                .foregroundStyle(item.id == preset.id ? Color.black : Color.white)
                        }
                    }
                }.padding(.horizontal,12)
            }
            HStack {
                Button { showPicker = true } label: {
                    Image(systemName:"camera.aperture").frame(width:48,height:48).background(.ultraThinMaterial,in:Circle())
                }
                Spacer()
                Button {
                    camera.capture(preset:preset, watermark:watermark, writeEXIF:exif)
                } label: {
                    ZStack {
                        Circle().fill(.white.opacity(0.25)).frame(width:84,height:84)
                        Circle().fill(.white).frame(width:68,height:68)
                    }
                }.disabled(camera.isCapturing)
                Spacer()
                Button { watermark.toggle() } label: {
                    Image(systemName: watermark ? "text.viewfinder" : "text.viewfinder.badge.magnifyingglass")
                        .frame(width:48,height:48).background(.ultraThinMaterial,in:Circle())
                }
            }.padding(.horizontal,18)
            HStack(spacing:10) {
                Text("\(preset.model) · \(preset.focal) · \(preset.aperture)").font(.system(size:11,weight:.medium,design:.monospaced))
                Spacer()
                Toggle("EXIF", isOn:$exif).labelsHidden().tint(.white)
            }.padding(.horizontal,18).padding(.bottom,14)
        }
        .background(.black.opacity(0.12))
    }
}
