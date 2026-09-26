#!/bin/bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0

# 1. init 生成的配置含 AGENT_MODE=auto
bash "$SKILL_DIR/scripts/init-project.sh" "$TMP/fresh" >/dev/null 2>&1
grep -qx 'AGENT_MODE=auto' "$TMP/fresh/.claude/.sdlc-config" || { echo "FAIL: init 未生成 AGENT_MODE=auto"; fail=1; }

# 2. update 为缺该键的存量配置补齐，且保留用户已有值
mkdir -p "$TMP/old/.claude/rules"
cp "$SKILL_DIR/templates/ARCHITECTURE.md.tpl" "$TMP/old/.claude/ARCHITECTURE.md"
cp "$SKILL_DIR/templates/CLAUDE.md.tpl" "$TMP/old/.claude/CLAUDE.md"
printf 'TEST_FRAMEWORK=vitest\n' > "$TMP/old/.claude/.sdlc-config"
bash "$SKILL_DIR/scripts/update-project.sh" "$TMP/old" >/dev/null 2>&1
grep -qx 'AGENT_MODE=auto' "$TMP/old/.claude/.sdlc-config" || { echo "FAIL: update 未补齐 AGENT_MODE"; fail=1; }
grep -qx 'TEST_FRAMEWORK=vitest' "$TMP/old/.claude/.sdlc-config" || { echo "FAIL: update 丢失用户值 TEST_FRAMEWORK"; fail=1; }

# 3. update 不覆盖用户已设的 AGENT_MODE，且不产生重复键
perl -i -pe 's/^AGENT_MODE=.*/AGENT_MODE=single/' "$TMP/old/.claude/.sdlc-config"
bash "$SKILL_DIR/scripts/update-project.sh" "$TMP/old" >/dev/null 2>&1
grep -qx 'AGENT_MODE=single' "$TMP/old/.claude/.sdlc-config" || { echo "FAIL: update 覆盖了用户的 AGENT_MODE"; fail=1; }
n="$(grep -c '^AGENT_MODE=' "$TMP/old/.claude/.sdlc-config")"
[ "$n" = "1" ] || { echo "FAIL: AGENT_MODE 出现 $n 次"; fail=1; }

[ "$fail" = "0" ] && echo PASS || exit 1
