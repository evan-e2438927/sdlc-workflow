#!/bin/bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

bash "$SKILL_DIR/scripts/init-project.sh" "$TMP" >/dev/null 2>&1

fail=0
[ -x "$TMP/.claude/hooks/sdlc-post-edit-check.sh" ] || { echo "FAIL: hook not installed"; fail=1; }
if command -v jq >/dev/null 2>&1; then
  jq -e '.hooks.PostToolUse[0].hooks[0].command | test("sdlc-post-edit-check")' "$TMP/.claude/settings.json" >/dev/null || { echo "FAIL: settings hook missing"; fail=1; }
else
  grep -q 'sdlc-post-edit-check' "$TMP/.claude/settings.json" || { echo "FAIL: settings hook missing"; fail=1; }
fi
# Idempotent: running update twice keeps exactly one PostToolUse entry for our hook
bash "$SKILL_DIR/scripts/update-project.sh" "$TMP" >/dev/null 2>&1
bash "$SKILL_DIR/scripts/update-project.sh" "$TMP" >/dev/null 2>&1
if command -v jq >/dev/null 2>&1; then
  n="$(jq '[.hooks.PostToolUse[].hooks[] | select(.command|test("sdlc-post-edit-check"))] | length' "$TMP/.claude/settings.json")"
  [ "$n" = "1" ] || { echo "FAIL: not idempotent (got $n)"; fail=1; }
fi
# PreToolUse 越界守卫：安装、settings 条目、幂等
[ -x "$TMP/.claude/hooks/sdlc-pre-edit-guard.sh" ] || { echo "FAIL: guard not installed"; fail=1; }
if command -v jq >/dev/null 2>&1; then
  n="$(jq '[.hooks.PreToolUse[]?.hooks[]? | select(.command|test("sdlc-pre-edit-guard"))] | length' "$TMP/.claude/settings.json")"
  [ "$n" = "1" ] || { echo "FAIL: PreToolUse guard entries = $n (want 1)"; fail=1; }
  m="$(jq -r '.hooks.PreToolUse[0].matcher' "$TMP/.claude/settings.json")"
  [ "$m" = "Edit|Write|MultiEdit" ] || { echo "FAIL: guard matcher = $m"; fail=1; }

  # 旧项目：settings 里只有 PostToolUse，update 后应补上 PreToolUse，且 PostToolUse 不重复
  OLD="$(mktemp -d)"
  bash "$SKILL_DIR/scripts/init-project.sh" "$OLD" >/dev/null 2>&1
  jq 'del(.hooks.PreToolUse)' "$OLD/.claude/settings.json" > "$OLD/s.json" && mv "$OLD/s.json" "$OLD/.claude/settings.json"
  bash "$SKILL_DIR/scripts/update-project.sh" "$OLD" >/dev/null 2>&1
  n="$(jq '[.hooks.PreToolUse[]?.hooks[]? | select(.command|test("sdlc-pre-edit-guard"))] | length' "$OLD/.claude/settings.json")"
  [ "$n" = "1" ] || { echo "FAIL: update did not merge PreToolUse into old settings (got $n)"; fail=1; }
  n="$(jq '[.hooks.PostToolUse[].hooks[] | select(.command|test("sdlc-post-edit-check"))] | length' "$OLD/.claude/settings.json")"
  [ "$n" = "1" ] || { echo "FAIL: PostToolUse duplicated after merge (got $n)"; fail=1; }
  rm -rf "$OLD"
else
  grep -q 'sdlc-pre-edit-guard' "$TMP/.claude/settings.json" || { echo "FAIL: settings guard missing"; fail=1; }
fi
[ "$fail" = "0" ] && echo PASS || exit 1
