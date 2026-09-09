# GNOME 截图模糊问题排查与自动增强方案

## 问题

在 GNOME Wayland 环境下截图，局部截图经常发糊，观感上文字和界面边缘不够清晰。

## 环境

- 系统：Fedora 44
- 桌面：GNOME Shell 50.4，Wayland
- 内置屏幕：2560x1440 @ 165Hz
- 显示缩放：约 1.333（界面中表现为 125% 分数缩放）
- GPU：
  - NVIDIA GeForce RTX 3060 Laptop GPU
  - AMD Radeon 680M

## 排查结论

截图模糊的主要原因不是“没有调用显卡”，而是：

1. GNOME 在 125% 分数缩放下使用非整数像素映射，合成画面本身就会产生轻微模糊。
2. GNOME 截图工具抓取的是合成后的画面，因此截图也会继承这些模糊。
3. NVIDIA 独显在 Real-ESRGAN 的 ncnn/Vulkan 版本上会出现 `vkQueueSubmit failed -4`，导致处理变慢和桌面卡顿。

显卡实际上是在工作的。`nvidia-smi` 和 `glxinfo` 都能看到硬件渲染器，并不是软件渲染。

## 尝试过的方案

1. 全屏截图后再裁剪：只能绕过窗口/区域截图 bug，但原图本身仍受分数缩放影响。
2. 临时把缩放切到 200% 再截图：清晰度明显提高，但操作太麻烦。
3. 对截图做普通锐化和 2 倍 Lanczos 放大：有改善，但细节恢复有限。
4. Real-ESRGAN 4 倍超分：效果好，但慢，且 NVIDIA 下出现 Vulkan 队列错误。
5. 换 waifu2x-ncnn-vulkan：
   - 速度更快；
   - NVIDIA 下无 `vkQueueSubmit failed`；
   - 模型更轻，适合作为后台自动处理方案。

## 最终方案

使用后台服务自动监听 GNOME 截图目录：

```text
新截图生成
  -> 文件大小稳定后立即处理
  -> waifu2x models-cunet，2 倍超分
  -> AMD Radeon 680M 处理
  -> 增强图写入 ~/Pictures/截图/增强/
  -> 增强图复制到 Wayland 剪贴板
  -> 桌面通知
```

当前默认参数：

```text
模型：models-cunet
倍率：2x
GPU：AMD Radeon 680M
tile：128
线程：1:4:4
低 CPU/IO 优先级
```

实测单张约 0.86 秒，其中：

```text
AI 处理：约 0.77 秒
写剪贴板：约 0.06 秒
通知：约 0.03 秒
```

## 相关文件

- `screenshot-autoprocess.sh`：后台监听和处理脚本
- `screenshot-autoprocess.service`：systemd 用户服务
- `ai-upscale.sh`：手动批量超分脚本
- `hdpi-screenshot.sh`：临时切换到 200% 缩放的辅助脚本
- `realesrgan-ncnn-vulkan/`：Real-ESRGAN 便携版
- `waifu2x-ncnn-vulkan/`：waifu2x 便携版

## 安装和使用

### 1. 启动自动增强服务

```bash
systemctl --user enable --now screenshot-autoprocess.service
```

### 2. 正常截图

使用 GNOME 自带的局部截图，例如：

```text
Shift + Print
```

截图完成后，等待“AI 增强完成”通知，然后直接粘贴。

### 3. 手动处理旧截图

```bash
./ai-upscale.sh /home/machine/Pictures/截图
```

## 管理命令

```bash
systemctl --user status screenshot-autoprocess.service
systemctl --user restart screenshot-autoprocess.service
systemctl --user stop screenshot-autoprocess.service
systemctl --user disable screenshot-autoprocess.service
```

日志：

```bash
cat /tmp/screenshot-autoprocess.log
```

## 注意事项

- 增强服务依赖当前目录中的脚本和模型文件，不要移动或删除。
- 分数缩放导致的原图模糊无法通过后处理完全还原，只能改善观感。
- 如果追求最高质量，可切换 Real-ESRGAN 4 倍模型，但速度会明显变慢。
- 如果追求更低延迟，可换 waifu2x 的 anime 或 photo 模型，但文字细节会略差。
