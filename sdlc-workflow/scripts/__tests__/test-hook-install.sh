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
[ "$fail" = "0" ] && echo PASS || exit 1
