#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Arrange: a project whose CLAUDE.md still has the old unbounded instruction
mkdir -p "$TMP/.claude/rules"
cp "$SKILL_DIR/templates/ARCHITECTURE.md.tpl" "$TMP/.claude/ARCHITECTURE.md"
cat > "$TMP/.claude/CLAUDE.md" <<'EOF'
# demo
## 迭代历史
**在处理新需求时，务必先阅读 `docs/iterations/` 下的历史迭代**，了解已有的设计决策。
## 自定义 Skills
placeholder
EOF

# Act
bash "$SKILL_DIR/scripts/update-project.sh" "$TMP" >/dev/null

# Assert: old unbounded line gone, bounded reference present, idempotent (run twice)
bash "$SKILL_DIR/scripts/update-project.sh" "$TMP" >/dev/null
grep -q 'HISTORY_ITER_DEPTH' "$TMP/.claude/CLAUDE.md" || { echo "FAIL: not migrated"; exit 1; }
! grep -q '务必先阅读 `docs/iterations/` 下的历史迭代' "$TMP/.claude/CLAUDE.md" || { echo "FAIL: old line remains"; exit 1; }
echo PASS
