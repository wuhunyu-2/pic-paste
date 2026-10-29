# 文档目录（长期有效资料）

- [requirements.md](requirements.md)：产品需求、优先级、不可变约束、明确排除项。
- [architecture.md](architecture.md)：Swift 原生技术架构、组件职责、接口和坐标模型。
- [development.md](development.md)：开发和 Git 工作流、设计变更控制。
- [acceptance.md](acceptance.md)：自动化与真机验收的证据标准。
- [documentation-policy.md](documentation-policy.md)：何时必须更新文档、变更职责、PR 校验清单。
- [branding.md](branding.md)：Logo SVG 规范和视觉资产。
- [retrospective.md](retrospective.md)：从旧 PicPaste 保留的需求及应避免的问题。
- [plans/p0-screenshot.md](plans/p0-screenshot.md)：首条完整截图闭环的实施依赖和文件映射。
- [decisions/0001-platform-and-stack.md](decisions/0001-platform-and-stack.md)：仅支持 Swift/macOS 27 的架构决定。
- [decisions/0002-source-of-truth.md](decisions/0002-source-of-truth.md)：资料与进度的唯一事实来源。

## 资料边界

`doc/` 不维护“完成率”、已合并 PR 数、当前 Issue 状态等容易过期的信息。所有任务进展、验收清单和阻塞由 [GitHub Issues](https://github.com/wuhunyu-2/pic-paste/issues) 维护，PR 保存差异、CI 和证据链接。长期文档**必须在设计或代码变更时主动修订**，而不是冻结在创建时的版本。决策改变时编辑相关文档并提交 ADR，不能只修改某一个 Issue 而留下自相矛盾的长期规范。
