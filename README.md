# PicPaste — 原生 macOS 27 截图与贴图

![PicPaste Logo](assets/logo/picpaste.svg)

> **持续开发中的 macOS 原生项目。** 仓库包含 Xcode 工程、代码、CI 和 SVG 资源；分阶段实现与真机验收以 GitHub Issues / PR 为准。CI 成功不代表截图闭环或 macOS 27 真机验收已完成。

PicPaste 是以 **Swift 6.4 + AppKit + SwiftUI** 开发的 Apple Silicon 原生 macOS 27 截图工具，追求离线、轻量、快速、稳定的屏幕截图、标注和贴图体验。

## 约束

- 唯一目标：macOS 27.0+、arm64（Apple Silicon）。
- Apple 原生技术：AppKit、SwiftUI、ScreenCaptureKit、Core Graphics、Image I/O、Vision。
- 完全离线；不使用 Electron、WebView、Rust、egui、WGPU 或外部 OCR Helper。
- 截图保存统一 PNG；支持透明 Alpha 和可配置的圆角。
- P0 交付优先：快捷键 → 截屏 → 原生选区 → 复制 / 保存 PNG → macOS 27 真机验收。

## 项目资料

以 [AGENTS.md](AGENTS.md) 作为索引，通过 [文档目录](doc/README.md) 查找需求、架构、开发规范、验收标准、Logo、ADR 和执行计划。规范会随有效设计决策与代码变化及时更新，详见 [文档维护规则](doc/documentation-policy.md)。**任务状态只在 [GitHub Issues](https://github.com/wuhunyu-2/pic-paste/issues) 维护**。

## 历史参考

旧项目 [wuhunyu/pic-paste](https://github.com/wuhunyu/pic-paste) 仅作为功能需求与问题经验来源；不迁移旧 Rust 架构，也不将其 CI 结果等同于新项目的设备验收。
