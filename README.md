# WeChatTranscript

WeChatTranscript 是一个 macOS 小工具：在电脑微信播放视频时捕获系统音频，停止后转写中文文字，并生成适合阅读的 Markdown 文稿。

它不读取微信缓存、不解析微信数据、不破解视频下载。核心思路是用户主动播放视频，App 通过 macOS 的系统音频捕获能力录制声音。

## 功能

- 录制 Mac 系统音频
- 优先使用 Apple Speech 本地识别转写中文语音
- 视频结束后根据持续静音自动停止录制并开始转写
- 输出原始转写 `.txt`
- 输出阅读稿 `.md`
- 同时保留录音 `.m4a`
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
4. 播放结束后等待自动转写，或手动点击 `停止并转写`
5. 到输出目录查看结果

录制文件会保存到：

```text
~/Documents/WeChatTranscript/
```

每次录制会生成：

- `.m4a`：系统音频
- `.txt`：原始转写
- `.md`：阅读稿

## 权限

首次录制时 macOS 会请求以下权限：

- 屏幕与系统音频录制：用于捕获系统音频
- 语音识别：用于调用 Apple Speech 转文字，支持时优先使用本地识别

如果授权后仍提示拒绝，可以重置权限后重新打开 App：

```sh
tccutil reset ScreenCapture local.codex.WeChatTranscript
tccutil reset SpeechRecognition local.codex.WeChatTranscript
open -n dist/WeChatTranscript.app
```

## 当前 MVP 限制

- 依赖 macOS 的 ScreenCaptureKit 捕获系统音频，适合电脑微信。
- 自动停止基于音频静音检测：录制满约 20 秒后，连续约 12 秒静音会自动停止并转写；如果视频中有很长静音段，可能提前停止。
- 转写用 Apple Speech，支持时优先使用本地识别；准确率和长音频能力仍取决于系统服务，长视频建议分段录。
- 当前阅读稿整理是本地启发式处理，后续可接 Whisper 或 LLM 提升效果。

## 隐私边界

- App 不读取微信聊天记录、缓存、数据库或视频文件。
- App 只保存用户主动录制的系统音频到本机 `~/Documents/WeChatTranscript/`。
- 语音识别优先使用 Apple Speech 的本地识别能力；如果系统不支持对应语言/设备的本地识别，可能会回退到系统语音识别服务。

## 路线图

- 分段录制和长音频转写
- 接入 Whisper/faster-whisper
- 使用 LLM 自动整理成文章、摘要和时间线
- 增加录制状态、音量电平和转写进度
- 打包成可直接下载的 `.dmg`

## 免责声明

请只录制你有权处理的内容，并遵守所在地法律法规、平台条款和内容版权要求。本项目不提供绕过微信权限、下载限制或加密保护的能力。

## License

MIT
