#!/bin/bash
# Track 路径规则：references/track-paths.md 的 JSON 是唯一来源；
# 04/05 必须引用它，08 三份 Codex 指令与 workflow-rules.md.tpl 的内联副本必须与它一致。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/../.." && pwd)"
python3 - "$SKILL_DIR" <<'PY'
import json, re, sys, pathlib
root = pathlib.Path(sys.argv[1])
R = root / "references"
fails = []
def fail(msg): fails.append(msg)

src = R / "track-paths.md"
if not src.exists():
    print("FAIL: 缺少 references/track-paths.md"); sys.exit(1)
blocks = re.findall(r"```json\n(.*?)\n```", src.read_text(encoding="utf-8"), re.S)
if len(blocks) != 1:
    print(f"FAIL: track-paths.md 应恰好有 1 个 json 代码块，实际 {len(blocks)}"); sys.exit(1)
data = json.loads(blocks[0])
tracks = data["tracks"]
for k in ("public_files", "test_file_patterns"):
    if k not in data: fail(f"track-paths.md 缺少字段 {k}")

def expand(tok):
    m = re.search(r"\{([^}]*)\}", tok)
    if not m: return [tok]
    return [x for alt in m.group(1).split(",") for x in expand(tok[:m.start()] + alt + tok[m.end():])]
def norm(tok):
    tok = tok.strip().strip("`")
    tok = re.sub(r"\*+$", "", tok)
    return tok if tok.endswith("/") else tok + "/"
def paths(xs): return {p for p in xs if not p.startswith("<")}

# 04 / 05：引用唯一来源，不再内联
t04 = (R / "04-task-generator.md").read_text(encoding="utf-8")
t05 = (R / "05-design-reviewer.md").read_text(encoding="utf-8")
if "references/track-paths.md" not in t04: fail("04 未引用 references/track-paths.md")
if "`apps/server/**`, `packages/api/**`" in t04: fail("04 §2.0 仍内联 backend 路径")
if "TRACK_PATH_RULES = references/track-paths.md 的 tracks 字段" not in t05: fail("05 TRACK_PATH_RULES 未改为引用")
if '"backend":   ["apps/server/"' in t05: fail("05 仍内联 TRACK_PATH_RULES")

# 08：三份内联白名单（backend / frontend 与 tracks 全等；test 行含 tests/unit/）
t08 = (R / "08-code-reviewer.md").read_text(encoding="utf-8")
for role in ("backend", "frontend"):
    lines = re.findall(rf"^- {role}: (.+)$", t08, re.M)
    if len(lines) != 3: fail(f"08 {role} 白名单应出现 3 次，实际 {len(lines)}")
    for i, line in enumerate(lines, 1):
        toks = re.split(r",\s*(?![^{}]*\})", line)
        got = {norm(x) for tok in toks for x in expand(tok.strip())}
        want = paths(tracks[role])
        if got != want: fail(f"08 第{i}份 {role} 白名单与 track-paths 不一致：多 {sorted(got-want)} 少 {sorted(want-got)}")
tests_lines = re.findall(r"^- test: (.+)$", t08, re.M)
if len(tests_lines) != 3 or not all("tests/unit/**" in l for l in tests_lines):
    fail("08 test 白名单应出现 3 次且含 tests/unit/**")

# workflow-rules.md.tpl：「Track 必须与目标文件路径自洽」一行的每段 `...` → track
tpl = (root / "templates" / "workflow-rules.md.tpl").read_text(encoding="utf-8")
m = re.search(r"^- Track 必须与目标文件路径自洽：(.+)$", tpl, re.M)
if not m:
    fail("workflow-rules.md.tpl 缺少「Track 必须与目标文件路径自洽」一行")
else:
    got = {}
    for seg in m.group(1).split("；"):
        if "→" not in seg: continue
        left, track = seg.rsplit("→", 1)
        track = track.strip().rstrip("。")
        got[track] = {norm(x) for tok in re.findall(r"`([^`]+)`", left) for x in expand(tok)}
    for track in ("frontend", "backend", "shared", "unit-test", "qa"):
        want = paths(tracks[track])
        if got.get(track) != want:
            fail(f"模板 {track} 与 track-paths 不一致：多 {sorted(got.get(track,set())-want)} 少 {sorted(want-got.get(track,set()))}")
    if "db/migrations/" not in got.get("infra", set()): fail("模板 infra 缺少 db/migrations/")

for f in fails: print("FAIL:", f)
print("PASS" if not fails else "")
sys.exit(1 if fails else 0)
PY
