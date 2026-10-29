#!/bin/bash
# SDLC PostToolUse hook: run the project linter on every edited code file.
# Contract: stdin = PostToolUse JSON (Claude Code file_path, or a Codex patch with
# several files). PostToolUse cannot hard-block (the edit already ran); exit 2 shows
# stderr to the model as feedback, which it then fixes. Degrades to exit 0 when a
# check is not applicable or tooling is absent.
# sdlc 托管文件：由 sdlc-sync-agents.sh 刷新，不要手改。
set -uo pipefail
. "$(dirname "$0")/sdlc-hook-lib.sh"

PROJECT_DIR="$(sdlc_project_root)"
CONFIG="$PROJECT_DIR/.agents/.sdlc-config"

# Read config (best-effort)
EDIT_CHECK="on"; LINT_TOOL="eslint"
if [ -f "$CONFIG" ]; then
  v=$(grep -E '^EDIT_CHECK=' "$CONFIG" | head -1 | cut -d= -f2- | tr -d '\r'); [ -n "$v" ] && EDIT_CHECK="$v"
  v=$(grep -E '^LINT_TOOL=' "$CONFIG" | head -1 | cut -d= -f2- | tr -d '\r'); [ -n "$v" ] && LINT_TOOL="$v"
fi
[ "$EDIT_CHECK" != "on" ] && exit 0

payload="$(cat)"
ROOT="$(cd "$PROJECT_DIR" 2>/dev/null && pwd -P)" || ROOT="/"
PATHS="$(sdlc_edited_paths "$payload" "$ROOT")"
[ -z "$PATHS" ] && exit 0

# resolve_linter <file>: the nearest project-local node_modules/.bin (walking up from the
# edited file to the project root) wins, and runs from that package dir so it uses the
# package's own version and config; otherwise fall back to PATH. Absent -> return 1.
resolve_linter() {
  local dir
  dir="$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)" || return 1
  while :; do
    if [ -x "$dir/node_modules/.bin/$LINT_TOOL" ]; then
      LINT_BIN="$dir/node_modules/.bin/$LINT_TOOL"; LINT_CWD="$dir"; return 0
    fi
    if [ "$dir" = "$ROOT" ] || [ "$dir" = "/" ]; then break; fi
    dir="$(dirname "$dir")"
  done
  LINT_BIN="$(command -v "$LINT_TOOL" 2>/dev/null)" || return 1
  LINT_CWD="$ROOT"
}

FAILED=0
while IFS= read -r FILE; do
  [ -n "$FILE" ] && [ -f "$FILE" ] || continue
  case "$FILE" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) : ;;   # code files we lint
    *) continue ;;                            # not applicable
  esac
  resolve_linter "$FILE" || continue
  case "$LINT_TOOL" in
    biome) OUT="$(cd "$LINT_CWD" && "$LINT_BIN" lint "$FILE" 2>&1)"; RC=$? ;;
    *)     OUT="$(cd "$LINT_CWD" && "$LINT_BIN" "$FILE" 2>&1)"; RC=$? ;;
  esac
  if [ "$RC" -ne 0 ]; then
    {
      echo "[sdlc hook] ${LINT_TOOL} 检查未通过：$FILE（linter: $LINT_BIN）"
      echo "$OUT"
    } >&2
    FAILED=1
  fi
done <<EOF
$PATHS
EOF

if [ "$FAILED" -ne 0 ]; then
  echo "请修复上述问题后再继续（项目规范由 .agents/ 下的编码规范与项目 skill 定义）。" >&2
  exit 2
fi
exit 0
