#!/usr/bin/env python3
"""漏段补转:VAD 偶尔会把某一整块语音解码成空段(你遇到的"丢字"根源)。
本脚本检测这些空白段,确认其确有声音(非静音)后,用 ffmpeg 切出该段、
再用 WhisperKit 的 none 模式单独转写,把结果回填进 JSON。
用法: recover_gaps.py <json> <audio.m4a> <model> <models_dir>
"""
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

TOKEN_RE = re.compile(r"<\|[^|]*\|>")
MIN_GAP = 8.0          # 只补 >=8 秒的空白段
SILENCE_MEAN_DB = -45  # mean_volume 低于此值视为真静音,跳过
PAD = 0.5              # 切片前后各留 0.5 秒余量


def strip_tokens(t: str) -> str:
    return TOKEN_RE.sub("", t or "").strip()


def mean_volume_db(audio: str, start: float, dur: float):
    out = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-ss", str(start), "-t", str(dur),
         "-i", audio, "-af", "volumedetect", "-f", "null", "-"],
        capture_output=True, text=True,
    ).stderr
    m = re.search(r"mean_volume:\s*(-?[\d.]+) dB", out)
    return float(m.group(1)) if m else None


def transcribe_clip(audio: str, start: float, dur: float, model: str, models_dir: str):
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "clip.wav"
        subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-ss", str(start),
             "-t", str(dur), "-i", audio, "-ar", "16000", "-ac", "1", str(wav)],
            check=True,
        )
        subprocess.run(
            ["whisperkit-cli", "transcribe", "--audio-path", str(wav),
             "--model", model, "--download-model-path", models_dir,
             "--language", "zh", "--chunking-strategy", "none",
             "--skip-special-tokens", "--prompt", "以下是普通话内容的简体中文转写。",
             "--report", "--report-path", tmp],
            capture_output=True, text=True,
        )
        js = Path(tmp) / "clip.json"
        if js.exists():
            return strip_tokens(json.loads(js.read_text(encoding="utf-8")).get("text", ""))
    return ""


def main():
    if len(sys.argv) < 5:
        print("用法: recover_gaps.py <json> <audio.m4a> <model> <models_dir>")
        sys.exit(1)
    json_path, audio, model, models_dir = sys.argv[1:5]
    data = json.loads(Path(json_path).read_text(encoding="utf-8"))
    segs = data.get("segments", [])

    recovered = 0
    for s in segs:
        span = s.get("end", 0) - s.get("start", 0)
        if span < MIN_GAP or strip_tokens(s.get("text", "")):
            continue
        start, end = s["start"], s["end"]
        dur = end - start
        mv = mean_volume_db(audio, start, dur)
        if mv is not None and mv < SILENCE_MEAN_DB:
            print(f"  跳过 {start:.1f}-{end:.1f}s(真静音 {mv:.1f}dB)")
            continue
        clip_start = max(0, start - PAD)
        text = transcribe_clip(audio, clip_start, dur + 2 * PAD, model, models_dir)
        if text:
            s["text"] = text
            recovered += 1
            print(f"  ✔ 补回 {start:.1f}-{end:.1f}s: {text[:40]}…")
        else:
            print(f"  ✗ {start:.1f}-{end:.1f}s 仍未转出(可能确无清晰人声)")

    if recovered:
        Path(json_path).write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    print(f"补转完成,共补回 {recovered} 段。")


if __name__ == "__main__":
    main()
