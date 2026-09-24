#!/bin/bash
# SDLC PreToolUse guard: during a multi-agent apply, stop a role sub-agent from
# writing outside its work-package allow list ($ITER_DIR/tracks/.allow-<role>).
# Contract: stdin = Claude Code PreToolUse JSON. exit 2 blocks the tool call and
# shows stderr to the agent; exit 0 allows. Fails open whenever the guard cannot
# tell who is writing or which allow list applies.
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CONFIG="$PROJECT_DIR/.claude/.sdlc-config"
MARKER="$PROJECT_DIR/.claude/.sdlc-active-iteration"

EDIT_GUARD="on"
if [ -f "$CONFIG" ]; then
  v=$(grep -E '^EDIT_GUARD=' "$CONFIG" | head -1 | cut -d= -f2- | tr -d '\r'); [ -n "$v" ] && EDIT_GUARD="$v"
fi
[ "$EDIT_GUARD" != "on" ] && exit 0

payload="$(cat)"
# json_str <jq-filter> <key> <text>: jq when available, else a grep fallback for flat string keys
json_str() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$3" | jq -r "$1 // empty" 2>/dev/null
  else
    printf '%s' "$3" | grep -oE "\"$2\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 \
      | sed -E "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/"
  fi
}

AGENT_TYPE="$(json_str '.agent_type' agent_type "$payload")"
[ -z "$AGENT_TYPE" ] && exit 0                      # main agent
case "${AGENT_TYPE##*:}" in
  sdlc-backend-dev)  ROLE=backend ;;
  sdlc-frontend-dev) ROLE=frontend ;;
  sdlc-test-dev)     ROLE=test ;;
  *) exit 0 ;;                                      # not an sdlc role (e.g. general-purpose fallback)
esac
FILE="$(json_str '.tool_input.file_path' file_path "$payload")"
[ -z "$FILE" ] && exit 0
[ -f "$MARKER" ] || exit 0                          # not inside an apply run

ROOT="$(cd "$PROJECT_DIR" 2>/dev/null && pwd -P)" || exit 0
ITER_DIR="$(head -1 "$MARKER" | tr -d '\r')"; ITER_DIR="${ITER_DIR%/}"
case "$ITER_DIR" in /*) ITER_ABS="$ITER_DIR" ;; *) ITER_ABS="$ROOT/$ITER_DIR" ;; esac

STATUS="$ITER_ABS/status.json"
[ -f "$STATUS" ] || exit 0
STAGE="$(json_str '.pipeline_stage' pipeline_stage "$(cat "$STATUS")")"
case "$STAGE" in dev|test-audit) ;; *) exit 0 ;; esac   # stale marker outside dev/test-audit: allow

ALLOW="$ITER_ABS/tracks/.allow-$ROLE"
[ -f "$ALLOW" ] || exit 0

# Path relative to the project root, resolved through the nearest existing ancestor
# (the target of a Write may not exist yet, nor its parent directories).
case "$FILE" in /*) ABS="$FILE" ;; *) ABS="$PWD/$FILE" ;; esac
d="$(dirname "$ABS")"; rest="$(basename "$ABS")"
while [ ! -d "$d" ] && [ "$d" != "/" ]; do rest="$(basename "$d")/$rest"; d="$(dirname "$d")"; done
d="$(cd "$d" 2>/dev/null && pwd -P)" || exit 0
FULL="${d%/}/$rest"
case "$FULL" in
  "$ROOT"/*) REL="${FULL#"$ROOT"/}" ;;
  *) exit 0 ;;                                      # outside the project: not the guard's concern
esac

while IFS= read -r pat || [ -n "$pat" ]; do
  pat="${pat%$'\r'}"; pat="${pat#./}"
  case "$pat" in ''|'#'*) continue ;; esac
  # shellcheck disable=SC2254  # unquoted on purpose: allow-list lines are glob patterns
  case "$REL" in $pat) exit 0 ;; esac
done < "$ALLOW"

{
  echo "[sdlc guard] $ROLE 不能写 $REL（不在本次工作包允许清单 $ITER_DIR/tracks/.allow-$ROLE 内）。"
  echo "如确需修改：停止该任务，在 $ITER_DIR/tracks/$ROLE.md 标 blocked，并在「公共文件修改请求」写明文件与原因；不要改用 Bash 等方式绕过。"
} >&2
exit 2
