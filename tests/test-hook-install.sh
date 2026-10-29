#!/bin/bash
# init 安装 sdlc hooks 到 .agents/hooks/，并由同步脚本注册到 .claude/settings.json 与 .codex/hooks.json。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$HERE/.." && pwd)"; SKILL_DIR="$REPO_DIR/sdlc-workflow"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0
cnt() { jq "[.hooks.$2[]?.hooks[]? | select(.command|test(\"$3\"))] | length" "$1"; }

bash "$SKILL_DIR/scripts/init-project.sh" "$TMP" >/dev/null 2>&1
for h in sdlc-hook-lib.sh sdlc-post-edit-check.sh sdlc-pre-edit-guard.sh; do
  [ -f "$TMP/.agents/hooks/$h" ] || { echo "FAIL: $h 未安装到 .agents/hooks/"; fail=1; }
done
[ "$(cnt "$TMP/.claude/settings.json" PostToolUse sdlc-post-edit-check)" = "1" ] || { echo "FAIL: settings 编辑后检查条目数不为 1"; fail=1; }
[ "$(cnt "$TMP/.claude/settings.json" PreToolUse sdlc-pre-edit-guard)" = "1" ] || { echo "FAIL: settings 越界守卫条目数不为 1"; fail=1; }
m="$(jq -r '.hooks.PreToolUse[0].matcher' "$TMP/.claude/settings.json")"
[ "$m" = "Edit|Write|MultiEdit" ] || { echo "FAIL: guard matcher = $m"; fail=1; }
jq -r '.hooks.PostToolUse[0].hooks[0].command' "$TMP/.claude/settings.json" | grep -q '^bash "${CLAUDE_PROJECT_DIR}/.agents/hooks/sdlc-post-edit-check.sh"$' || { echo "FAIL: 编辑后检查命令应为 bash + .agents/hooks"; fail=1; }
[ "$(cnt "$TMP/.codex/hooks.json" PostToolUse sdlc-post-edit-check)" = "1" ] || { echo "FAIL: codex hooks 缺编辑后检查"; fail=1; }
[ "$(cnt "$TMP/.codex/hooks.json" PreToolUse sdlc-pre-edit-guard)" = "0" ] || { echo "FAIL: codex 不应注册越界守卫"; fail=1; }

# ── update 幂等（Task 9）──
[ "$fail" = "0" ] && echo PASS || exit 1
