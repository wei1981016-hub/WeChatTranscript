#!/bin/bash
# 一键安装 WeChatTranscript 的转写配套工具(App Support 架构)。
#   1) 安装依赖 (whisperkit-cli / ffmpeg / opencc)
#   2) 部署脚本/纠错词典到 ~/Library/Application Support/WeChatTranscript
#   3) 安装 Finder 右键「转写」快速操作
#
# 为什么放 App Support 而不是 ~/Documents:
#   Finder 快速操作由系统 XPC 服务 WorkflowServiceRunner 运行,它无法访问受 TCC
#   保护的「文稿」目录(会报 Operation not permitted)。把脚本和模型放在非保护的
#   App Support 下即可避开;右键时只读取你选中的那个文件(Finder 会单独授权)。
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
APPSUP="$HOME/Library/Application Support/WeChatTranscript"
SERVICES="$HOME/Library/Services"
REC="$HOME/Documents/WeChatTranscript"

echo "▶ 1/3 检查依赖..."
if ! command -v brew >/dev/null; then
  echo "  未检测到 Homebrew,请先安装:https://brew.sh"; exit 1
fi
for pkg in whisperkit-cli ffmpeg opencc; do
  if brew list --formula "$pkg" >/dev/null 2>&1; then
    echo "  ✔ $pkg 已安装"
  else
    echo "  ↓ 安装 $pkg ..."; brew install "$pkg"
  fi
done

echo "▶ 2/3 部署脚本与纠错词典到 $APPSUP ..."
mkdir -p "$APPSUP/bin" "$APPSUP/models" "$APPSUP/transcripts" "$APPSUP/work"
cp "$SRC/bin/transcribe.sh" "$SRC/bin/postprocess.py" "$SRC/bin/recover_gaps.py" "$APPSUP/bin/"
chmod +x "$APPSUP/bin/transcribe.sh"
# 纠错词典:已存在则不覆盖,保护你自己加的词
if [ -f "$APPSUP/corrections.txt" ]; then
  echo "  · corrections.txt 已存在,保留你的自定义词典"
else
  cp "$SRC/corrections.txt" "$APPSUP/corrections.txt"
  echo "  ✔ 已放置示例纠错词典 corrections.txt"
fi
# 命令行便捷转发器(可选):~/Documents/WeChatTranscript/transcribe.sh
mkdir -p "$REC"
cat > "$REC/transcribe.sh" <<EOF
#!/bin/bash
exec "\$HOME/Library/Application Support/WeChatTranscript/bin/transcribe.sh" "\$@"
EOF
chmod +x "$REC/transcribe.sh"
echo "  ✔ 脚本就位"

echo "▶ 3/3 安装 Finder 右键「转写」快速操作..."
rm -rf "$SERVICES/WeChatTranscribe.workflow"
mkdir -p "$SERVICES"
cp -R "$SRC/WeChatTranscribe.workflow" "$SERVICES/"
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true
killall Finder 2>/dev/null || true
echo "  ✔ 快速操作已安装并刷新"

echo ""
echo "✅ 完成!用法:"
echo "   · 右键:  Finder 选中 .m4a → 右键 →(快速操作)→ 转写"
echo "   · 命令:  ~/Documents/WeChatTranscript/transcribe.sh [-m large] [文件.m4a]"
echo ""
echo "文稿输出在:$APPSUP/transcripts/(转写完成后会自动打开)"
echo "纠错词典在:$APPSUP/corrections.txt(看到反复出错的词就加一行 错误=正确)"
echo "首次右键时 macOS 会弹权限框,点允许即可。"
