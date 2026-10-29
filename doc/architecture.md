# Swift 原生架构与接口边界

## 1. 架构原则

1. **系统原生**：单个 macOS 27 arm64 Swift App；AppKit 管理非标准浮层和事件，SwiftUI 管理设置，ScreenCaptureKit 提供图像，Vision 提供本地识别。
2. **先闭环再扩展**：P0 不为未完成的标注、OCR、长图建立大型通用插件体系；扩展模块只在相应 Issue 实施。
3. **有界与可取消**：截图、标注、长图和贴图资源要有取消和释放路径；抓图数据不会因窗口关闭仍被无限持有。
4. **像素准确**：明确区分全局桌面坐标（points）与显示器局部图像坐标（pixels）；跨屏不能乘一个通用 Retina scale。
5. **可测试**：纯坐标函数、截图会话状态、PNG 输出可单测；TCC、焦点、Spaces、输入、真实剪贴板必须真机验收。

## 2. 核心流程

```text
Global Shortcut / Menu Bar
  -> CaptureCoordinator (@MainActor 状态机)
  -> ScreenPermissionService -> ScreenCaptureKit CaptureService
  -> CapturedFrame (CGImage + display metadata, immutable)
  -> SelectionPanelController (NSPanel) + SelectionView (NSView)
  -> PixelSelection (display-local physical pixel rect)
  -> ImageComposer -> PNGExporter / ClipboardWriter
  -> cleanup session -> idle
```

必须**先捕获源图，再打开浮层**；若需要排除应用自有贴图/预览，应按 ScreenCaptureKit 的应用过滤能力处理并在真机核验，而不是事后修复被污染的像素。

## 3. P0 预期文件责任划分

```
PicPaste/
  App/PicPasteApp.swift                 SwiftUI 应用入口与设置 Scene
  App/AppCoordinator.swift              组合服务和菜单动作
  App/MenuBarController.swift           菜单栏行为与退出
  Hotkeys/GlobalHotkeyManager.swift     全局快捷键注册/冲突与生命周期
  Capture/CaptureCoordinator.swift      捕获状态机和取消令牌（@MainActor）
  Capture/ScreenPermissionService.swift TCC 授权检测与用户指引
  Capture/CaptureService.swift          SCShareableContent / SCScreenshotManager 适配层
  Capture/CapturedFrame.swift           不可变图像与显示器元数据
  Selection/SelectionPanelController.swift NSPanel 主线程生命周期
  Selection/SelectionView.swift         NSView 交互、绘制、键鼠事件
  Selection/SelectionGeometry.swift     纯数值像素变换、裁剪、八手柄逻辑
  Export/ImageComposer.swift            圆角与可选标注合成
  Export/PNGExporter.swift              Image I/O PNG、原子保存、防覆盖
  Export/ClipboardWriter.swift          NSPasteboard 图像输出
  Settings/SettingsView.swift           SwiftUI 设置页
  Settings/AppSettings.swift            本地配置持久化
PicPasteTests/
  SelectionGeometryTests.swift
  CaptureStateTests.swift
  PNGExportTests.swift
```

以上是**计划中的精确路径**，初次导入设计包时尚不存在，实现时由 GitHub Issues 分步创建。后续模块：`Pins/`、`Annotations/`、`Recognition/`、`LongCapture/`；在对应阶段开始前不创建空壳目录和协议。

## 4. P0 最小数据契约

```swift
// 数据模型设计契约；在真实 Xcode 27 工程中实现并用 Swift 6.4 编译验证。
struct PixelRect: Equatable {
    var x: Int
    var y: Int
    var width: Int
    var height: Int
}

struct DisplayGeometry {
    var displayID: CGDirectDisplayID
    var desktopFramePoints: CGRect
    var imageWidthPixels: Int
    var imageHeightPixels: Int
}

struct CapturedFrame {
    var geometry: DisplayGeometry
    var image: CGImage
}
```

- `desktopFramePoints` 是用于屏幕布局的**全局逻辑点**，坐标可为负。
- `PixelRect` 是截取源图的**显示器局部物理像素**（左上为原点；右、下边界取闭开区间）。
- 图像局部像素换算使用所选 display 的独立比例及其 frame 作为局部原点。**禁止** `desktopOrigin * scale` 生成全局物理坐标。
- 禁止把 NSView 的 y-up、图像的 y-down、AppKit `NSScreen` 布局混用；建立独立纯函数和单测。设备布局变化必须使已有捕获快照失效。
- 当 Image I/O/CGImage 的并发安全约束与 Swift 6 严格并发冲突时，在有明确所有权与生命周期前不添加广泛的 `@unchecked Sendable`。

## 5. 系统 API 和线程

- 用 `SCShareableContent` 获取可捕获屏幕和窗口；初版用 `SCContentFilter` + `SCScreenshotManager.captureImage` 获取单帧 `CGImage`，具体可用签名以 Xcode 27 编译结果为准。必要时评估 macOS 27 新截图配置 API，但不得混用未经验证的输出坐标语义。
- 所有 AppKit `NSWindow`/`NSPanel`/`NSView` 生命周期和鼠标焦点改变在 `@MainActor`。
- 异步捕获、PNG 编码、长图拼接和 OCR 不得在主线程执行长时间密集计算；返回 UI 的状态变化只在主线程。
- `NSPanel` 的 level、activation、collectionBehavior 与 `CanJoinAllSpaces`/`FullScreenAuxiliary` 不是纸面正确即视为可用；在 macOS 27 真机测试中确定。
- Glass 仅用于工具栏、按钮等控制层；绝不可改变被截取、合成或导出的图像像素。
- 每个流程具备 `idle -> capturing -> selecting -> exporting -> idle` 和 cancel/error 路径，发生失败不会留下不可见的拦截点击窗口。

## 6. 后期模块边界

| 模块 | 依赖 | 内容 |
| --- | --- | --- |
| Pins | 已验收的 CapturedFrame/clipboard | 多个 NSPanel、鼠标穿透和恢复、内存管理 |
| Annotations | PixelRect + 合成流水线 | 可撤销的矢量/像素操作，不修改源图 |
| Recognition | CapturedFrame 与选区 | Vision OCR、QR，本地按需执行 |
| LongCapture | CaptureService + 独立磁盘分段 | 手动采样、可信拼接、暂停/复核、流式 PNG |

## 7. 官方参考

- [Apple ScreenCaptureKit 捕获说明](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos)
- [SCScreenshotManager 单帧捕获](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager)
- [NSWindow CollectionBehavior](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct)
- [Vision RecognizeTextRequest](https://developer.apple.com/documentation/vision/recognizetextrequest)
