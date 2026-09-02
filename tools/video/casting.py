#!/usr/bin/env python3
"""Build a voice-casting reel: each candidate voice reads a representative line
over a labelled card. I can generate these but not listen to them, so picking is
Yotam's call."""
import subprocess, wave
from pathlib import Path

HERE = Path(__file__).parent
PIPER = HERE / "tts-venv/bin/piper"
ESPEAK = HERE / "espeak.sh"
VOICES = HERE / "voices"
WORK = HERE / "casting"; WORK.mkdir(exist_ok=True)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

NARR = "Same data. Same point of view. Different threshold."
MILH = "Everything's coming up Milhouse!"
PHONE = "This phone is not a person. Nobody has vouched for it."

SAMPLES = [
    ("NARRATOR",   "ryan (high)",        "piper", "en_US-ryan-high",      NARR,  {}),
    ("NARRATOR",   "joe (medium)",       "piper", "en_US-joe-medium",     NARR,  {}),
    ("NARRATOR",   "hfc_male (medium)",  "piper", "en_US-hfc_male-medium",NARR,  {}),
    ("NARRATOR",   "lessac (medium)",    "piper", "en_US-lessac-medium",  NARR,  {}),
    ("MILHOUSE",   "danny (low)",        "piper", "en_US-danny-low",      MILH,  {}),
    ("MILHOUSE",   "lessac (medium)",    "piper", "en_US-lessac-medium",  MILH,  {}),
    ("DEMO PHONE", "espeak-ng default",  "espeak", None, PHONE, dict(speed=150, pitch=50)),
    ("DEMO PHONE", "espeak-ng low+slow", "espeak", None, PHONE, dict(speed=125, pitch=10)),
    ("DEMO PHONE", "espeak-ng fast+flat","espeak", None, PHONE, dict(speed=190, pitch=30, voice="en-us+croak")),
]

def dur(p):
    with wave.open(str(p)) as w: return w.getnframes() / w.getframerate()

def esc(s):
    return s.replace("\\", r"\\").replace(":", r"\:").replace("'", r"\'").replace(",", r"\,")

segs = []
for i, (role, label, engine, voice, text, opts) in enumerate(SAMPLES):
    wav = WORK / f"{i:02d}.wav"
    if engine == "piper":
        subprocess.run([str(PIPER), "-m", str(VOICES/f"{voice}.onnx"), "-f", str(wav),
                        "--data-dir", str(VOICES)], input=text, text=True, check=True, capture_output=True)
    else:
        subprocess.run([str(ESPEAK), "-v", opts.get("voice","en-us"), "-s", str(opts["speed"]),
                        "-p", str(opts["pitch"]), "-w", str(wav), text], check=True, capture_output=True)
    d = dur(wav) + 0.9
    seg = WORK / f"{i:02d}.mp4"
    draw = (f"drawtext=fontfile={FONT}:text='{esc(role)}':fontsize=64:fontcolor=0x8899aa:x=(w-tw)/2:y=620,"
            f"drawtext=fontfile={FONT}:text='{esc(label)}':fontsize=86:fontcolor=white:x=(w-tw)/2:y=740,"
            f"drawtext=fontfile={FONT}:text='{esc(text)}':fontsize=44:fontcolor=0xbbbbbb:x=(w-tw)/2:y=1040")
    subprocess.run(["ffmpeg","-y","-v","error","-f","lavfi","-i",f"color=c=0x101418:s=1080x1920:d={d:.2f}:r=25",
                    "-i",str(wav),"-vf",draw,"-c:v","libx264","-crf","22","-pix_fmt","yuv420p",
                    "-c:a","aac","-b:a","160k","-af",f"adelay=450|450,apad,atrim=0:{d:.2f}",
                    "-shortest",str(seg)], check=True)
    segs.append(seg)
    print(f"{role:11s} {label:22s} {dur(wav):4.1f}s")

lst = WORK/"list.txt"
lst.write_text("".join(f"file '{s}'\n" for s in segs))
out = Path.home()/"Videos/intro_video_demos/voice_casting.mp4"
subprocess.run(["ffmpeg","-y","-v","error","-f","concat","-safe","0","-i",str(lst),
                "-c","copy",str(out)], check=True)
print("\n->", out)
