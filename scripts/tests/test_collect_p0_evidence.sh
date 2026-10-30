#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root/scripts/collect-p0-evidence.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/artifact" "$work/bin"
printf 'synthetic app bundle archive\n' > "$work/artifact/PicPaste-macOS27-arm64-unsigned.zip"
printf '%s\n' '1234567890abcdef1234567890abcdef12345678' > "$work/artifact/SOURCE_SHA.txt"
printf '%s\n' '1234567890abcdef1234567890abcdef12345678' > "$work/artifact/CHECKOUT_SHA.txt"
(cd "$work/artifact" && shasum -a 256 PicPaste-macOS27-arm64-unsigned.zip > SHA256SUMS)
cat > "$work/bin/sw_vers" <<'MOCK'
#!/bin/sh
case "$1" in
  -productVersion) echo 27.0.1 ;;
  -buildVersion) echo 26A434 ;;
  *) exit 1 ;;
esac
MOCK
cat > "$work/bin/sysctl" <<'MOCK'
#!/bin/sh
case "$2" in
  hw.model) echo Mac15,9 ;;
  machdep.cpu.brand_string) echo 'Apple M3 Pro' ;;
  kern.hv_vmm_present) echo 0 ;;
  *) exit 1 ;;
esac
MOCK
cat > "$work/bin/system_profiler" <<'MOCK'
#!/bin/sh
cat <<'TEXT'
Displays:
    Internal Display:
      Resolution: 3024 x 1964 Retina
      Main Display: Yes
      Display Serial Number: SECRET-SERIAL-DO-NOT-LEAK
    External Display:
      Resolution: 1920 x 1080
      Online: Yes
TEXT
MOCK
chmod +x "$work/bin/"*
PATH="$work/bin:$PATH" bash "$script" "$work/artifact" > "$work/report.md"
grep -Fq '1234567890abcdef1234567890abcdef12345678' "$work/report.md"
grep -Fq '27.0.1 (26A434)' "$work/report.md"
grep -Fq 'Apple M3 Pro' "$work/report.md"
grep -Fq 'SHA256: PASS' "$work/report.md"
grep -Fq 'Resolution: 3024 x 1964 Retina' "$work/report.md"
grep -Fq '尚未真机验证' "$work/report.md"
if grep -q 'SECRET-SERIAL-DO-NOT-LEAK' "$work/report.md"; then echo 'Privacy leak' >&2; exit 1; fi
if grep -q 'DEVICE_VERIFIED=YES' "$work/report.md"; then echo 'False verification state' >&2; exit 1; fi
printf 'corrupted archive\n' >> "$work/artifact/PicPaste-macOS27-arm64-unsigned.zip"
if PATH="$work/bin:$PATH" bash "$script" "$work/artifact" > "$work/invalid.md" 2> "$work/error.txt"; then
  echo 'Checksum mismatch incorrectly accepted' >&2; exit 1
fi
grep -Fq 'SHA256' "$work/error.txt"
rm -f "$work/artifact/SOURCE_SHA.txt"
if PATH="$work/bin:$PATH" bash "$script" "$work/artifact" > "$work/missing.md" 2> "$work/error.txt"; then
  echo 'Missing SOURCE_SHA incorrectly accepted' >&2; exit 1
fi
grep -Fq 'SOURCE_SHA.txt' "$work/error.txt"
echo 'P0 acceptance evidence tests passed'
