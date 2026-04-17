# Recording Detector

一个用于检测屏幕录制行为的 macOS 测试工具，配合 [Himi Recorder](../README.md) 使用，验证其隐身录屏能力。

<p align="center">
  <img src="../imgs/QQ20260417-104040.png" width="400" alt="未检测到录屏" />
  <img src="../imgs/QQ20260417-104135.png" width="400" alt="检测到录屏" />
</p>

## 检测原理

| 方法 | 原理 | 误报风险 |
|------|------|----------|
| **Video File Write** | `proc_pidfdinfo` 遍历所有进程的文件描述符，检查是否有进程**正在写入 .mp4/.mov 等视频文件**，并验证 `FWRITE` 标志 | 极低 |
| **System Helpers** | 检测 `screencaptureui` 等系统录屏辅助进程（仅在录屏时才会出现） | 零 |

核心检测方法（Video File Write）不依赖进程名单或窗口分析，而是直接检查进程是否在**写视频文件** —— 这是实锤，不会误报。

## 使用方法

### 构建

```bash
cd DetectorTestApp
./build.sh
```

### 运行

```bash
open DetectorTestApp.app
```

### 验证 Himi Recorder 隐身能力

1. 打开 Recording Detector
2. 使用 QQ 或其他普通录屏软件录屏 → 应能检测到
3. 使用 Himi Recorder 录屏 → 如果隐身能力正常，则检测不到

## 系统要求

- **macOS 14.0 (Sonoma)** 或更高版本
