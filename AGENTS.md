# AGENTS.md — PicPaste agent 入口索引

此文件**只提供权威入口与必要的行为提醒**；不要在此复制需求细节、技术方案、Task 清单或实时进度。

| 场景 | 必读来源 |
| --- | --- |
| 项目定位、资源和开始方式 | [README.md](README.md) |
| 文档导航 | [doc/README.md](doc/README.md) |
| 产品范围、需求和排除项 | [doc/requirements.md](doc/requirements.md) |
| Swift / AppKit 架构与像素坐标约定 | [doc/architecture.md](doc/architecture.md) |
| 开发协作、Git、变更流程 | [doc/development.md](doc/development.md) |
| CI、设备验收和证据标准 | [doc/acceptance.md](doc/acceptance.md) |
| **文档持续维护规则** | [doc/documentation-policy.md](doc/documentation-policy.md) |
| UI 与 Logo 资源 | [doc/branding.md](doc/branding.md) |
| 历史经验 | [doc/retrospective.md](doc/retrospective.md) |
| 已采纳架构决策 | [doc/decisions/](doc/decisions/) |
| P0 方案和任务顺序 | [doc/plans/p0-screenshot.md](doc/plans/p0-screenshot.md) |
| **唯一实时任务/进度/阻塞/验收记录** | [GitHub Issues](https://github.com/wuhunyu-2/pic-paste/issues) |
| 代码变更与证据 | [GitHub Pull Requests](https://github.com/wuhunyu-2/pic-paste/pulls) |

**每次开工**：查看所选 Issue、相关文档及其依赖；不要全文加载不相关文档。

**每次交付**：检查是否改变了需求、架构、接口、实现约定、验收方法、工具命令或文档路径。若改变，**在同一个 PR 中主动更新对应文档及必要的 ADR、索引和链接**。文档是持续演进的工程资产，**不是写一次就永久冻结**；不能以“文档已经创建”为由拒绝必要更新。若只改变任务进度，则仅更新 Issue，不在文档中复制完成率或最新 CI 编号。

**完成声明**：区分代码完成、CI 通过、安装包生成和 macOS 27 真机验收；任何阶段的完成状态以 Issue 中可核验的证据为准。
