#!/bin/bash
# WeChatTranscript 转写主脚本(App Support 版,避开 ~/Documents 的 TCC 保护)
# 模型与输出都在 ~/Library/Application Support/WeChatTranscript 下。
# 用法:
#   transcribe.sh                      # medium,转写 ~/Documents/WeChatTranscript 里最新一段
#   transcribe.sh 某文件.m4a            # 转写指定文件
#   transcribe.sh -m large 某文件.m4a   # large-v3 模型
set -euo pipefail

APPSUP="$HOME/Library/Application Support/WeChatTranscript"
MODELS="$APPSUP/models"
OUT="$APPSUP/transcripts"
BIN="$APPSUP/bin"
REC="$HOME/Documents/WeChatTranscript"
mkdir -p "$OUT"

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

if [[ $# -ge 1 ]]; then
  AUDIO="$1"
else
  AUDIO="$(ls -t "$REC"/*.m4a 2>/dev/null | head -1 || true)"
fi
if [[ -z "${AUDIO:-}" || ! -f "$AUDIO" ]]; then
  echo "找不到要转写的 .m4a。"
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

echo "▶ 漏段补转..."
python3 "$BIN/recover_gaps.py" "$OUT/$STEM.json" "$AUDIO" "$MODEL" "$MODELS"

echo "▶ 清洗成纯文本..."
python3 "$BIN/postprocess.py" "$OUT/$STEM.json"

echo "✔ 完成。文稿目录: $OUT"
