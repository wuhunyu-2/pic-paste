#!/usr/bin/env bash
# Local-only evidence helper. It never uploads data or claims device acceptance.
set -euo pipefail

usage() {
  echo "Usage: bash scripts/collect-p0-evidence.sh /path/to/extracted-GitHub-Actions-artifact" >&2
  exit 2
}
[[ $# -eq 1 ]] || usage
artifact_dir="$1"
[[ -d "$artifact_dir" ]] || { echo "Artifact directory not found: $artifact_dir" >&2; exit 2; }

for name in SOURCE_SHA.txt CHECKOUT_SHA.txt SHA256SUMS PicPaste-macOS27-arm64-unsigned.zip; do
  [[ -f "$artifact_dir/$name" ]] || { echo "Missing required artifact file: $name" >&2; exit 2; }
done
source_sha="$(tr -d '\r\n' < "$artifact_dir/SOURCE_SHA.txt")"
checkout_sha="$(tr -d '\r\n' < "$artifact_dir/CHECKOUT_SHA.txt")"
for sha in "$source_sha" "$checkout_sha"; do
  [[ "$sha" =~ ^[0-9a-fA-F]{40}$ ]] || { echo 'Invalid SOURCE_SHA.txt or CHECKOUT_SHA.txt value' >&2; exit 2; }
done

# Check only our expected App zip; never accept a checksum manifest naming unrelated paths.
expected_sha="$(awk '$2 == "PicPaste-macOS27-arm64-unsigned.zip" { print $1 }' "$artifact_dir/SHA256SUMS")"
[[ "$expected_sha" =~ ^[0-9a-fA-F]{64}$ ]] || { echo 'Invalid or missing SHA256 checksum for app archive' >&2; exit 2; }
actual_sha="$(shasum -a 256 "$artifact_dir/PicPaste-macOS27-arm64-unsigned.zip" | awk '{print $1}')"
[[ "$expected_sha" == "$actual_sha" ]] || { echo 'SHA256 mismatch: PicPaste-macOS27-arm64-unsigned.zip' >&2; exit 1; }

value_or_unknown() { "$@" 2>/dev/null || printf 'unknown\n'; }
os_version="$(value_or_unknown sw_vers -productVersion)"
os_build="$(value_or_unknown sw_vers -buildVersion)"
architecture="$(value_or_unknown uname -m)"
mac_model="$(value_or_unknown sysctl -n hw.model)"
processor="$(value_or_unknown sysctl -n machdep.cpu.brand_string)"
vm_flag="$(value_or_unknown sysctl -n kern.hv_vmm_present)"
if [[ "$vm_flag" == 1 ]]; then
  vm_description='检测到虚拟化环境：不可用于 DEVICE_VERIFIED'
else
  vm_description='未检测到虚拟化标志；仍须实际人工操作证明是真机'
fi
# Whitelist display attributes; do NOT include display serial numbers, UUIDs, or raw system_profiler data.
displays="$(system_profiler SPDisplaysDataType 2>/dev/null | grep -E '^[[:space:]]*(Resolution:|UI Looks like:|Main Display:|Online:|Retina:|Display Type:)' | sed 's/^[[:space:]]*//' || true)"
[[ -n "$displays" ]] || displays='未获取到显示器信息；请人工填写显示器布局和缩放'
cat <<REPORT
# PicPaste P0-07 真机验收记录（待填写）

> 当前状态：**尚未真机验证**。本脚本仅校验构建包并采集基础环境信息；不会触发截图权限、操作菜单或验证桌面行为。全部场景必须在真实设备上人工验证。

## 构建来源与完整性

- SOURCE_SHA: \`$source_sha\`
- CHECKOUT_SHA: \`$checkout_sha\`
- PicPaste-macOS27-arm64-unsigned.zip SHA256: \`$actual_sha\`
- SHA256: PASS（所选开发 App ZIP 与产物内 SHA256SUMS 一致）

## 当前设备环境

- macOS: $os_version ($os_build)
- 设备型号: $mac_model
- 芯片: $processor
- 架构: $architecture
- 虚拟化检查: $vm_description
- 显示器摘要（已过滤序列号）：
REPORT
while IFS= read -r line; do printf '  - %s\n' "$line"; done <<< "$displays"
cat <<'REPORT'
- 显示器排列/缩放/外接屏型号（人工记录）：未填写

## 真机操作记录（全部初始状态为未执行）

| 场景 | 结果 PASS / FAIL / BLOCKED | 实际步骤、现象与截图/录屏链接 |
| --- | --- | --- |
| 菜单栏与全局快捷键启动 | 未执行 | |
| TCC 首次拒绝、允许、撤销并恢复 | 未执行 | |
| 拖选、移动、八手柄、Enter、Esc、重复截图 | 未执行 | |
| 失败/取消后的焦点恢复与窗口清理 | 未执行 | |
| Retina / 1x / 2x / 负坐标外接屏 / 断连 | 未执行 | |
| Spaces、全屏应用、Stage Manager（如有） | 未执行 | |
| Preview / Notes 粘贴和透明圆角像素 | 未执行 | |
| PNG 保存、像素尺寸、文件名、同名防覆盖 | 未执行 | |
| 连续至少 30 次截图、取消、再捕获 | 未执行 | |

## 汇总

- 实测操作员及时间：未填写
- 失败及关联 Bug Issue：未填写
- 未执行或无设备导致 BLOCKED 的项目：未填写
- 最终状态：**待人工核验，禁止将本报告直接标注 DEVICE_VERIFIED**

请将填写后的结果及必要的截图/录屏附到 GitHub Issue #7。缺少外接屏或 macOS 27 实机的场景保持 BLOCKED，不能据此关闭 P0 门槛。
REPORT
