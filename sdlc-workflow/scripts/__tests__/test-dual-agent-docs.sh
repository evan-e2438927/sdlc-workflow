#!/bin/bash
# 双模式（单/多 agent）相关 markdown 规范的结构断言。各任务在 "# ── END ──" 前追加自己的断言段。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/../.." && pwd)"
REPO_DIR="$(cd "$SKILL_DIR/.." && pwd)"
R="$SKILL_DIR/references"
fail=0
has()    { grep -qF -- "$2" "$1" 2>/dev/null || { echo "FAIL: $1 缺少: $2"; fail=1; }; }
lacks()  { ! grep -qF -- "$2" "$1" 2>/dev/null || { echo "FAIL: $1 不应包含: $2"; fail=1; }; }
exists() { [ -f "$1" ] || { echo "FAIL: 缺少文件 $1"; fail=1; }; }

# ── Task 2: Track 统一 + Gate 1 名单 ──
has   "$R/05-design-reviewer.md" '["frontend","backend","shared","infra","unit-test","qa"]'
has   "$R/05-design-reviewer.md" '"unit-test": ["tests/unit/"]'
has   "$R/05-design-reviewer.md" '["tests/e2e/"]'
has   "$R/05-design-reviewer.md" '"packages/contracts/"'
lacks "$R/05-design-reviewer.md" 'track == "test"'
lacks "$R/05-design-reviewer.md" '（frontend / backend / shared / infra / test）'
has   "$R/04-task-generator.md"  '`packages/auth/**`, `packages/contracts/**`'
has   "$SKILL_DIR/SKILL.md"      'track: frontend|backend|shared|infra|unit-test|qa'

# ── END ──
[ "$fail" = "0" ] && echo PASS || exit 1
