"""Renders the voice callout clips with Piper, a local neural text-to-speech engine
(https://github.com/OHF-Voice/piper1-gpl), then encodes them to .ogg with ffmpeg.
Run it through tools/generate_voices.sh, which brings Piper and ffmpeg along in Docker.

  Built-in packs into AlertCCOnMe/Media/Voice/<Pack>/:
    tools/generate_voices.sh
  One pack for a voice pack add-on (see templates/AlertCCOnMe_Voice_Example), with any
  voice from https://huggingface.co/rhasspy/piper-voices whose license allows it:
    tools/generate_voices.sh --name Grampa --voice en_US-joe-medium --out-dir <dir>
"""

import argparse
import json
import subprocess
import tempfile
import urllib.request
import wave
from pathlib import Path

from piper import PiperVoice, SynthesisConfig

ROOT = Path(__file__).resolve().parent.parent
MODELS = ROOT / "tools" / ".piper"
VOICES_URL = "https://huggingface.co/rhasspy/piper-voices/resolve/main/"

# Keep in sync with the callout keys in AlertCCOnMe/Data/CastableCC.lua (the offline
# tests check the built-in packs).
CALLOUTS = {
    "Sheep": "Sheep", "Cyclone": "Cyclone", "Hibernate": "Hibernate", "Roots": "Roots",
    "Sleep": "Sleep", "Fear": "Fear", "Seduction": "Seduction", "Banish": "Banish",
    "MindControl": "Mind control", "Shackle": "Shackle", "Hex": "Hex", "Lasso": "Lasso",
    "TurnEvil": "Turn evil", "ScareBeast": "Scare beast", "SongOfChiJi": "Song of Chee-Jee",
    "CC": "Crowd control", "Cast": "Cast",
}

# Pack name: (Piper voice, speaker in a multi-speaker voice). Credits in AlertCCOnMe/NOTICE.
PACKS = {
    "Bryce": ("en_US-bryce-medium", None),
    "Isla": ("en_GB-vctk-medium", "p277"),
}

# Slightly faster than Piper's default, so a callout is over before the cast is.
LENGTH_SCALE = 0.9

# Trim leading/trailing silence so the callout starts the instant it fires.
FILTER = (
    "silenceremove=start_periods=1:start_threshold=-50dB,areverse,"
    "silenceremove=start_periods=1:start_threshold=-50dB,areverse,loudnorm=I=-14:TP=-1"
)


def load(voice):
    """Loads a Piper voice, downloading it into tools/.piper/ on first use."""
    lang, name, quality = voice.split("-")
    MODELS.mkdir(parents=True, exist_ok=True)
    for ext in (".onnx", ".onnx.json"):
        path = MODELS / (voice + ext)
        if not path.exists():
            url = f"{VOICES_URL}{lang[:2]}/{lang}/{name}/{quality}/{voice}{ext}"
            urllib.request.urlretrieve(url, path)
    return PiperVoice.load(MODELS / (voice + ".onnx"))


def render(name, voice, speaker, out_dir):
    piper = load(voice)
    speaker_id = None
    if speaker is not None:
        speakers = json.loads((MODELS / (voice + ".onnx.json")).read_text())["speaker_id_map"]
        speaker_id = speakers[speaker]
    config = SynthesisConfig(speaker_id=speaker_id, length_scale=LENGTH_SCALE)
    out_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "clip.wav"
        for key, text in CALLOUTS.items():
            for suffix, line in (("OnYou", f"{text} on you!"), ("", f"{text}!")):
                with wave.open(str(wav), "wb") as f:
                    piper.synthesize_wav(line, f, syn_config=config)
                subprocess.run(
                    ["ffmpeg", "-loglevel", "error", "-y", "-i", str(wav), "-af", FILTER,
                     "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "4",
                     str(out_dir / f"{key}{suffix}.ogg")],
                    check=True,
                )
    print(f"{name}: {len(list(out_dir.glob('*.ogg')))} clips")


def main():
    parser = argparse.ArgumentParser(description="Render the voice callout clips with Piper.")
    parser.add_argument("--name", help="pack name (with --voice and --out-dir)")
    parser.add_argument("--voice", help="Piper voice, e.g. en_US-joe-medium")
    parser.add_argument("--speaker", help="speaker in a multi-speaker voice, e.g. p277")
    parser.add_argument("--out-dir", type=Path, help="where the .ogg clips go")
    args = parser.parse_args()
    if args.voice:
        if not (args.name and args.out_dir):
            parser.error("--voice needs --name and --out-dir")
        render(args.name, args.voice, args.speaker, args.out_dir)
        return
    for name, (voice, speaker) in PACKS.items():
        render(name, voice, speaker, ROOT / "AlertCCOnMe" / "Media" / "Voice" / name)


if __name__ == "__main__":
    main()
