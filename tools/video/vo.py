#!/usr/bin/env python3
"""Synthesize a scratch VO track from an ASS caption file and mux it onto the video.

Captions overlap on purpose (narrator and Milhouse commenting on the same frame);
speech can't. Lines are laid out in cue order and pushed later when the previous
line is still talking, so nothing collides.
"""
import json, re, subprocess, sys, wave
from pathlib import Path

HERE = Path(__file__).parent
PIPER = HERE / "tts-venv/bin/piper"
ESPEAK = HERE / "espeak.sh"
VOICES = HERE / "voices"
GAP = 0.30  # silence between consecutive lines

def dur(p):
    with wave.open(str(p)) as w:
        return w.getnframes() / w.getframerate()

def piper(text, voice, out, length_scale=1.0):
    cfg = json.dumps({"length_scale": length_scale})
    subprocess.run([str(PIPER), "-m", str(VOICES / f"{voice}.onnx"), "-f", str(out),
                    "--data-dir", str(VOICES), "--config", str(VOICES / f"{voice}.onnx.json")],
                   input=text, text=True, check=True, capture_output=True)
    return dur(out)

def espeak(text, out, speed=150, pitch=20, voice="en-us"):
    subprocess.run([str(ESPEAK), "-v", voice, "-s", str(speed), "-p", str(pitch),
                    "-w", str(out), text], check=True, capture_output=True)
    return dur(out)

def parse_ass(path):
    cues = []
    for line in Path(path).read_text().splitlines():
        if not line.startswith("Dialogue:"):
            continue
        body = line.split(":", 1)[1]
        f = body.split(",", 9)
        t = f[1].strip()
        h, m, s = t.split(":")
        start = int(h) * 3600 + int(m) * 60 + float(s)
        style = f[3].strip()
        text = re.sub(r"\{[^}]*\}", "", f[9]).replace(r"\N", " ").strip()
        cues.append({"start": start, "style": style, "text": text})
    return sorted(cues, key=lambda c: c["start"])

def main():
    ass, video, out_video = sys.argv[1], sys.argv[2], sys.argv[3]
    narr_voice = sys.argv[4] if len(sys.argv) > 4 else "en_US-ryan-high"
    milh_voice = sys.argv[5] if len(sys.argv) > 5 else "en_US-danny-low"

    work = HERE / "vo_parts"
    work.mkdir(exist_ok=True)
    for f in work.glob("*.wav"):
        f.unlink()

    cues = parse_ass(ass)
    cursor = 0.0
    placed = []
    for i, c in enumerate(cues):
        wav = work / f"{i:02d}.wav"
        if c["style"] == "Narr":
            d = piper(c["text"], narr_voice, wav, length_scale=1.0)
        else:
            # a touch slower and higher-strung for the in-character line
            d = piper(c["text"], milh_voice, wav, length_scale=1.05)
        at = max(c["start"], cursor)
        cursor = at + d + GAP
        placed.append({"at": at, "dur": d, "wav": wav, **c})

    for p in placed:
        drift = p["at"] - p["start"]
        print(f'{p["at"]:6.2f}s  {p["style"]:5s} {p["dur"]:4.1f}s'
              f'{"  (+%.1fs late)" % drift if drift > 0.05 else ""}  {p["text"][:52]}')

    # one delayed stream per line, all summed
    inputs, filters, labels = [], [], []
    for i, p in enumerate(placed):
        inputs += ["-i", str(p["wav"])]
        filters.append(f'[{i}:a]adelay={int(p["at"]*1000)}|{int(p["at"]*1000)},'
                       f'aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo[a{i}]')
        labels.append(f"[a{i}]")
    mix = "".join(labels) + f"amix=inputs={len(placed)}:normalize=0,alimiter=limit=0.9[out]"
    track = work / "vo.wav"
    subprocess.run(["ffmpeg", "-y", "-v", "error", *inputs, "-filter_complex",
                    ";".join(filters) + ";" + mix, "-map", "[out]", str(track)], check=True)

    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", video, "-i", str(track),
                    "-c:v", "copy", "-c:a", "aac", "-b:a", "160k",
                    "-map", "0:v:0", "-map", "1:a:0",
                    "-af", "apad", "-shortest", out_video], check=True)
    print("\n->", out_video)

main()
