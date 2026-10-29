# 旧 PicPaste 复盘与新项目需求迁移

原始仓库：[wuhunyu/pic-paste](https://github.com/wuhunyu/pic-paste)。参考其 [README](https://github.com/wuhunyu/pic-paste/blob/main/README.md)、[原始 TASKS](https://github.com/wuhunyu/pic-paste/blob/main/docs/TASKS.md)、[状态记录](https://github.com/wuhunyu/pic-paste/blob/main/docs/STATUS.md) 和 [窗口策略](https://github.com/wuhunyu/pic-paste/blob/main/docs/macos-window-strategy.md)。

## 1. 可核实的旧项目现象

- 旧项目采用 Rust + egui/eframe + wgpu，集成原生 ScreenCaptureKit、Swift Vision IPC、macOS AppKit 探针，产生多层交互/渲染边界。
- 大量代码任务和 CI 已完成，但主流程仍依赖原 eframe/winit 浮层，独立 NSPanel 的真机交互、IME、Retina、Spaces、TCC 等长期没有完整设备验收；这不是“所有旧代码无效”。
- 旧仓库明确强调“代码完成 ≠ CI 通过 ≠ 真机验收”；新项目把这种区分提前到 P0，而不是等发行阶段才处理。
- 原需求范围曾覆盖截屏、贴图、标注、OCR/QR、长截图、Lite/Full/Add-on、Windows。首次闭环前多子系统并行会增加偏移风险；新项目按依赖顺序分层交付。

## 2. 迁移策略（需求迁移，不是代码迁移）

| 旧需求 | 新项目处理 |
| --- | --- |
| 区域截图、冻结像素、放大镜、窗口检测 | 保留；截图核心 P0，取色/窗口检测 P1 |
| PNG-only、透明圆角、剪贴板 | 保留；纳入 P0 |
| 八手柄选区、Esc/Enter、焦点控制 | 保留；直接用 AppKit NSPanel 实现并真机验收 |
| 悬浮贴图、缩放、透明度、鼠标穿透 | 保留；独立 P1，保证恢复入口 |
| 线/箭头/画笔/几何/文字/模糊/马赛克 | 保留；P2 非破坏性标注 |
| Vision OCR、二维码 | 保留；P3 直接使用 Swift Vision，无需 IPC Helper |
| 用户手动纵横滚动、自动拼接、错误恢复 | 保留；P4，暂不实现自动滚动 |
| Windows、跨平台内核 | 删除；仅 macOS 27 / arm64 |
| Lite/Full/Add-on 与跨进程通信 | 删除；首版单一原生 App |
| 旧 CI 和 Release 制品 | 不作为新仓库任何功能验收证据 |

## 3. 防止再次偏移的机制

1. 最小原生截屏闭环优先；P0 必须真实鼠标、权限、剪贴板和 PNG 验收。
2. GitHub Issue 有清晰依赖与可反证的验收条件，不能用多 PR 数量替代产品结果。
3. AppKit 负责截图浮层、贴图，不先采用跨框架渲染；避免“原生实验浮层长期不能替换正式 UI”。
4. `AGENTS.md` 只索引，稳定设计放 doc，活跃进度只在 Issues，减少多个状态源矛盾。
5. 发现需要改变功能范围、架构或可验收事实时，先记录 Issue + ADR 再推进。

## 4. 不作为事实的判断

“旧项目失败完全因为 Rust”只是推测，无法仅凭代码推导；新选型是针对单一 macOS 27 目标做取舍。旧仓库的既有功能实现与 CI 可以作为设计参考，但不能复用其验收结论。
