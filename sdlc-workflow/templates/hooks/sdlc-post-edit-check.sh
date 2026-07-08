#!/bin/bash
# SDLC PostToolUse hook: run project check on the edited file.
# Contract: stdin = Claude Code PostToolUse JSON. PostToolUse cannot hard-block
# (the edit already ran); exit 2 makes Claude Code show this stderr to the model
# as feedback, which it then fixes. Degrades to exit 0 when a check is not
# applicable or tooling is absent.
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CONFIG="$PROJECT_DIR/.claude/.sdlc-config"

# Read config (best-effort)
EDIT_CHECK="on"; LINT_TOOL="eslint"
if [ -f "$CONFIG" ]; then
  v=$(grep -E '^EDIT_CHECK=' "$CONFIG" | head -1 | cut -d= -f2-); [ -n "$v" ] && EDIT_CHECK="$v"
  v=$(grep -E '^LINT_TOOL=' "$CONFIG" | head -1 | cut -d= -f2-); [ -n "$v" ] && LINT_TOOL="$v"
fi
[ "$EDIT_CHECK" != "on" ] && exit 0

# Extract edited file path from stdin JSON (jq if present, else grep fallback)
payload="$(cat)"
if command -v jq >/dev/null 2>&1; then
  FILE="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')"
else
  FILE="$(printf '%s' "$payload" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
fi
[ -z "$FILE" ] || [ ! -f "$FILE" ] && exit 0

case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) : ;;   # code files we lint
  *) exit 0 ;;                              # not applicable
esac

# Resolve linter; absent -> graceful no-op (do not spam a project without it)
command -v "$LINT_TOOL" >/dev/null 2>&1 || exit 0

case "$LINT_TOOL" in
  biome) OUT="$(biome lint "$FILE" 2>&1)"; RC=$? ;;
  *)     OUT="$("$LINT_TOOL" "$FILE" 2>&1)"; RC=$? ;;
esac
if [ "$RC" -ne 0 ]; then
  {
    echo "[sdlc hook] ${LINT_TOOL} 检查未通过：$FILE"
    echo "$OUT"
    echo "请修复上述问题后再继续（项目规范由 .claude/skills / 编码规范定义）。"
  } >&2
  exit 2
fi
exit 0
