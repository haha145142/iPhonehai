# GCamStyle iOS Pro

原生 iOS 相机项目，面向只有 iPhone、通过 GitHub Actions macOS 云端编译的使用方式。

## 当前版本 2.0 功能
- 原生 AVFoundation 相机拍摄
- MetalKit + Core Image 实时取景风格预览
- 128 个相机 / 风格模板
- Leica / Hasselblad / ZEISS / vivo / Xiaomi / Huawei / OPPO / Google Pixel / Apple / Sony / Canon / Nikon / Fujifilm / Ricoh 等
- 4 套水印布局：Natural / Cinematic / Portrait / Street
- 拍后自动水印
- Apple ProRAW 捕获（设备支持时）
- ProRAW 原始 DNG 保留 + CIRAWFilter RAW 开发 + 风格化 JPEG 伴侣图
- Live Photo 捕获并保留原始照片 + 配对视频；另外生成风格化静态 JPEG
- JPEG EXIF 编辑：Make / Model / Lens / Artist / Copyright / DateTimeOriginal / GPS 移除
- 相册照片导入后套用风格和水印
- GitHub Actions macOS-15 云端编译未签名 IPA

## 关于品牌水印
当前水印是应用动态绘制的品牌文字、机型、镜头、参数条和品牌风格配色，不内置第三方官方 Logo 图片，也不声称照片来自对应真实硬件。

## 关于 EXIF
导出的 JPEG 可使用所选预设或自定义 Make / Model / Lens 等字段。修改后的元数据属于应用写入的信息，不代表原始拍摄硬件。

## 只用 iPhone 构建
1. 本仓库 main 分支已经配置自动云端构建。
2. 每次 push 到 main 会触发 GCamStyle iOS Cloud Build。
3. 进入 GitHub Actions 的成功运行，下载 Artifact GCamStyle-iOS-unsigned-IPA。
4. 下载得到未签名 IPA 后，用自己的证书完成签名和安装。

## 说明
ProRAW 是否可用由设备与当前相机配置决定；Live Photo 依赖设备支持。Apple 的 AVFoundation / Core Image API 提供了这些能力，但不能把 iPhone 的硬件算法直接变成其他品牌的原厂算法。
