#!/usr/bin/env python3
"""Runs the on-device systems on bench/data/images and writes bench/data/outputs/<id>.<system>.txt:

    squint    Squint's Code Mode (release build)
    plain     Apple Vision with default settings (`squint --plain`)
    livetext  Apple's Live Text engine (bench/LiveText.swift)
    trex      TRex's own OCR engine, only if TREX_RUNNER points at a built runner (see bench/README.md)

Also records Squint's wall-clock time per image, including process start-up.

    swift build -c release && python3 bench/run.py [data directory, default bench/data]

SQUINT_BINARY overrides the Squint executable, to measure a specific build.
"""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "bench" / "data"
IMAGES, OUTPUTS = DATA / "images", DATA / "outputs"
SQUINT = Path(os.environ.get("SQUINT_BINARY", ROOT / ".build" / "release" / "Squint"))


def main():
    OUTPUTS.mkdir(exist_ok=True)
    seconds = {}
    for image in sorted(IMAGES.glob("*.png")):
        for system, flags in [("squint", []), ("plain", ["--plain"])]:
            start = time.perf_counter()
            text = subprocess.run([SQUINT, *flags, image], capture_output=True, text=True, check=True).stdout
            if system == "squint":
                seconds[image.stem] = round(time.perf_counter() - start, 3)
            (OUTPUTS / f"{image.stem}.{system}.txt").write_text(text, encoding="utf-8")
    (DATA / "squint-seconds.json").write_text(json.dumps(seconds, indent=2) + "\n", encoding="utf-8")
    print(f"squint, plain: {len(seconds)} images")

    subprocess.run(["swift", ROOT / "bench" / "LiveText.swift", IMAGES, OUTPUTS], check=True)
    if runner := os.environ.get("TREX_RUNNER"):
        subprocess.run([runner, IMAGES, OUTPUTS], check=True)
        print(f"trex: {len(list(OUTPUTS.glob('*.trex.txt')))} images")


if __name__ == "__main__":
    main()
