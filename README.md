# WeChatTranscript

WeChatTranscript 是一个 macOS 小工具：在电脑微信播放视频时捕获系统音频，并保存为 `.m4a` 录音文件。

它不读取微信缓存、不解析微信数据、不破解视频下载。核心思路是用户主动播放视频，App 通过 macOS 的系统音频捕获能力录制声音。转写、摘要和文稿整理请使用你自己的大模型或语音识别工具处理录音文件。

## 功能

- 录制 Mac 系统音频
- 视频结束后根据持续静音自动停止录制并保存
- 同时支持手动停止并保存
- 输出 `.m4a` 录音文件
- 支持电脑微信视频、视频号、公众号视频等“无法直接下载”的场景

## 系统要求

- macOS 14 或更新版本
- Apple Silicon Mac
- 已安装 Xcode Command Line Tools

## 构建

```sh
make
open dist/WeChatTranscript.app
```

## 使用

1. 打开 `dist/WeChatTranscript.app`
2. 点击 `开始录制`
3. 在电脑微信里播放视频
4. 播放结束后等待自动保存，或手动点击 `停止并保存`
5. 到输出目录查看 `.m4a` 文件

录制文件会保存到：

```text
~/Documents/WeChatTranscript/
```

## 权限

首次录制时 macOS 会请求以下权限：

- 屏幕与系统音频录制：用于捕获系统音频

如果授权后仍提示拒绝，可以重置权限后重新打开 App：

```sh
tccutil reset ScreenCapture local.codex.WeChatTranscript
open -n dist/WeChatTranscript.app
```

## 当前 MVP 限制

- 依赖 macOS 的 ScreenCaptureKit 捕获系统音频，适合电脑微信。
- 自动停止基于音频静音检测：录制满约 20 秒后，连续约 12 秒静音会自动停止并保存；如果视频中有很长静音段，可能提前停止。
- 当前版本不做语音识别、不生成 `.txt` 或 `.md`。

## 隐私边界

- App 不读取微信聊天记录、缓存、数据库或视频文件。
- App 只保存用户主动录制的系统音频到本机 `~/Documents/WeChatTranscript/`。
- App 不上传录音、不调用 Apple Speech、不调用任何大模型服务。

## 转写（可选配套工具）

App 本身只负责录音。`Transcribe/` 目录提供一套**完全本地**的转写流水线，把录好的 `.m4a` 转成带标点的简体中文文稿，全程不上传。

### 安装

```sh
./Transcribe/install.sh
```

安装器会自动：

1. 用 Homebrew 安装依赖 `whisperkit-cli` / `ffmpeg` / `opencc`
2. 把转写脚本部署到 `~/Documents/WeChatTranscript/`
3. 安装 Finder 右键「转写」快速操作

首次模型会自动下载（medium 约 1.5GB；可选 large-v3 约 3GB）。

### 用法

两种方式，任选其一：

- **右键（推荐）**：在 Finder 选中 `.m4a` → 右键 →（快速操作）→ **转写**。
  首次会弹「运行 / 通知权限」各一次，点允许即可。若菜单里没有，去
  `系统设置 → 键盘 → 键盘快捷键 → 服务 → 文件与文件夹` 勾上「转写」。
- **命令行**：

  ```sh
  cd ~/Documents/WeChatTranscript
  ./transcribe.sh                    # medium 模型，转写最新一段录音
  ./transcribe.sh 某文件.m4a          # 指定文件
  ./transcribe.sh -m large 某文件.m4a # large-v3 模型（更准更慢）
  ```

产物在 `~/Documents/WeChatTranscript/transcripts/`：`.txt`（纯文本阅读稿）、`.md`、`.srt`（带时间轴）。

### 流水线做了什么

1. **转写**：WhisperKit（Apple Silicon 本地推理）+ VAD 分块。
2. **漏段补转**（`recover_gaps.py`）：WhisperKit 的 VAD 偶尔会把一整块语音解码成空段（导致“丢字”）。本步检测这类空白段，确认确有声音后用 `ffmpeg` 切出该段、单独重转、拼回原文。
3. **清洗**（`postprocess.py`）：去除特殊标记、去除分块重叠的重复句、过滤字幕组水印幻觉、繁体转简体、按句分段；若仍有补不回的空白段会打印告警，绝不“悄悄漏话”。

### 已知局限

- 自动停止/录音里若混入了后续其它视频的声音，会一并转写，需手动删除。
- medium 在语速快、术语密、夹人名的内容上仍会有个别同音/专名错（如“陆家嘴”可能误成“楼下嘴”）。换 `-m large` 可减少；要彻底纠正建议再接一层 LLM 后处理。

### 隐私

转写全程在本机完成：WhisperKit 本地推理、`opencc` 本地转换，不联网、不上传任何音频或文本。

## 路线图

- 增加录制状态和音量电平
- 增加自动停止阈值设置
- 打包成可直接下载的 `.dmg`
- 稳定签名，减少 macOS TCC 权限反复授权问题

## 免责声明

请只录制你有权处理的内容，并遵守所在地法律法规、平台条款和内容版权要求。本项目不提供绕过微信权限、下载限制或加密保护的能力。

## License

MIT
