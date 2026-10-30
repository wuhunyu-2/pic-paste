# 测试与验收标准（macOS 27）

## 1. 四种互不等价的状态

| 状态 | 准确含义 | 必须证据 |
| --- | --- | --- |
| `CODE_DONE` | 功能代码和相关测试已提交 | PR / commit / 测试说明 |
| `CI_PASSED` | 正确 SHA 上的自动化流水线成功 | GitHub Actions run 链接 |
| `ARTIFACT_BUILT` | 已生成可供用户下载的 arm64 开发 App | ZIP / DMG、SHA256、Bundle ID、版本 |
| `DEVICE_VERIFIED` | macOS 27 真机完成规定的交互操作 | 设备 OS build、复现步骤、截图/录屏、实际结果 |

Issue 不得因为 `CI_PASSED` 自动跳过 `DEVICE_VERIFIED`。最终状态记录在 Issue 评论/验收勾选，不复制到本文件。

## 2. P0 自动化门槛

- xcodebuild 在 `xcode-27` arm64 上完整构建成功，运行 Swift 6 严格并发检查和测试。
- 坐标映射单元测试至少覆盖单屏 1×、Retina 2×、副屏在左/上方（负全局坐标）、非整数缩放比例（若实际可用）、越界拖动、空选区、八手柄反向拖动。
- 截图状态机测试至少覆盖：重复触发、取消、权限失败、屏幕断连、回调迟到、保存失败和返回 idle。
- P0-02 全局热键单测覆盖：默认注册及事件传递、冲突后旧绑定保留、成功替换旧绑定释放、重复注册幂等、退出清理，以及重复截图请求被拒绝。注册与焦点在 macOS 27 真实桌面的测试仍单独记录，不以单元测试替代。
- PNG 回归用已知像素图片验证：裁剪尺寸、角半径 0 和非 0、边界透明 Alpha、连续导出不会覆盖旧文件、剪贴板与文件为同一合成源。
- 生成 ad-hoc 开发 `.app`，ZIP 内记录 commit SHA；不得把没有实际构建的文档包称为可安装版本。
- P0-03 的 generation 状态机单测覆盖：并发触发拒绝、取消后迟到结果无效、失败后可重试、旧失败不影响新会话、成功后保持会话直到用户确认，以及负坐标元数据保持原值。TCC 首次授权/撤销/重新授权、显示器拔插与实际无污染源图必须由 macOS 27 设备另行核验。

## 3. P0 macOS 27 真机矩阵

| 场景 | 必须观察 |
| --- | --- |
| 首次授权 | 拒绝后正确提示，授权后可截图，撤销后可恢复 |
| 热键 | 菜单栏及快捷键均能启动；Escape 不遗留覆盖屏幕的隐形窗口 |
| 标准选区 | 拖动、移动、八方向调节、Enter、Esc，输出区域与屏幕相符 |
| Retina 与显示器 | 1×/2×，副屏负原点、不同排列和断连事件不会截错屏 |
| Space / 全屏 | 常规桌面、全屏应用、Stage Manager（如有）不产生不可恢复的焦点问题 |
| 剪贴板 | Preview、Notes 等系统应用可粘贴，内容及透明角一致 |
| 保存 | PNG 在 Finder/Preview 可打开、像素尺寸正确、不静默覆盖 |
| 自有窗口 | 重复截图无截图浮层或贴图残影；失败时不留下鼠标拦截层 |
| 稳定性 | 连续操作不少于 30 次（正常、取消、再捕获）无死锁或明显泄漏 |

记录 Mac 型号、芯片、macOS 27 的精确 build、显示器布局/缩放、使用的 App SHA、每项实际结果。没有第二显示器时如实记录“未执行”，相关验收不能宣称完成。

## 4. 后续质量评估目标（不是未经验证的保证）

- 旧版本目标可以作为测量参考：30 次冷启动 P95 ≤ 1.5s；100 次热键响应 P95 ≤ 200ms；空闲 CPU ≤ 0.5%、RSS ≤ 80 MiB；5 张 1080p 贴图帧 P95 ≤ 16.7ms。先明确起止采样点和硬件再决定是否成为发行阻断阈值。
- OCR 评测可沿用至少 400 张中英混合图片的测试集，记录 CER/定位命中率；在测量之前不写死为已达标。
- 手动滚动长截图至少 50 个实际网页/文档场景，统计可信拼接成功率、错误拒绝与恢复，覆盖动态内容、固定栏、重复图案、长图边界和内存。
- 正式发行前确认真实 Developer ID、公证、首次下载 Gatekeeper、权限保持和回滚行为；开发 ad-hoc 包不等同于正式发行包。

## 5. 关闭 Issue 的证据模板

在对应 Issue 评论或 PR 中提供：准确功能和失败复现方式、commit SHA、CI run、开发 App artifact、设备环境与真实操作步骤、通过/失败和剩余风险。没有设备可测试时可完成代码 PR，但将设备验收 Issue 保持 Open。


## 6. P0-07 本地采证脚本（辅助工具，不代替真机验收）

针对 GitHub Actions 产出的 `PicPaste-macOS27-arm64-unsigned` artifact，在 macOS 27 真机上下载并解压 artifact 外层 ZIP（其中应有 `SOURCE_SHA.txt`、`CHECKOUT_SHA.txt`、`SHA256SUMS` 和 `PicPaste-macOS27-arm64-unsigned.zip`），从项目根目录执行：

```bash
bash scripts/collect-p0-evidence.sh /path/to/extracted-artifact > p0-07-device-evidence.md
```

脚本在本机校验 **App ZIP 的 SHA256 与同一 artifact 内的 SHA256SUMS 是否一致**，并记录源码 SHA、实际 checkout SHA、macOS 版本与精确 build、设备型号、架构、芯片信息以及经过白名单过滤的显示器分辨率摘要；不会把显示器序列号或原始系统报告放入结果，也不会上传任何数据。SHA256 不匹配、缺失必需来源文件时直接失败。

生成的 Markdown **默认所有操作均为“未执行”**。人工运行开发 App 后，逐行将结果填写为 PASS / FAIL / BLOCKED，补充截图/录屏、外接显示器排列与缩放、测试实际步骤和失败 Issue；再将已填写的报告附到 #7。即使本脚本成功，`DEVICE_VERIFIED` 仍为 NO。脚本的 GitHub Actions 测试只使用合成输入，不能当作物理设备验证。

P0 验收最终是否通过，仍依照第 3 节完整真机矩阵和 Issue #7 人工证据决定。

## 7. GitHub-hosted macOS 的桌面窗口探针

CI 在 `xcode-27` 环境执行 `xcrun swift scripts/tests/macos_desktop_session_probe.swift`，尝试创建、显示和关闭一块 AppKit `NSPanel`，并打印当前虚拟显示器数量、Screen Recording 与 Accessibility 的既有授权状态。首次引入时设置 `continue-on-error: true`，因为它是对 runner 是否存在可用 WindowServer 图形会话的**探测**，不应在能力确认前直接阻断已有测试。`CI_DESKTOP_PROBE_RESULT=PASS` 只能证明 CI 会话可以进行基础 AppKit 窗口生命周期操作；`UNAVAILABLE` 或脚本失败则意味着需要确认运行环境，不代表 App 功能故障。

在 `PicPasteTests.swift` 中基于合成 `CapturedFrame` 测试 PicPaste 自身 `SelectionPanelController` 的原生 `NSPanel` 显示、主动关闭、重复打开时旧窗口清理和取消回调幂等；这些 XCTest 可在 runner 的 WindowServer 会话上运行，但不需要真实屏幕捕获权限或硬件交互。下一步可进一步扩展事件注入及实际 ScreenCaptureKit 测试，并分别检查进程级 TCC 权限，而不是从独立 Swift 探针推断 App 授权。ScreenCaptureKit 首次 TCC 授权、真实多显示器负坐标与物理显示器连接、Spaces/全屏、用户级焦点恢复及系统应用粘贴，仍需对照第 3 节的真实设备证据验收。禁止将 CI 的虚拟面板显示结果替换 `DEVICE_VERIFIED`。


## 8. CI ScreenCaptureKit 实际截图与隔离剪贴板测试

`scripts/tests/macos_capture_session_probe.swift` 在 GitHub-hosted `xcode-27` 图形会话中先检查 **当前探针进程** 的 `CGPreflightScreenCaptureAccess()`，只有已授权才调用 `SCShareableContent`、`SCContentFilter` 和 `SCScreenshotManager.captureImage` 做单帧截图。结果仅打印屏幕 ID、图像宽高及 `CI_SCK_PROBE_RESULT`，**不会保存、上传或输出屏幕像素**；运行设置 `timeout-minutes: 3`，能力探测阶段使用 `continue-on-error: true`，日志中 `PASS` 才能视为真实捕获通过，单看 GitHub step 的绿色标记不够。宿主进程的 TCC 许可不能推断最终 App 在用户电脑上的授权流程。

`PicPasteTests/PNGExportTests.swift` 使用独立命名的真实 `NSPasteboard` 做 PNG 字节复制、回读和 ImageIO 解码回归，不碰用户正在使用的 `NSPasteboard.general`。生产代码默认仍写入 `.general`，可选的 `to:` 参数只用于可隔离的依赖注入。这可以在 CI 检查本机写入和读回，但 **Preview/Notes 真实粘贴、首次许可、跨显示器、Space 和焦点恢复**仍按第 3 节交付真机证据；不能因为单帧与剪贴板 CI 成功就将 Issue #7 标为 `DEVICE_VERIFIED`。

## 9. CaptureService 源码实调、30 次选区循环和 Escape 自动化

- `PicPasteTests.swift` 的 `testThirtySelectionSessionsReturnToIdleWithoutStaleOverlay` 用真实 `SelectionPanelController`、`SelectionView`、`CaptureCoordinator` 进行 30 次循环：每次模拟状态机的截图成功，创建 NSPanel，取消两次并校验仅回调一次、没有残留的可见选区窗口以及状态返回 `idle`。这属于 **合成冻结图像 + 真实 AppKit 窗口** 的自动化回归，不代表连续 30 次屏幕实际采集成功。
- `testSyntheticEscapeKeyClosesRealSelectionPanelOnce` 构造 `NSEvent.keyDown`（Escape），直接发送到实际 `SelectionView.keyDown`，检查关闭与回调幂等；这不等于物理键盘或全局快捷键实际输入验证。
- `testRealCaptureServiceOnAuthorizedDesktop` 尝试由实际 XCTest 宿主运行 `CaptureService.captureMouseDisplay`；若宿主进程未被 TCC 预授权或鼠标不在屏幕内，会以 **XCTSkip** 明确跳过。**跳过必须记录为未测试，不能计为成功。**
- 为减少 XCTest 宿主 TCC 限制，CI 另用 `xcrun swiftc` 将仓库中的 **原始** `CaptureService.swift`、`CapturedFrame.swift`、`ScreenPermissionService.swift` 与 `scripts/tests/macos_capture_service_probe.swift` 编译为单独的探测程序。该程序只在其自身已获得屏幕录制预授权时调用 `captureMouseDisplay`，仅输出尺寸、displayID、错误类型与 `CI_APP_CAPTURE_SERVICE_RESULT`，不保存或上传图片。该生产源码实调已在 PR CI 输出过 `CI_APP_CAPTURE_SERVICE_RESULT=PASS`，随后升级为**强制 CI 门槛**（不设置 `continue-on-error`）：缺少权限、没有鼠标所在显示器、捕获失败或编译失败均导致该步骤失败。必须同时检查日志中的 `CI_APP_CAPTURE_SERVICE_RESULT=PASS` 和正确 SHA 的 Actions 结果，不能将独立探针成功推断为 XCTest 宿主的 TCC 通过。
- 所有这些 CI 测试仍发生在托管的虚拟 macOS 图形会话中，不能替代第 3 节所要求的首次 TCC 授权/撤销、真实多屏、Spaces、物理焦点恢复和跨应用粘贴。只有真实环境证据可设置 `DEVICE_VERIFIED`。

## 10. 选区原生鼠标事件到 PNG / 剪贴板的 CI 集成回归

`PicPasteTests/PicPasteTests.swift` 在 macOS runner 创建真实的 `SelectionPanelController`、`NSPanel`、`SelectionView`，用构造的 `NSEvent.mouseEvent` 调用视图的 `mouseDown`、`mouseDragged`、`mouseUp`，再使用构造的 Enter `NSEvent.keyDown` 确认：

- 拖选后断言 `PixelRect` 的确切源像素坐标，并将同一个合成冻结 `CGImage` 交给 `ImageComposer` 与 `PNGExporter`，通过 ImageIO 解码核验输出宽高，写入独立命名的真实 `NSPasteboard` 并回读原始 PNG 字节。
- 拖选后再在选区内部拖动，核验移动和 AppKit y-up → CGImage y-down 映射后的确切像素坐标。
- 分别操作八个选区调整手柄（上左、上、上右、右、下右、下、下左、左），断言完成回调仅一次、像素裁剪位置和尺寸正确、窗口清理完成。

这些测试验证的是**生产 AppKit 视图及窗口的事件处理**，而非纯几何函数；但事件由 XCTest 构造并直接送入 NSResponder 方法，冻结图像为合成数据，并不模拟操作系统全局鼠标投递、物理光标焦点、首次 TCC、真实多显示器/Spaces 或 Preview/Notes 跨进程粘贴。不可据此把 P0-07 标记为 `DEVICE_VERIFIED`。实际鼠标与设备场景仍遵循第 3 节记录。


## 11. CI 真正截图 → 原生选区 → PNG → 隔离剪贴板的端到端链路

`.github/workflows/ci.yml` 通过 `xcrun swiftc` 编译 `scripts/tests/macos_live_capture_selection_export.swift`，直接链接仓库中的 **生产源码** `CaptureService`、`CaptureCoordinator`、`SelectionPanelController`、`SelectionView`、`SelectionInteraction`、`SelectionGeometry`、`ImageComposer`、`PNGExporter`、`ClipboardWriter` 及相关类型。该 CI 步骤为 **强制门槛**，不使用 `continue-on-error`。

执行顺序：

1. 检查运行该程序的 CI 进程已具备屏幕录制权限、鼠标位于可见显示器；由 `CaptureService.captureMouseDisplay` 真正调用 ScreenCaptureKit 冻结源 `CGImage`，检查捕获权限回调次数和截图像素尺寸。
2. 通过实际 `CaptureCoordinator` 管理截图会话，再用真实 AppKit `NSPanel` / `SelectionView` 显示**先前已经捕获**的冻结画面；以合成 `NSEvent` 发送画面中央区域的 mouseDown / mouseDragged / mouseUp / Enter，检查选区完成一次、无残留可见浮层、状态返回 idle。
3. 用与 `SelectionGeometry` 独立计算的按屏幕 points→图像 pixels 期望矩形，验证 y-up / y-down 映射和裁剪区域；使用生产 `ImageComposer` 和 `PNGExporter` 编码，再经 ImageIO 解码，断言像素尺寸与期望裁剪一致。
4. 将同一份 PNG 数据写入**独立命名的真实** `NSPasteboard`，读回验证字节完全一致，退出前清空；无截图图片文件、图像二进制、像素值或粘贴内容上传到 Actions artifact 与日志。

日志分别打印 `CI_PICPaste_E2E_CAPTURE=PASS`、`CI_PICPaste_E2E_SELECTION=PASS`、`CI_PICPaste_E2E_PNG=PASS`、`CI_PICPaste_E2E_PASTEBOARD=PASS`，最后必须有 `CI_PICPaste_E2E_RESULT=PASS` 和同一来源 SHA 的 GitHub Actions 成功记录。

**能力边界**：CI 是虚拟 macOS 图形会话；鼠标、Enter 为代码直接投递给生产视图的合成 NSEvent，未验证真实外设输入、系统级事件派发、首个 TCC 弹窗与拒绝/撤销/恢复、真实双屏、全屏 Spaces、用户焦点与 Preview/Notes 跨应用粘贴。不能因为该 CI 步骤成功而关闭 Issue #7 或标记 `DEVICE_VERIFIED`。最终真机验收仍遵守第 3 节。


## 12. CI 自身窗口排除阳性对照和连续真实捕获

`scripts/tests/macos_capture_own_window_repeat.swift` 在 `xcode-27` 托管 macOS 图形会话中，以**当前截图进程自身**创建可见、纯洋红色的原生 `NSWindow`。首先用未过滤的 `SCScreenshotManager.captureImage` 获取阳性对照，验证该窗口确实出现在画面内；若看不到窗口，该测试**失败**，不能用虚假的“未污染”结果冒充成功。

随后保持窗口可见，重复 **8 次**调用生产 `CaptureService.captureMouseDisplay`，逐次核验：截图授权完成回调恰好一次、显示器标识/原生屏幕坐标与尺寸一致、捕获 `CGImage` 的宽高合法，并确认窗口中心采样像素中**不再出现阳性对照的洋红色标记**。这项检查直接测试生产服务的 ScreenCaptureKit 排除策略，而不是单独构造一个模拟过滤器。测试返回时关闭窗口，图像仅在内存中作必要的局部像素判断，不写入磁盘、不上传到 CI Artifact、不输出任何截屏像素值。CI 为强制门槛（无 `continue-on-error`）；日志以 `CI_OWN_WINDOW_POSITIVE_CONTROL=PASS`、`CI_OWN_WINDOW_EXCLUSION=PASS`、`CI_REPEATED_REAL_CAPTURES=8` 和 `CI_OWN_WINDOW_REPEAT_RESULT=PASS` 为成功证据。

**限制**：测试窗仅覆盖采样位置，用于证明在托管 macOS runner 上自身窗口排除的一个实际案例，并不证明任意位置、所有窗口类型或跨 Spaces 都完全排除。8 次连续真实捕获也不等于第 3 节要求的至少 30 次真实设备键鼠截图、取消和再捕获压力验收；真实多屏、用户首次 TCC、应用焦点及原生粘贴仍需实机证据，`DEVICE_VERIFIED` 仍取决于 Issue #7 的真机记录。

## 13. 预先取消截图的错误归一化与重试

P0-32 回归验证使用独立的 macOS CI 进程，在 Screen Recording 已被预授权的情况下，先创建一个进入 `CaptureService.captureMouseDisplay` 前**主动标记取消**的 Swift `Task`。断言服务抛出公共类型 `CaptureFailure.cancelled`，且尚未开始真正截图的任务不调用 `onAuthorizationComplete`；否则强制 CI 失败。随后同一个测试脚本继续调用真实 `CaptureService` 获取画面，作为失败后可以重新截图的基本证据。修复前 CI 已重现：`Task.checkCancellation()` 在内部异常转换范围外，原生 `CancellationError` 逸出；通过将检查纳入既有 `do/catch` 归一化，不绕过 TCC。

这只覆盖**事先取消**与后续成功的单进程 CI 路径，不等同于首次 TCC 授权弹窗期间取消、用户桌面中途取消、跨 Space 取消或异常系统失败重试。相关真实设备结果继续按第 3 节收集。
