# PicPaste 品牌与图标资源

![PicPaste SVG Logo](../assets/logo/picpaste.svg)

## 原始标识

- **可编辑矢量源**：[assets/logo/picpaste.svg](../assets/logo/picpaste.svg)，1024 × 1024 viewBox，纯 SVG 路径/形状/渐变；不是把 PNG 包装进 SVG。
- 含义：四角取景框代表截图选区，叠放照片代表复制/粘贴，图钉代表置顶贴图。
- 风格：克制暖米色背景、橙色重点、蓝灰色图像；无文字。遵循当前已选定图标，不随意换成别的方案。
- 图片资源许可：本项目原创 AI 协作设计图标；后续如引入第三方资源，需检查许可并在文档注明出处。

## 资源与生成规则

- SVG 是本仓库的**唯一图标设计源**；修改视觉形状先改 SVG，review 过后再派生其他格式。
- Finder / Dock 所需的 AppIcon PNG / ICNS 应由构建或发布流程从 SVG 生成，并验证在小尺寸（16/32/64 px）与 512/1024 px 下的辨识度。
- 生成的 PNG/ICNS 属于构建产物，除非 Xcode Asset Catalog 需要且 PR 明确说明，否则不提交多份重复源文件。
- GUI 和截图 PNG 的实际颜色与 Alpha 不应被 Logo 的色彩或玻璃效果处理影响。
- 图标变化要同步维护本文件、README 展示和相关资源。正式应用图标接入在 P0-01 Issue 完成。
