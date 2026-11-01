#!/usr/bin/env python3
"""Processa as gravações brutas de `audios/` e gera os clipes do app.

Para cada arquivo: corrige nomes conhecidos, converte MP3->WAV, mono 48 kHz, corta silêncio
no início/fim, nivela o volume e grava `.caf` em
`Packages/AganhaAudio/Sources/AganhaAudio/Resources/<idioma>/<voz>/`.
Os originais em `audios/` nunca são alterados.

Uso:
  scripts/process_audio.py            processa tudo e imprime o relatório
  scripts/process_audio.py --missing  lista só os clipes do manifesto que ainda faltam
"""
import array
import csv
import math
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "audios"
MANIFEST = ROOT / "docs" / "audio-manifest.csv"
OUT = ROOT / "Packages/AganhaAudio/Sources/AganhaAudio/Resources"
LANG = "pt-BR"
RATE = 48000

# Erros de digitação conhecidos nos nomes entregues pelo estúdio.
RENAMES = {
    "lu_flow_preparador_v1": "lu_flow_preparados_v1",
    "lu_flow_nivel_sapequa_v1": "lu_flow_nivel_sapeca_v1",
}

LEAD_PAD_MS = 4       # sobra de silêncio antes da palavra
TAIL_PAD_MS = 60      # cauda natural depois da palavra
FADE_IN_MS = 3
FADE_OUT_MS = 40
START_THRESHOLD = 0.03   # -30 dB relativo ao pico
END_THRESHOLD = 0.012    # -38 dB relativo ao pico
PEAK_CEILING = 0.891     # -1 dBFS
TARGET_RMS_DB = {"cmd": -16.0}
DEFAULT_RMS_DB = -18.0
MAX_COMMAND_S = 0.8


def db(x):
    return 20 * math.log10(max(x, 1e-9))


def normalized_stem(path):
    stem = path.stem
    return RENAMES.get(stem, stem)


def to_mono_wav(src, dst):
    subprocess.run(["afconvert", "-f", "WAVE", "-d", f"LEI16@{RATE}", "-c", "1", str(src), str(dst)],
                   check=True, capture_output=True)


def read_samples(path):
    with wave.open(str(path)) as w:
        assert w.getsampwidth() == 2 and w.getnchannels() == 1
        data = array.array("h")
        data.frombytes(w.readframes(w.getnframes()))
    return [s / 32768 for s in data]


def write_wav(path, samples):
    data = array.array("h", (max(-32768, min(32767, round(s * 32767))) for s in samples))
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def process(samples, category):
    peak = max((abs(s) for s in samples), default=0)
    if peak < 1e-4:
        raise ValueError("arquivo silencioso")
    first = next(i for i, s in enumerate(samples) if abs(s) >= peak * START_THRESHOLD)
    last = max(i for i, s in enumerate(samples) if abs(s) >= peak * END_THRESHOLD)
    start = max(0, first - RATE * LEAD_PAD_MS // 1000)
    end = min(len(samples), last + RATE * TAIL_PAD_MS // 1000)
    clip = samples[start:end]

    fade_in = RATE * FADE_IN_MS // 1000
    fade_out = min(len(clip), RATE * FADE_OUT_MS // 1000)
    for i in range(min(fade_in, len(clip))):
        clip[i] *= i / fade_in
    for i in range(fade_out):
        clip[len(clip) - 1 - i] *= i / fade_out

    active = [s for s in clip if abs(s) >= peak * START_THRESHOLD]
    rms = math.sqrt(sum(s * s for s in active) / max(len(active), 1))
    target = TARGET_RMS_DB.get(category, DEFAULT_RMS_DB)
    gain = 10 ** (target / 20) / rms
    clip_peak = max(abs(s) for s in clip)
    limited = clip_peak * gain > PEAK_CEILING
    if limited:
        gain = PEAK_CEILING / clip_peak
    return [s * gain for s in clip], start / RATE * 1000, db(gain), limited


def missing():
    have = {p.stem for p in (OUT / LANG / "lu").glob("*.caf")} if (OUT / LANG / "lu").exists() else set()
    rows = [r for r in csv.DictReader(open(MANIFEST, encoding="utf-8")) if r["voice"] == "lu"]
    todo = [r for r in rows if r["filename"][:-4] not in have]
    for prio in ("P0", "P1", "P2"):
        group = [r for r in todo if r["priority"] == prio]
        print(f"\n{prio}: {len(group)} faltando")
        for r in group:
            print(f"  {r['filename']}  {r['text']}")
    print(f"\nTotal: {len(todo)} de {len(rows)} faltando")


def main():
    if "--missing" in sys.argv:
        return missing()
    out_dir = OUT / LANG / "lu"
    out_dir.mkdir(parents=True, exist_ok=True)
    print(f"{'arquivo':40} {'corte ini':>9} {'dur(s)':>7} {'ganho':>7}  obs")
    problems = 0
    for src in sorted(RAW.iterdir()):
        if src.suffix.lower() not in (".wav", ".mp3"):
            continue
        stem = normalized_stem(src)
        category = stem.split("_")[1] if "_" in stem else ""
        with tempfile.TemporaryDirectory() as tmp:
            mono = Path(tmp) / "mono.wav"
            to_mono_wav(src, mono)
            clip, cut_ms, gain_db, limited = process(read_samples(mono), category)
            final = Path(tmp) / "final.wav"
            write_wav(final, clip)
            subprocess.run(["afconvert", "-f", "caff", "-d", f"LEI16@{RATE}", str(final),
                            str(out_dir / f"{stem}.caf")], check=True, capture_output=True)
        dur = len(clip) / RATE
        notes = []
        if src.stem != stem:
            notes.append(f"renomeado de {src.stem}")
        if src.suffix.lower() == ".mp3":
            notes.append("mp3->caf")
        if limited:
            notes.append("limitado pelo pico")
        if category == "cmd" and dur > MAX_COMMAND_S:
            notes.append(f"LONGO (>{MAX_COMMAND_S}s)")
            problems += 1
        print(f"{stem:40} {cut_ms:7.0f}ms {dur:7.2f} {gain_db:+6.1f}dB  {'; '.join(notes)}")
    print(f"\nSaída: {out_dir.relative_to(ROOT)}  ({problems} comando(s) longo(s))")


if __name__ == "__main__":
    main()
