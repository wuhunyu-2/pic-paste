# PicPaste repository initialization implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. This document defines file responsibilities and checks, **not** live task progress; current status belongs to GitHub Issues.

**Goal:** 初始化 `wuhunyu-2/pic-paste` 的规范、资料索引、SVG 品牌资源和 GitHub Issue 驱动的开发任务流程。

**Architecture:** 根目录 `AGENTS.md` 仅作为索引；长期文档位于 `doc/`；原生应用资源位于 `assets/logo/`；动态任务信息只在 Issues。文档按变更触发器持续修订。

**Tech Stack:** Markdown, SVG, Git, GitHub Issues / PRs。Swift 6.4 + macOS 27 应用将在 P0-01 单独实现。

## Global Constraints

- 唯一产品平台 macOS 27 arm64，Swift 6.4、AppKit + SwiftUI。
- 不在文档初始化任务中宣称已实现可安装截图应用。
- SVG 为 Logo 设计单一源；无 PNG 内嵌。
- GitHub Issues 是进度唯一事实来源，不能存第二套进度台账。

## Deliverable 1: Source-of-truth documents and logo

**Files:** `AGENTS.md`, `README.md`, `doc/README.md`, `doc/requirements.md`, `doc/architecture.md`, `doc/development.md`, `doc/acceptance.md`, `doc/documentation-policy.md`, `doc/branding.md`, `doc/retrospective.md`, `doc/decisions/*.md`, `assets/logo/picpaste.svg`.

**Interfaces:** AGENTS.md/README.md 链接到既有文件；README 和 branding 展示同一 SVG；文档变化由 documentation-policy 触发。

- 验证全部相对链接存在、SVG XML 可解析、viewBox=1024×1024、没有 image/base64 外部嵌入。
- 验证文档没有声称已通过 CI 或设备验收；保留旧仓库需求映射但不直接复用 Rust 实现。

## Deliverable 2: GitHub task ledger

**Files:** `.github/ISSUE_TEMPLATE/bug_report.yml`, `.github/ISSUE_TEMPLATE/config.yml`, `.github/PULL_REQUEST_TEMPLATE.md`；动态 Issue 不写入文件。

**Interfaces:** P0 至 P5 的各任务 Issue 必须附需求/架构/验收链接、实际任务范围、依赖和明确的完成证据；PR 关联 Issue 并报告文档更新情况。

- 创建一次性的初始任务 Issues；不要把 issue-seed 的副本长期提交到仓库。
- 通过 GitHub issue 列表核对标题和数量；不在 README 增加任务状态快照。

## Deliverable 3: Repository verification

**Files:** `.gitignore`, `.github/PULL_REQUEST_TEMPLATE.md`.

- 初始化 `main` 的提交，并读取远端 `AGENTS.md`、SVG 及文档确认其可访问。
- 在首个开发 Issue 中说明项目缺少 Xcode 工程、CI 和可安装 App，作为下一任务的交付范围。
- 后续按 `doc/plans/p0-screenshot.md` 推进，不跳过真实 macOS 27 设备验收。
