# ADR-0001：macOS 27 / arm64 / Swift 原生单一应用

- 状态：已选定（产品约束，2026-10-29）
- 背景：旧 PicPaste 的跨平台 UI 和原生平台窗口之间存在复杂边界，目标已收敛至 macOS 27。
- 决策：Swift 6.4 / Swift 6 语言模式；macOS deployment target 27.0；仅 arm64。AppKit 负责浮层和贴图，SwiftUI 负责设置；ScreenCaptureKit 负责捕获，Core Graphics / Image I/O 负责绘制导出，Vision 负责 OCR / QR；完全离线，首版单一 App。
- 排除：Windows、macOS 26 及以前、Intel、Rust、WGPU、egui、Electron、WebView、Lite/Full、强制额外 Helper。
- 代价：放弃旧 Rust 实现复用和跨平台能力；需要重新实现截图核心、标注和长截图。
- 校验：P0 需在 Xcode 27 编译并在真实 macOS 27 设备完成截图闭环；SDK 文档本身不能证明 GUI 行为。
- 参考：[Apple Xcode 系统要求](https://developer.apple.com/xcode/system-requirements)、[Apple Silicon 限定说明](https://developer.apple.com/news/?id=k1mtkt1k)。
