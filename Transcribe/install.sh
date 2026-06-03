#!/bin/bash
# 一键安装 WeChatTranscript 的转写配套工具:
#   1) 安装依赖 (whisperkit-cli / ffmpeg / opencc)
#   2) 部署转写脚本到 ~/Documents/WeChatTranscript/
#   3) 安装 Finder 右键「转写」快速操作
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/Documents/WeChatTranscript"
SERVICES="$HOME/Library/Services"

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

echo "▶ 2/3 部署转写脚本到 $DEST ..."
mkdir -p "$DEST"
cp "$SRC/transcribe.sh" "$SRC/postprocess.py" "$SRC/recover_gaps.py" "$DEST/"
chmod +x "$DEST/transcribe.sh"
echo "  ✔ transcribe.sh / postprocess.py / recover_gaps.py 已就位"

echo "▶ 3/3 安装 Finder 右键「转写」快速操作..."
mkdir -p "$SERVICES"
rm -rf "$SERVICES/WeChatTranscribe.workflow"
cp -R "$SRC/WeChatTranscribe.workflow" "$SERVICES/"
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true
killall Finder 2>/dev/null || true
echo "  ✔ 快速操作已安装并刷新"

echo ""
echo "✅ 完成!现在的用法:"
echo "   · 命令:  cd ~/Documents/WeChatTranscript && ./transcribe.sh"
echo "   · 右键:  Finder 选中 .m4a → 右键 →(快速操作)→ 转写"
echo ""
echo "首次右键转写时,macOS 会弹「运行权限 / 通知权限」各一次,点允许即可。"
echo "若右键没有「转写」:系统设置 → 键盘 → 键盘快捷键 → 服务 → 文件与文件夹,勾上「转写」。"
