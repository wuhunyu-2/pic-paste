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

下一步可在此基础上添加针对 PicPaste 自身 `SelectionPanelController` 的 AppKit 生命周期测试，并逐步覆盖非真实权限相关的自动化交互。ScreenCaptureKit 首次 TCC 授权、真实多显示器负坐标与物理显示器连接、Spaces/全屏、用户级焦点恢复及系统应用粘贴，仍需对照第 3 节的真实设备证据验收。禁止将 CI 的虚拟面板显示结果替换 `DEVICE_VERIFIED`。
