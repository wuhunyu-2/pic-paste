# P0 Native Screenshot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. 若当前 agent 环境未安装上述 Skill，执行时直接按下文 Issue/PR 验收，不自行假设已加载。

**Goal:** 交付 macOS 27 / arm64 上真实可用的“快捷键 → 冻结截图 → 原生区域选取 → 复制或保存 PNG”闭环。

**Architecture:** SwiftUI 设置和应用入口，AppKit 菜单栏/浮层，ScreenCaptureKit 截图，Core Graphics / Image I/O 导出。采用单独的 `CaptureCoordinator` 管理截图生命周期，所有坐标/裁剪逻辑先在纯 Swift 中验证，再连接 NSPanel。任务进度仅通过 GitHub Issues 记录。

**Tech Stack:** Swift 6.4, macOS 27 SDK, AppKit, SwiftUI, ScreenCaptureKit, Core Graphics, Image I/O, XCTest, GitHub Actions `xcode-27`.

## Global Constraints

- Target macOS 27.0+ and arm64 only.
- Native Swift, no Rust/egui/WGPU/Electron/WebView or network services.
- Output PNG only; alpha radius 0–64 source physical pixels.
- No new major phase until P0 `DEVICE_VERIFIED` evidence in macOS 27 Issue.
- AGENTS.md remains an index; no duplicate progress documents.

---

## Planned file map

实现文件责任与接口见 [architecture.md](../architecture.md) 第 3–4 节。所有路径在创建 Xcode 工程后依约落地。新项目首阶段从完整应用启动和截图闭环开始，不提前实现贴图、OCR、长图。

### Task 1 / Issue [P0-01]：创建原生 Xcode 工程与 CI

**Files:** `PicPaste.xcodeproj/project.pbxproj`, `PicPaste/App/PicPasteApp.swift`, `PicPaste/App/AppCoordinator.swift`, `PicPaste/App/MenuBarController.swift`, `PicPasteTests/`, `.github/workflows/ci.yml`, `.gitignore`。

**Interfaces:** SwiftUI App 通过 `AppCoordinator` 访问菜单栏操作，提供可测试的“开始截图”入口；后续注入捕获服务。必须使用可检查进程、可启动窗口的真正 `.app` bundle。

- [ ] 创建 Xcode macOS App 工程（Swift 6 语言模式、arm64、deployment target 27.0），确认 bundle 启动和菜单栏图标存在。
- [ ] 添加最小 XCTest target 与启动/配置测试。
- [ ] 使用 `xcodebuild -project PicPaste.xcodeproj -scheme PicPaste -destination 'platform=macOS,arch=arm64' test` 验证本机和 CI 行为（如实际 scheme 不同，在 PR 中统一更新文档和 CI）。
- [ ] 配置 `.github/workflows/ci.yml` 使用 `runs-on: xcode-27`；记录 `xcodebuild -version`、`sw_vers` 和 commit SHA。
- [ ] 产出 ad-hoc 开发 `.app` 并归档 ZIP；记录 Bundle ID、源码 SHA、文件 SHA256。不能声称已通过真机验收。
- [ ] 提交最小 PR，并由 GitHub Actions 验证。

### Task 2 / Issue [P0-02]：菜单栏与全局快捷键

**Files:** `PicPaste/App/MenuBarController.swift`, `PicPaste/Hotkeys/GlobalHotkeyManager.swift`, `PicPaste/Settings/AppSettings.swift`, `PicPasteTests/HotkeyStateTests.swift`。

**Interfaces:** `GlobalHotkeyManager` 把截图事件交给 `@MainActor CaptureCoordinator`，重复触发时按预定状态处理；注册失败不得丢失现有已生效快捷键。

- [ ] 先设计可测试的注册/反注册状态机及失败回滚测试；优先验证系统全局热键适配方式，不通过事件监听偷取键盘输入。
- [ ] 实装菜单栏截图、设置、退出命令，以及默认稳定快捷键；第二次截图请求不会生成多个选区窗口。
- [ ] 测试热键冲突、应用退出取消注册、连续触发、输入框焦点与系统保留组合键。
- [ ] 将真机注册与菜单交互情况记录到对应 Issue。

### Task 3 / Issue [P0-03]：ScreenCaptureKit 权限与冻结图像

**Files:** `PicPaste/Capture/ScreenPermissionService.swift`, `CaptureService.swift`, `CapturedFrame.swift`, `CaptureCoordinator.swift`, `PicPasteTests/CaptureStateTests.swift`。

**Interfaces:** `CaptureService` 接受目标显示器 ID 返回 `CapturedFrame`（源 `CGImage` + 桌面 points 元数据 + 显示器局部 pixel size）。输出错误类型明确区分权限拒绝、目标消失、系统失败与取消。

- [ ] 为捕获过程编写取消、重复触发、权限拒绝和过期结果回调测试。
- [ ] 通过 SCShareableContent 找到鼠标所在显示器，使用 SCContentFilter 与 SCScreenshotManager 获取冻结画面。
- [ ] 把错误反馈显示给用户；确认一次失败后状态恢复 `idle`，不会留下后台采集流和透明拦截窗。
- [ ] 在真实 macOS 27 测试首次允许、拒绝、撤销许可与系统设置恢复。

### Task 4 / Issue [P0-04]：纯 Swift 几何及选区状态

**Files:** `PicPaste/Selection/SelectionGeometry.swift`, `PicPasteTests/SelectionGeometryTests.swift`。

**Interfaces:** 输入目标屏幕的 `desktopFramePoints`、`imageWidthPixels/imageHeightPixels` 和 NSView 局部 point rect，输出规范化的 `PixelRect`，保证 `x/y >= 0`、`width/height > 0`、右下不越界；必须明确定义 y 轴方向。

- [ ] 先写失败测试：1×、2×、负全局原点、边界裁剪、零面积、角与边的八手柄、反向拖动、整数取舍。
- [ ] 实现 display-local points → source pixels 的纯函数；不使用全局 origin 乘 scale。
- [ ] 对测试数据逐像素比较输出矩形，与同源的 CGImage cropping 语义匹配。
- [ ] 运行选区测试并确认无越界或反向 Rect。

### Task 5 / Issue [P0-05]：真正 AppKit NSPanel 截图浮层

**Files:** `PicPaste/Selection/SelectionPanelController.swift`, `SelectionView.swift`, `PicPaste/Capture/CaptureCoordinator.swift`。

**Interfaces:** 浮层只能接收 Task 3 的不可变 `CapturedFrame`；对外返回 `PixelRect` 或 cancel。`Escape`、窗口关闭、显示器断连最终只结束一次截图会话。

- [ ] 先实现纯选区层与鼠标/键盘状态转移测试。
- [ ] 建立 AppKit `NSPanel` 和 `NSView`，展示同一冻结 `CGImage`，不复用旧 eframe/winit 或另开 Helper 进程。
- [ ] 实现拖动选取、移动、八手柄、Esc、Enter 和失焦/关闭恢复。
- [ ] 在 macOS 27 真机验证 Retina、1×/2×、负原点、全屏 Spaces、焦点与窗口清理；保存失败录屏和日志到 Issue。

### Task 6 / Issue [P0-06]：PNG / 剪贴板与透明圆角

**Files:** `PicPaste/Export/ImageComposer.swift`, `PNGExporter.swift`, `ClipboardWriter.swift`, `PicPasteTests/PNGExportTests.swift`。

**Interfaces:** `ImageComposer` 输入 `CGImage + PixelRect + cornerRadiusPx`，生成同一不可变裁剪图，分别交给 Image I/O PNG 与 NSPasteboard，不能分别重复计算不同像素结果。

- [ ] 使用已知 RGBA 测试图片先写裁剪、0/64 半径、Alpha 四角及无覆盖保存回归。
- [ ] 建立原子化 PNG 保存和时间戳命名；失败时不破坏既有文件。
- [ ] 通过 NSPasteboard 复制真实图像，测试 Preview/Notes 等应用粘贴；保持原生图像而非只复制文件路径。
- [ ] 产出可安装的 P0 App artifact，记录来源 SHA 和 ZIP SHA256。

### Task 7 / Issue [P0-07]：独立真机验收门槛

**Files:** 不修改功能代码；如发现 Bug，应新建/关联 Issue 并以独立 PR 修复。证据直接上传 GitHub Issue，不写进 README 状态摘要。

- [ ] 严格执行 [acceptance.md](../acceptance.md) 第 3 节的真机矩阵，逐条登记实际结果。
- [ ] 验证构建 SHA、macOS 27 build、处理器、显示器信息与录屏；需测试真实 TCC、热键、Spaces、选区、复制和 PNG。
- [ ] 缺少多显示器或设备证据时保持 Issue Open；不以 CI 或截图模拟冒充设备验收。
- [ ] 所有 P0 阻断缺陷关闭后，才允许启动 P1 的实际功能开发。

## 校验清单

- P0 有完整需求映射：R-001→Task 1/2，R-002→Task 3，R-003→Task 4/5，R-004/005→Task 6，R-006→Task 4/7，R-007→Task 1/7。
- 文件路径与 `architecture.md` 对齐，后续阶段无空壳文件预建。
- 所有新代码在创建真实 Xcode 工程后由 Xcode 27 编译验证；此文档是执行计划，而不是已经执行的代码或设备测试证明。
