# iPhonehai

基于 SwiftUI、AVFoundation、Core Image 和 AGC 配置参数的 iPhone 相机工程。

当前基础版本来自用户提供的豆包工程，并保留影踪追寻通用配置的参数映射。

## 功能
- 后置相机取景与拍照
- 拍照、夜景、人像模式
- AGC 配置读取
- 自动保存到照片图库
- 水印
- 相框
- iOS 云端自动构建未签名 IPA

## 说明
Android GCam 的闭源原生算法库不能直接在 iOS 上运行，本项目使用 iOS 原生图像处理能力映射可兼容的参数。
