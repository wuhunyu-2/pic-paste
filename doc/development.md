# 开发规则、Git 流程与决策边界

## 1. 事实来源

- 产品长期范围：`doc/requirements.md`；架构：`doc/architecture.md` 和已采纳 ADR；验收原则：`doc/acceptance.md`。
- **唯一动态进度**：新仓库的 GitHub Issues；不得在 README、状态文档或 AGENTS.md 重复保存实时完成率。
- 当前工作范围：所选 Issue 的背景、依赖、任务及验收清单；PR 解释代码变更、验证方法、CI 与实机证据。
- 有矛盾时先报告，修正 Issue 和相关文档；禁止不通知直接扩大范围、改目标系统或替换已决议技术栈。

## 2. 实施约束

- 所有业务代码为 Swift；原生 AppKit、SwiftUI、ScreenCaptureKit、Vision 与系统库优先。
- 不添加 Rust、WGPU、egui、Electron、WebView 或用于绕开原生 UI 缺陷的旁路 Renderer。
- 不引入新的框架、包管理器或辅助进程，除非 Issue 明确要求且 ADR 已说明必要性与替代方案。
- 只修改当前 Issue 关联模块，不夹带大规模清理、功能扩张或旧系统兼容。适用时先写失败回归，再用最少改动通过。
- UI 的窗口焦点、点击穿透、权限、Retina、Spaces 等不能只凭逻辑模拟或 CI 推断。

## 3. 分支、PR 与提交

1. 从 `main` 建独立 `feat/issue-<number>-<topic>` 或 `fix/issue-<number>-<topic>` 分支；并行任务可用 Git worktree。
2. 每项任务对应可审阅的最小 PR，引用 `Closes #<number>` 仅当满足 Issue 全部关闭条件；否则用 `Refs #<number>`。
3. 先局部编译/测试，再 CI 全量；提交前检查 diff、未追踪文件、隐私信息、生成物和变更范围。
4. 可以按已分配 Issue 自动完成代码、提交、推送任务分支与提出 PR；**正式发布、改变产品范围或架构、关闭需要设备验证的 Issue，均需要可验证的授权或设备证据**。
5. 在 P0 首次真机验收通过之前，不得仅因 CI 绿灯就宣称版本可用、改变默认截图后端或标记 P0 完成。

## 4. AI 决策规则

- 明确的 Issue 范围内实现细节可自主处理；跨模块设计选择先说明备选方案、影响和推荐理由。
- 与架构或需求基线冲突、需要改变技术栈/输出格式/目标 OS、需要新增进程或越过系统权限时停止推进并升级决策。
- 同一假设连续两次验证失败，应给出根因、真实日志和下一步方案，而不是堆积更多模拟测试或无限重试。
- 对外回复必须区分 `CODE_DONE`、`CI_PASSED`、`ARTIFACT_BUILT`、`DEVICE_VERIFIED`。没有证据的状态不允许报告为成功。

## 5. 构建与测试

- 开发机和 GitHub Actions 采用 Xcode 27 / macOS 27 SDK、Swift 6 语言模式、arm64、部署目标 macOS 27.0。
- `PicPaste.xcodeproj` 建好后，以 `xcodebuild -project PicPaste.xcodeproj -scheme PicPaste -destination 'platform=macOS,arch=arm64' test` 等命令作为持续测试入口；具体 scheme/签名环境由首个 Issue 验证并修正。
- GitHub Actions 使用 `xcode-27` runner；每次构建应记录 Xcode 版本、SDK、源码 SHA。CI 可产出 ad-hoc 签名开发包，但不会验证用户桌面 TCC、实际鼠标交互和 Gatekeeper 分发效果。
- QA 答复包含复现步骤、构建 SHA、测试命令、实际结果和未验证边界；用户验收证据直接附到对应 Issue。

## 6. 文档变更（持续维护）

文档不是固定不变的初始化资料。每个 Agent 在修改代码、接口、使用方式、依赖、技术决策或验收标准时，必须检查受影响的文档，必要时在**同一个 PR** 更新；重大取舍需要 ADR，已有 ADR 不应静默覆写历史，应通过新增 ADR 说明取代关系。

入口详细规定见 [documentation-policy.md](documentation-policy.md)。`AGENTS.md` 只在入口/索引变化时更新。任务推进、勾选、阻塞等实时状态仍只写入 GitHub Issues，不需要建立重复的进度文档。
