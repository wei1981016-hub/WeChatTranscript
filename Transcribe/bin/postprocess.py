#!/usr/bin/env python3
"""把 WhisperKit 的 JSON 转写结果清洗成可读纯文本 / Markdown。

做四件事:
1. 去掉 <|...|> 这类特殊标记
2. 去掉 VAD 分块重叠造成的重复段
3. 过滤静音段幻觉(noSpeechProb 高且像片尾/字幕组水印)
4. 繁体转简体(opencc t2s),再按句切分成段落
用法: postprocess.py 某文件.json
输出: 同名 .txt 和 .md
"""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

TOKEN_RE = re.compile(r"<\|[^|]*\|>")
# 字幕组水印幻觉(Whisper 训练数据里混进的字幕水印,会在片尾/静音段脑补出来)。
# 只精准匹配水印词,避免误删真实人声。
WATERMARK_RE = re.compile(
    r"字幕.{0,4}(製作|制作|志願者|志愿者|by)"
    r"|(謝謝|谢谢).{0,3}(觀看|观看)"
    r"|(請|请).{0,4}(訂閱|订阅)"
    r"|新唐人|明鏡|法輪|點贊訂閱|点赞订阅"
)


CORRECTIONS_PATH = (
    Path.home() / "Library" / "Application Support" / "WeChatTranscript" / "corrections.txt"
)


def load_corrections():
    """读取纠错词典(每行 错误=正确,# 注释)。按错误词长度降序,先长后短避免子串冲突。"""
    pairs = []
    if CORRECTIONS_PATH.exists():
        for line in CORRECTIONS_PATH.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            wrong, right = line.split("=", 1)
            wrong, right = wrong.strip(), right.strip()
            if wrong:
                pairs.append((wrong, right))
    pairs.sort(key=lambda p: len(p[0]), reverse=True)
    return pairs


def apply_corrections(text: str, pairs) -> str:
    for wrong, right in pairs:
        text = text.replace(wrong, right)
    return text


def strip_tokens(text: str) -> str:
    return TOKEN_RE.sub("", text).strip()


def to_simplified(text: str) -> str:
    if not shutil.which("opencc"):
        return text
    try:
        out = subprocess.run(
            ["opencc", "-c", "t2s.json"],
            input=text, capture_output=True, text=True, check=True,
        )
        return out.stdout
    except Exception:
        return text


def dedup_overlap(segments, window=6):
    """丢弃与最近 window 段重叠 / 互相包含的重复段(VAD 分块边界会重复转写)。"""
    kept = []
    for s in segments:
        t = s["text"]
        if not t:
            continue
        dup = False
        for prev in kept[-window:]:
            p = prev["text"]
            if t == p or (len(t) >= 6 and t in p) or (len(p) >= 6 and p in t):
                if len(t) > len(p):  # 保留更长的那一句
                    prev["text"] = t
                dup = True
                break
        if not dup:
            kept.append(s)
    return kept


def looks_like_hallucination(s) -> bool:
    return bool(WATERMARK_RE.search(s["text"]))


def paragraphs_from_segments(segs, target=150):
    """按句末标点或累计长度切段;Whisper 偶尔不输出标点时退化为按长度切。"""
    paras, cur = [], ""
    for s in segs:
        cur += s["text"]
        if cur and (cur[-1] in "。！？!?" or len(cur) >= target):
            paras.append(cur)
            cur = ""
    if cur:
        paras.append(cur)
    return paras or [""]


def main():
    if len(sys.argv) < 2:
        print("用法: postprocess.py 某文件.json")
        sys.exit(1)
    path = Path(sys.argv[1])
    data = json.loads(path.read_text(encoding="utf-8"))
    raw = data.get("segments", [])

    # 空段告警:跨度 >8 秒却没有文字的段,通常意味着这段语音被漏转了(VAD 丢块)
    dropped = []
    for s in raw:
        span = s.get("end", 0) - s.get("start", 0)
        if span >= 8 and not strip_tokens(s.get("text", "")):
            dropped.append((round(s.get("start", 0), 1), round(s.get("end", 0), 1)))
    if dropped:
        print("⚠ 检测到可能漏转的空白段(秒):", dropped)
        print("  建议改用 medium 模型重转,或手动核对这些时间点。")

    segs = []
    for s in raw:
        s = {**s, "text": strip_tokens(s.get("text", ""))}
        if not s["text"] or looks_like_hallucination(s):
            continue
        segs.append(s)
    segs = dedup_overlap(segs)

    corrections = load_corrections()
    paras = paragraphs_from_segments(segs)
    paras = [apply_corrections(to_simplified(p).strip(), corrections) for p in paras]
    paras = [p for p in paras if p]
    full = "".join(paras)
    if corrections:
        print(f"  已应用纠错词典 {len(corrections)} 条")

    txt_path = path.with_suffix(".txt")
    md_path = path.with_suffix(".md")
    txt_path.write_text("\n\n".join(paras) + "\n", encoding="utf-8")

    title = (paras[0][:28] + ("…" if len(paras[0]) > 28 else "")) if paras else "转写稿"
    md = [f"# {title}", "", f"来源音频:{path.stem}.m4a", "", "## 阅读稿", ""]
    md += ["\n\n".join(paras)]
    md_path.write_text("\n".join(md) + "\n", encoding="utf-8")

    print(f"✔ 段落 {len(paras)} 段,字数 {len(full)}")
    print(f"  纯文本: {txt_path}")
    print(f"  Markdown: {md_path}")


if __name__ == "__main__":
    main()
