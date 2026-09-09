# GNOME Screenshot Super-Resolution

解决 GNOME Wayland 分数缩放下截图模糊问题的排查记录和自动增强方案。

## 功能

- 自动监听 GNOME 截图目录 `~/Pictures/截图`
- 截图生成后立即处理
- 使用 waifu2x `models-cunet` 2 倍超分
- 增强图保存到 `~/Pictures/截图/增强/`
- 自动把增强图写入 Wayland 剪贴板
- 桌面通知处理完成

## 文件说明

| 文件 | 作用 |
| --- | --- |
| `GNOME截图模糊问题处理.md` | 完整问题排查和处理记录 |
| `screenshot-autoprocess.sh` | 自动监听、处理、写剪贴板的主脚本 |
| `screenshot-autoprocess.service` | systemd 用户服务 |
| `screenshot-autoprocess.desktop` | 旧版 autostart 配置，当前以 systemd 服务为准 |
| `ai-upscale.sh` | 手动批量超分脚本 |
| `hdpi-screenshot.sh` | 临时切换 200% 缩放截图的辅助脚本 |

## 依赖

需要准备以下工具和模型：

- `inotify-tools`
- `wl-clipboard`
- `waifu2x-ncnn-vulkan`

模型二进制文件体积较大，未提交到本仓库。请参考 `GNOME截图模糊问题处理.md` 中的说明放置到对应目录。

## 安装

```bash
systemctl --user enable --now screenshot-autoprocess.service
```

## 使用

正常使用 GNOME 局部截图：

```text
Shift + Print
```

等待“AI 增强完成”通知，然后直接粘贴。

## 系统日志

```bash
cat /tmp/screenshot-autoprocess.log
```
