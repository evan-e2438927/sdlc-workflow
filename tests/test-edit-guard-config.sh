#!/bin/bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$HERE/.." && pwd)"; SKILL_DIR="$REPO_DIR/sdlc-workflow"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0

# init：EDIT_GUARD=on，标记文件进 .gitignore
bash "$SKILL_DIR/scripts/init-project.sh" "$TMP/fresh" >/dev/null 2>&1
grep -qx 'EDIT_GUARD=on' "$TMP/fresh/.agents/.sdlc-config" || { echo "FAIL: init 未生成 EDIT_GUARD=on"; fail=1; }
grep -qxF '.agents/.sdlc-active-iteration' "$TMP/fresh/.gitignore" || { echo "FAIL: init 未把标记文件加入 .gitignore"; fail=1; }

# update：老配置补齐 EDIT_GUARD；用户设的 off 不被覆盖；.gitignore 补齐
mkdir -p "$TMP/old/.claude/rules"
cp "$SKILL_DIR/templates/ARCHITECTURE.md.tpl" "$TMP/old/.claude/ARCHITECTURE.md"
cp "$SKILL_DIR/templates/AGENTS.md.tpl" "$TMP/old/.claude/CLAUDE.md"
printf 'LINT_TOOL=biome\n' > "$TMP/old/.claude/.sdlc-config"
bash "$SKILL_DIR/scripts/update-project.sh" "$TMP/old" >/dev/null 2>&1
grep -qx 'EDIT_GUARD=on' "$TMP/old/.claude/.sdlc-config" || { echo "FAIL: update 未补齐 EDIT_GUARD"; fail=1; }
grep -qxF '.claude/.sdlc-active-iteration' "$TMP/old/.gitignore" || { echo "FAIL: update 未把标记文件加入 .gitignore"; fail=1; }
perl -i -pe 's/^EDIT_GUARD=.*/EDIT_GUARD=off/' "$TMP/old/.claude/.sdlc-config"
bash "$SKILL_DIR/scripts/update-project.sh" "$TMP/old" >/dev/null 2>&1
grep -qx 'EDIT_GUARD=off' "$TMP/old/.claude/.sdlc-config" || { echo "FAIL: update 覆盖了用户的 EDIT_GUARD"; fail=1; }

[ "$fail" = "0" ] && echo PASS || exit 1
