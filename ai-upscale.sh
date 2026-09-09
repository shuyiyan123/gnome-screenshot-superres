#!/usr/bin/env bash
set -euo pipefail

# 使用 Real-ESRGAN 对截图做 GPU 超分。
# 用法：
#   ./ai-upscale.sh                     # 自动处理 ~/Pictures/截图 里最新一张 png
#   ./ai-upscale.sh 图片.png            # 处理指定图片
#   ./ai-upscale.sh /path/to/dir        # 批量处理目录里的 png

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/realesrgan-ncnn-vulkan/realesrgan-ncnn-vulkan"
MODELS="$SCRIPT_DIR/realesrgan-ncnn-vulkan/models"
MODEL="${MODEL:-realesrgan-x4plus}"
SCALE="${SCALE:-4}"

if [[ ! -x "$BIN" ]]; then
    echo "未找到 Real-ESRGAN 可执行文件：$BIN" >&2
    echo "请先确认已下载 realesrgan-ncnn-vulkan。" >&2
    exit 1
fi

if [[ "$#" -eq 0 ]]; then
    input="$(ls -t "$HOME"/Pictures/截图/*.png 2>/dev/null | head -n 1 || true)"
    if [[ -z "$input" ]]; then
        echo "没有找到截图文件。" >&2
        exit 1
    fi
    set -- "$input"
fi

process_file() {
    local src="$1"
    local base ext out
    base="${src%.*}"
    ext="${src##*.}"
    out="${base}_${MODEL}_x${SCALE}.png"
    echo "处理：$src"
    "$BIN" -i "$src" -o "$out" -m "$MODELS" -n "$MODEL" -s "$SCALE" -f png -v
    echo "输出：$out"
}

for target in "$@"; do
    if [[ -d "$target" ]]; then
        while IFS= read -r file; do
            process_file "$file"
        done < <(find "$target" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | sort)
    elif [[ -f "$target" ]]; then
        process_file "$target"
    else
        echo "跳过不存在的路径：$target" >&2
    fi
done
