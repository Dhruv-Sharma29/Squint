#!/usr/bin/env python3
"""Builds the benchmark set: real functions from Python's standard library and npm's JavaScript source,
each paired with randomized rendering settings (theme, font, size, line numbers, video degradation).

Seeded, so it produces the same set every time. Snippets are picked at random, never by looking at
how Squint does on them, so results on this set are test results, not tuning results.

    python3 bench/make_dataset.py           ->  bench/data/truth/<id>.txt and bench/data/manifest.json
    python3 bench/make_dataset.py --novel   ->  bench/data-novel/: the same snippets with every identifier
                                                consistently renamed, so no model can recall the code from training
"""
import ast
import builtins
import io
import json
import keyword
import random
import re
import subprocess
import sys
import sysconfig
import tempfile
import textwrap
import tokenize
from pathlib import Path

SEED = 20261024
PER_LANGUAGE = 20
MIN_LINES, MAX_LINES, MAX_WIDTH = 6, 22, 84
MAX_PER_FILE = 2

DATA = Path(__file__).parent / "data"
THEMES = ["dark-plus", "light-plus", "github-light", "monokai", "solarized-dark", "one-dark"]
FONTS = ["SF Mono", "Menlo", "Monaco", "Courier New", "Andale Mono", "PT Mono"]
SIZES = [12, 13, 14, 16, 18, 20]


def usable(lines):
    return (MIN_LINES <= len(lines) <= MAX_LINES
            and all(len(line) <= MAX_WIDTH and line.isascii() and "\t" not in line for line in lines))


def python_snippets():
    stdlib = Path(sysconfig.get_paths()["stdlib"])
    for path in sorted(stdlib.glob("*.py")) + sorted(stdlib.glob("*/*.py")):
        if any(part in {"test", "tests", "idlelib", "site-packages", "turtledemo"} for part in path.parts):
            continue
        try:
            source = path.read_text(encoding="utf-8")
            tree = ast.parse(source)
        except (UnicodeDecodeError, SyntaxError):
            continue
        lines = source.splitlines()
        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                start = min([d.lineno for d in node.decorator_list] + [node.lineno]) - 1
                snippet = textwrap.dedent("\n".join(lines[start:node.end_lineno])).rstrip()
                if usable(snippet.splitlines()):
                    yield str(path.relative_to(stdlib)), snippet


def javascript_snippets():
    root = Path(subprocess.check_output(["npm", "root", "-g"], text=True).strip()) / "npm" / "lib"
    start = re.compile(r"^\s*(async\s+)?function\s*\*?\s*\w+\s*\(|^\s*(const|let)\s+\w+\s*=\s*(async\s*)?\([^)]*\)\s*=>\s*\{\s*$")
    for path in sorted(root.rglob("*.js")):
        lines = path.read_text(encoding="utf-8").splitlines()
        for index, line in enumerate(lines):
            if not start.match(line):
                continue
            depth, end = 0, None
            for offset, candidate in enumerate(lines[index:index + MAX_LINES + 1]):
                depth += candidate.count("{") - candidate.count("}")
                if depth == 0 and "{" in "".join(lines[index:index + offset + 1]):
                    end = index + offset
                    break
            if end is not None:
                snippet = textwrap.dedent("\n".join(lines[index:end + 1])).rstrip()
                if usable(snippet.splitlines()):
                    yield str(path.relative_to(root.parent)), snippet


def python_parses(code):
    try:
        compile(code, "<snippet>", "exec")
        return True
    except SyntaxError:
        return False


def javascript_parses(code):
    with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False) as file:
        file.write(code)
    return subprocess.run(["node", "--check", file.name], capture_output=True).returncode == 0


def pick(candidates, parses, rng):
    candidates = list(candidates)
    rng.shuffle(candidates)
    chosen, per_file = [], {}
    for source, snippet in candidates:
        if per_file.get(source, 0) >= MAX_PER_FILE or not parses(snippet):
            continue
        per_file[source] = per_file.get(source, 0) + 1
        chosen.append((source, snippet))
        if len(chosen) == PER_LANGUAGE:
            break
    return chosen


WORDS = ("amber bolt cedar delta ember fable grove harbor ivory jasper kiln lumen maple nectar onyx pylon quartz "
         "raven sable tundra umber vertex willow yarrow zephyr basil comet dune fjord glyph heron inlet jolt knoll "
         "lotus mesa nimbus orbit prism quill ridge spire thorn usher vapor wren").split()
KEEP_JS = set("""break case catch class const continue debugger default delete do else export extends false finally for
function if import in instanceof let new null of return static super switch this throw true try typeof undefined var void
while with yield async await require module exports process console JSON Object Array Promise Math Error Set Map Symbol
Number String Boolean Date RegExp Buffer globalThis NaN Infinity length push pop map filter join split slice keys values
entries forEach reduce includes indexOf startsWith endsWith replace trim toString then resolve reject has get set add
delete size log error warn apply call bind prototype constructor sort concat some every find assign""".split())


def fresh_name(original, rng, taken):
    """A new identifier in the same style (snake_case, camelCase, PascalCase or UPPER_CASE) as `original`."""
    prefix = original[: len(original) - len(original.lstrip("_"))]
    core = original.lstrip("_")
    while True:
        words = [rng.choice(WORDS) for _ in range(1 if len(core) <= 4 else 2)]
        if core.isupper() and len(core) > 1:
            name = "_".join(words).upper()
        elif "_" in core or core.islower():
            name = "_".join(words)
        elif core[:1].isupper():
            name = "".join(word.capitalize() for word in words)
        else:
            name = words[0] + "".join(word.capitalize() for word in words[1:])
        name = prefix + name
        if name not in taken:
            taken.add(name)
            return name


def renamed_python(code, rng):
    keep = set(keyword.kwlist) | set(keyword.softkwlist) | set(dir(builtins)) | {"self", "cls"}
    mapping, taken = {}, set()
    spans = []
    for token in tokenize.generate_tokens(io.StringIO(code).readline):
        name = token.string
        if token.type == tokenize.NAME and name not in keep and not (name.startswith("__") and name.endswith("__")):
            if name not in mapping:
                mapping[name] = fresh_name(name, rng, taken)
            spans.append((token.start, token.end, mapping[name]))
    lines = code.split("\n")
    for (row, start), (_, end), new in sorted(spans, reverse=True):
        lines[row - 1] = lines[row - 1][:start] + new + lines[row - 1][end:]
    return "\n".join(lines)


def renamed_javascript(code, rng):
    mapping, taken, spans = {}, set(), []
    index, previous = 0, "op"  # previous significant token kind, to tell a regex literal from division
    while index < len(code):
        char = code[index]
        if code.startswith("//", index):
            index = code.find("\n", index) if "\n" in code[index:] else len(code)
        elif code.startswith("/*", index):
            close = code.find("*/", index + 2)
            index = len(code) if close == -1 else close + 2
        elif char in "'\"`":
            end = index + 1
            while end < len(code) and code[end] != char:
                end += 2 if code[end] == "\\" else 1
            index, previous = end + 1, "value"
        elif char == "/" and previous == "op":
            end, in_class = index + 1, False
            while end < len(code) and (code[end] != "/" or in_class):
                in_class = (in_class or code[end] == "[") and code[end] != "]"
                end += 2 if code[end] == "\\" else 1
            index, previous = end + 1, "value"
        elif char.isalpha() or char in "_$":
            end = index
            while end < len(code) and (code[end].isalnum() or code[end] in "_$"):
                end += 1
            word = code[index:end]
            if word not in KEEP_JS:
                if word not in mapping:
                    mapping[word] = fresh_name(word, rng, taken)
                spans.append((index, end, mapping[word]))
            index, previous = end, "op" if word in {"return", "typeof", "case", "in", "of", "new", "delete", "void", "throw"} else "value"
        elif char.isdigit():
            while index < len(code) and (code[index].isalnum() or code[index] == "."):
                index += 1
            previous = "value"
        else:
            if not char.isspace():
                previous = "value" if char in ")]}" else "op"
            index += 1
    for start, end, new in reversed(spans):
        code = code[:start] + new + code[end:]
    return code


def make_novel():
    """The same snippets and rendering settings, with every identifier renamed. Snippets whose renamed version
    doesn't parse are kept unchanged and flagged in the manifest."""
    rng = random.Random(SEED + 1)
    novel = DATA.parent / "data-novel"
    (novel / "truth").mkdir(parents=True, exist_ok=True)
    manifest = json.loads((DATA / "manifest.json").read_text())
    for item in manifest:
        code = (DATA / "truth" / f"{item['id']}.txt").read_text(encoding="utf-8").rstrip("\n")
        python = item["language"] == "python"
        candidate = renamed_python(code, rng) if python else renamed_javascript(code, rng)
        item["renamed"] = candidate != code and (python_parses(candidate) if python else javascript_parses(candidate))
        (novel / "truth" / f"{item['id']}.txt").write_text((candidate if item["renamed"] else code) + "\n", encoding="utf-8")
    (novel / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"{sum(item['renamed'] for item in manifest)} of {len(manifest)} snippets renamed -> {novel}")


def main():
    if "--novel" in sys.argv:
        return make_novel()
    rng = random.Random(SEED)
    (DATA / "truth").mkdir(parents=True, exist_ok=True)
    manifest = []
    for language, extension, candidates, parses in [
        ("python", "py", python_snippets(), python_parses),
        ("javascript", "js", javascript_snippets(), javascript_parses),
    ]:
        for number, (source, snippet) in enumerate(pick(candidates, parses, rng), start=1):
            item_id = f"{extension}-{number:02d}"
            (DATA / "truth" / f"{item_id}.txt").write_text(snippet + "\n", encoding="utf-8")
            manifest.append({
                "id": item_id,
                "language": language,
                "source": source,
                "theme": rng.choice(THEMES),
                "font": rng.choice(FONTS),
                "size": rng.choice(SIZES),
                "line_numbers": rng.random() < 0.4,
                "line_height": round(rng.uniform(1.2, 1.6), 2),
                "padding": rng.randint(12, 40),
                "condition": rng.choices(["screenshot", "video-1080p", "video-720p"], weights=[40, 35, 25])[0],
            })
    (DATA / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"{len(manifest)} snippets -> {DATA}")


if __name__ == "__main__":
    main()
