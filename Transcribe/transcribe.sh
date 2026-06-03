#!/bin/bash
# WeChatTranscript 转写脚本 —— WhisperKit 转写 + 清洗成纯文本/Markdown
# 用法:
#   ./transcribe.sh                      # medium 模型,转写最新一段录音
#   ./transcribe.sh 某文件.m4a            # medium 模型,转写指定文件
#   ./transcribe.sh -m large 某文件.m4a   # large-v3 模型(更准更慢,首次下约 3GB)
set -euo pipefail

BASE="$HOME/Documents/WeChatTranscript"
MODELS="$BASE/models"
OUT="$BASE/transcripts"
mkdir -p "$OUT"

# --- 解析 -m 模型开关 ---
MODEL_KIND="medium"
while getopts "m:" opt; do
  case "$opt" in
    m) MODEL_KIND="$OPTARG" ;;
    *) echo "未知选项"; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

case "$MODEL_KIND" in
  medium) MODEL="medium" ;;
  large|large-v3) MODEL="large-v3" ;;
  *) echo "模型只支持 medium / large,收到: $MODEL_KIND"; exit 1 ;;
esac

# 选择音频:参数指定 > 目录里最新的 m4a
if [[ $# -ge 1 ]]; then
  AUDIO="$1"
else
  AUDIO="$(ls -t "$BASE"/*.m4a 2>/dev/null | head -1 || true)"
fi
if [[ -z "${AUDIO:-}" || ! -f "$AUDIO" ]]; then
  echo "找不到要转写的 .m4a,请先用 App 录一段,或把文件路径作为参数传入。"
  exit 1
fi

STEM="$(basename "${AUDIO%.*}")"
echo "▶ 转写: $AUDIO  (模型: $MODEL)"

whisperkit-cli transcribe \
  --audio-path "$AUDIO" \
  --model "$MODEL" \
  --download-model-path "$MODELS" \
  --language zh \
  --chunking-strategy vad \
  --skip-special-tokens \
  --prompt "以下是普通话内容的简体中文转写。" \
  --report \
  --report-path "$OUT"

echo "▶ 漏段补转(检测 VAD 丢块并单独重转)..."
python3 "$BASE/recover_gaps.py" "$OUT/$STEM.json" "$AUDIO" "$MODEL" "$MODELS"

echo "▶ 清洗成纯文本..."
python3 "$BASE/postprocess.py" "$OUT/$STEM.json"

echo "✔ 完成。文稿目录: $OUT"
echo "   - $STEM.txt   (纯文本阅读稿)"
echo "   - $STEM.md    (Markdown)"
echo "   - $STEM.srt   (带时间轴字幕)"
