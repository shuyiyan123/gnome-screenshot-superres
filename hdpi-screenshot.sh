#!/usr/bin/env bash
set -euo pipefail

# 一键高精度截图辅助脚本：
# 1. 读取当前显示器缩放
# 2. 临时切到 200%（整数缩放，画面更锐）
# 3. 等你用 Print 截图
# 4. 按回车后自动恢复原来的缩放

GDCTL="${GDCTL:-/usr/bin/gdctl}"
MONITOR="${MONITOR:-eDP-2}"
HIGH_SCALE="${HIGH_SCALE:-2.0}"

if ! command -v "$GDCTL" >/dev/null 2>&1; then
    echo "未找到 gdctl，请确认已安装 GNOME Display Control 工具。" >&2
    exit 1
fi

# 从 gdctl show 里自动读取当前 Scale，例如 1.3333333730697632
ORIGINAL_SCALE="$("$GDCTL" show | sed -n 's/^.*Scale: //p' | head -n 1)"

if [[ -z "$ORIGINAL_SCALE" ]]; then
    echo "无法读取当前缩放比例，请先运行：$GDCTL show" >&2
    exit 1
fi

echo "当前缩放：$ORIGINAL_SCALE"
echo "即将临时切换到：$HIGH_SCALE"

restore_scale() {
    echo
    echo "正在恢复原缩放：$ORIGINAL_SCALE"
    "$GDCTL" set --logical-monitor --primary --monitor "$MONITOR" --scale "$ORIGINAL_SCALE"
}

# 无论脚本怎样退出，都尽量恢复原缩放
trap restore_scale EXIT INT TERM

"$GDCTL" set --logical-monitor --primary --monitor "$MONITOR" --scale "$HIGH_SCALE"

echo
echo "现在按 Shift+Print 直接进入局部截图，选择你要的区域并保存。"
read -r -p "区域截图保存完成后，按回车恢复原缩放并退出..." _
