#!/usr/bin/env python3
"""Scores every bench/data/outputs/<id>.<system>.txt against bench/data/truth/<id>.txt.

Metrics, per image, then averaged:
    CER          character error rate: edit distance / ground-truth length (whitespace counts)
    lines exact  share of lines identical to the truth at the same position (indentation counts)
    exact        the whole snippet is identical: paste it and nothing needs fixing
    parses       Python compiles it / `node --check` accepts it

Trailing whitespace and trailing blank lines are ignored for every system (they're invisible on screen),
as is a Markdown code fence around a whole answer. Writes bench/results.csv and prints Markdown tables,
plus a two-sided sign test of Squint against each other system on per-image CER.

    python3 bench/score.py [data directory, default bench/data]
"""
import csv
import json
import math
import subprocess
import sys
import tempfile
from collections import defaultdict
from pathlib import Path

BENCH = Path(__file__).parent
DATA = Path(sys.argv[1]) if len(sys.argv) > 1 else BENCH / "data"
ORDER = ["squint", "claude", "livetext", "trex", "plain"]
NAMES = {"squint": "Squint (Code Mode)", "claude": "Claude (AI chat)", "livetext": "Apple Live Text",
         "trex": "TRex", "plain": "Apple Vision, default settings"}


def normalized(text):
    lines = [line.rstrip() for line in text.replace("\r\n", "\n").split("\n")]
    if lines and lines[0].lstrip().startswith("```"):
        lines = lines[1:]
    while lines and lines[-1].strip() in ("", "```"):
        lines.pop()
    return "\n".join(lines)


def distance(a, b):
    if len(a) < len(b):
        a, b = b, a
    previous = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        current = [i]
        for j, cb in enumerate(b, 1):
            current.append(min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (ca != cb)))
        previous = current
    return previous[-1]


def parses(code, language):
    if language == "python":
        try:
            compile(code, "<output>", "exec")
            return True
        except (SyntaxError, ValueError):
            return False
    with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False) as file:
        file.write(code)
    return subprocess.run(["node", "--check", file.name], capture_output=True).returncode == 0


def sign_test(wins, losses):
    n, k = wins + losses, max(wins, losses)
    if n == 0:
        return 1.0
    return min(1.0, 2 * sum(math.comb(n, i) for i in range(k, n + 1)) / 2 ** n)


def table(rows, group):
    groups = sorted({row[group] for row in rows})
    systems = [s for s in ORDER if any(row["system"] == s for row in rows)]
    lines = [f"| System | " + " | ".join(f"{g} CER | {g} exact" for g in groups) + " |",
             "|---|" + "---|---|" * len(groups)]
    for system in systems:
        cells = []
        for g in groups:
            subset = [r for r in rows if r["system"] == system and r[group] == g]
            cells += [f"{sum(r['cer'] for r in subset) / len(subset):.1%}", f"{sum(r['exact'] for r in subset)}/{len(subset)}"]
        lines.append(f"| {NAMES[system]} | " + " | ".join(cells) + " |")
    return "\n".join(lines)


def main():
    # In the novel set, snippets whose renamed version didn't parse were left unchanged; they're excluded.
    manifest = {item["id"]: item for item in json.loads((DATA / "manifest.json").read_text()) if item.get("renamed", True)}
    rows = []
    for output in sorted((DATA / "outputs").glob("*.*.txt")):
        item_id, system = output.name.split(".")[:2]
        if item_id not in manifest:
            continue
        item = manifest[item_id]
        truth = normalized((DATA / "truth" / f"{item_id}.txt").read_text(encoding="utf-8"))
        text = normalized(output.read_text(encoding="utf-8"))
        truth_lines, lines = truth.split("\n"), text.split("\n")
        rows.append({
            "id": item_id, "system": system, "language": item["language"], "condition": item["condition"],
            "theme": item["theme"], "font": item["font"], "size": item["size"],
            "line_numbers": "with line numbers" if item["line_numbers"] else "no line numbers",
            "cer": distance(text, truth) / max(len(truth), 1),
            "lines_exact": sum(a == b for a, b in zip(lines, truth_lines)) / max(len(lines), len(truth_lines)),
            "exact": text == truth,
            "parses": parses(text, item["language"]),
        })

    with (BENCH / f"results-{DATA.name}.csv").open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0]))
        writer.writeheader()
        for row in rows:
            writer.writerow({**row, "cer": f"{row['cer']:.4f}", "lines_exact": f"{row['lines_exact']:.4f}"})

    by_system = defaultdict(list)
    for row in rows:
        by_system[row["system"]].append(row)
    print(f"## Overall ({len(manifest)} images)\n")
    print("| System | Character error rate | Lines exact | Snippet exact | Parses |")
    print("|---|---|---|---|---|")
    for system in [s for s in ORDER if s in by_system]:
        subset = by_system[system]
        n = len(subset)
        print(f"| {NAMES[system]} | {sum(r['cer'] for r in subset) / n:.1%} | {sum(r['lines_exact'] for r in subset) / n:.0%} "
              f"| {sum(r['exact'] for r in subset)}/{n} | {sum(r['parses'] for r in subset)}/{n} |")

    print("\n## Squint vs each system, per-image character error rate (two-sided sign test)\n")
    squint = {r["id"]: r["cer"] for r in by_system.get("squint", [])}
    for system in [s for s in ORDER if s in by_system and s != "squint"]:
        other = {r["id"]: r["cer"] for r in by_system[system]}
        shared = squint.keys() & other.keys()
        wins = sum(squint[i] < other[i] for i in shared)
        losses = sum(squint[i] > other[i] for i in shared)
        print(f"- vs {NAMES[system]}: Squint better on {wins}, worse on {losses}, tied on {len(shared) - wins - losses} "
              f"(p = {sign_test(wins, losses):.2g})")

    for group in ["condition", "line_numbers", "language"]:
        print(f"\n## By {group.replace('_', ' ')}\n")
        print(table(rows, group))

    seconds_file = DATA / "squint-seconds.json"
    if seconds_file.exists():
        seconds = sorted(json.loads(seconds_file.read_text()).values())
        print(f"\nSquint time per image (CLI, including start-up): median {seconds[len(seconds) // 2]:.2f} s, "
              f"95th percentile {seconds[min(len(seconds) - 1, math.ceil(0.95 * len(seconds)) - 1)]:.2f} s")


if __name__ == "__main__":
    main()
