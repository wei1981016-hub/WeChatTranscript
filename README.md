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

## 路线图

- 增加录制状态和音量电平
- 增加自动停止阈值设置
- 打包成可直接下载的 `.dmg`
- 稳定签名，减少 macOS TCC 权限反复授权问题

## 免责声明

请只录制你有权处理的内容，并遵守所在地法律法规、平台条款和内容版权要求。本项目不提供绕过微信权限、下载限制或加密保护的能力。

## License

MIT
