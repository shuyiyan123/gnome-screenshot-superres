#!/usr/bin/env bash
set -euo pipefail

# 自动增强新截图，并把增强结果写入 Wayland 剪贴板。
# 监控目录默认是 ~/Pictures/截图，输出到该目录下的“增强”子目录。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/waifu2x-ncnn-vulkan/waifu2x-ncnn-vulkan-20250915-linux/waifu2x-ncnn-vulkan"
MODELS="$SCRIPT_DIR/waifu2x-ncnn-vulkan/waifu2x-ncnn-vulkan-20250915-linux/models-cunet"
NOISE="${NOISE:-0}"
SCALE="${SCALE:-2}"
GPU_ID="${GPU_ID:-1}"
THREADS="${THREADS:-1:4:4}"
TILE_SIZE="${TILE_SIZE:-128}"
DELAY_BEFORE_PROCESS="${DELAY_BEFORE_PROCESS:-0}"
OUT_TAG="${OUT_TAG:-waifu2x-cunet}"
WATCH_DIR="${WATCH_DIR:-$HOME/Pictures/截图}"
OUT_DIR="$WATCH_DIR/增强"
LOG_FILE="${LOG_FILE:-/tmp/screenshot-autoprocess.log}"

if ! command -v inotifywait >/dev/null 2>&1; then
    echo "缺少 inotifywait，请安装 inotify-tools。" >&2
    exit 1
fi

if ! command -v wl-copy >/dev/null 2>&1; then
    echo "缺少 wl-copy，请安装 wl-clipboard。" >&2
    exit 1
fi

if [[ ! -x "$BIN" ]]; then
    echo "未找到 waifu2x-ncnn-vulkan：$BIN" >&2
    exit 1
fi

mkdir -p "$WATCH_DIR" "$OUT_DIR"

process_file() {
    local src="$1"
    local base out

    [[ -f "$src" ]] || return
    case "${src,,}" in
        *.png|*.jpg|*.jpeg|*.webp) ;;
        *) return ;;
    esac

    base="$(basename "$src")"
    base="${base%.*}"

    # 已经是增强结果则跳过，避免循环处理
    [[ "$base" == *_waifu2x_* ]] && return

    out="$OUT_DIR/${base}_${OUT_TAG}_x${SCALE}.png"
    [[ -f "$out" ]] && return
    echo "$(date '+%F %T') 处理：$src" >> "$LOG_FILE"
    sleep "$DELAY_BEFORE_PROCESS"

    if nice -n 15 ionice -c 3 -n 7 "$BIN" -i "$src" -o "$out" -m "$MODELS" -n "$NOISE" -s "$SCALE" -f png -g "$GPU_ID" -j "$THREADS" -t "$TILE_SIZE" -v >> "$LOG_FILE" 2>&1; then
        if [[ -f "$out" ]]; then
            wl-copy --type image/png < "$out"
            notify-send -i "$out" "AI 增强完成" "剪贴板已更新为高清版：$out"
            echo "$(date '+%F %T') 完成：$out" >> "$LOG_FILE"
        fi
    else
        echo "$(date '+%F %T') 失败：$src" >> "$LOG_FILE"
    fi
}

wait_file_ready() {
    local file="$1"
    local last_size=-1 current_size
    local i

    for i in {1..20}; do
        [[ -f "$file" ]] || return 1
        current_size="$(stat -c%s "$file" 2>/dev/null || echo 0)"
        if [[ "$current_size" -gt 0 && "$current_size" == "$last_size" ]]; then
            return 0
        fi
        last_size="$current_size"
        sleep 0.1
    done
    return 1
}

echo "$(date '+%F %T') 启动监控：$WATCH_DIR" >> "$LOG_FILE"

inotifywait -m -e create -e close_write -e moved_to --format '%e|%w%f' "$WATCH_DIR" 2>> "$LOG_FILE" |
while IFS='|' read -r event file; do
    case "$event" in
        CREATE|MOVED_TO)
            wait_file_ready "$file" && process_file "$file"
            ;;
        CLOSE_WRITE)
            process_file "$file"
            ;;
    esac
done
