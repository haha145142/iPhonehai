# GCamStyle iOS

原生 SwiftUI + AVFoundation 相机项目。通过 GitHub Actions 的 macOS runner 编译 IPA，适合只有 iPhone 的用户。

使用：GitHub -> Actions -> Build GCamStyle iOS -> Run workflow。完成后在 Artifacts 下载 GCamStyle-iOS-IPA。

当前版本包含 128 个风格预设，覆盖 Leica / Hasselblad / ZEISS / vivo / Xiaomi / Huawei / OPPO / Pixel / iPhone / Sony / Canon / Nikon / Fujifilm / Ricoh 等。拍摄后自动处理并生成参数水印。

注意：水印为应用动态绘制的文字/参数条，不包含第三方官方 Logo 图片；不代表照片真实硬件来源。
