#!/bin/bash
# SDLC PreToolUse guard: during a multi-agent apply, stop a role sub-agent from
# writing outside its work-package allow list ($ITER_DIR/tracks/.allow-<role>).
# Contract: stdin = PreToolUse JSON (Claude Code file_path, or a Codex patch with
# several files). exit 2 blocks the tool call and shows stderr to the agent; exit 0
# allows. Blocks when any edited path is out of bounds. Fails open whenever the guard
# cannot tell who is writing or which allow list applies (Codex input carries no
# sub-agent identity, so the guard is registered for Claude Code only).
# sdlc 托管文件：由 sdlc-sync-agents.sh 刷新，不要手改。
set -uo pipefail
. "$(dirname "$0")/sdlc-hook-lib.sh"

PROJECT_DIR="$(sdlc_project_root)"
CONFIG="$PROJECT_DIR/.agents/.sdlc-config"
MARKER="$PROJECT_DIR/.agents/.sdlc-active-iteration"

EDIT_GUARD="on"
if [ -f "$CONFIG" ]; then
  v=$(grep -E '^EDIT_GUARD=' "$CONFIG" | head -1 | cut -d= -f2- | tr -d '\r'); [ -n "$v" ] && EDIT_GUARD="$v"
fi
[ "$EDIT_GUARD" != "on" ] && exit 0

payload="$(cat)"
AGENT_TYPE="$(sdlc_json_str '.agent_type' agent_type "$payload")"
[ -z "$AGENT_TYPE" ] && exit 0                      # main agent (or Codex: no identity)
case "${AGENT_TYPE##*:}" in
  sdlc-backend-dev)  ROLE=backend ;;
  sdlc-frontend-dev) ROLE=frontend ;;
  sdlc-test-dev)     ROLE=test ;;
  *) exit 0 ;;                                      # not an sdlc role (e.g. general-purpose fallback)
esac
[ -f "$MARKER" ] || exit 0                          # not inside an apply run

ROOT="$(cd "$PROJECT_DIR" 2>/dev/null && pwd -P)" || exit 0
PATHS="$(sdlc_edited_paths "$payload" "$ROOT")"
[ -z "$PATHS" ] && exit 0

ITER_DIR="$(head -1 "$MARKER" | tr -d '\r')"; ITER_DIR="${ITER_DIR%/}"
case "$ITER_DIR" in /*) ITER_ABS="$ITER_DIR" ;; *) ITER_ABS="$ROOT/$ITER_DIR" ;; esac

STATUS="$ITER_ABS/status.json"
[ -f "$STATUS" ] || exit 0
STAGE="$(sdlc_json_str '.pipeline_stage' pipeline_stage "$(cat "$STATUS")")"
case "$STAGE" in dev|test-audit) ;; *) exit 0 ;; esac   # stale marker outside dev/test-audit: allow

ALLOW="$ITER_ABS/tracks/.allow-$ROLE"
[ -f "$ALLOW" ] || exit 0

# rel_of <abs>: path relative to the project root, resolved through the nearest existing
# ancestor (the target of a Write may not exist yet, nor its parent directories).
# Prints nothing when the path is outside the project (not the guard's concern).
rel_of() {
  local d rest full
  d="$(dirname "$1")"; rest="$(basename "$1")"
  while [ ! -d "$d" ] && [ "$d" != "/" ]; do rest="$(basename "$d")/$rest"; d="$(dirname "$d")"; done
  d="$(cd "$d" 2>/dev/null && pwd -P)" || return 0
  full="${d%/}/$rest"
  case "$full" in "$ROOT"/*) printf '%s\n' "${full#"$ROOT"/}" ;; esac
}

# allowed <rel>: 0 when some allow-list line matches
allowed() {
  local pat
  while IFS= read -r pat || [ -n "$pat" ]; do
    pat="${pat%$'\r'}"; pat="${pat#./}"
    case "$pat" in ''|'#'*) continue ;; esac
    # Only * is a wildcard (and it still crosses /); escape [ ] ? so they match literally
    # instead of being read as bash glob character-class/single-char syntax (Next.js/Expo
    # Router dynamic route segments like [slug] or [...slug] must match literally).
    pat="${pat//\[/\\[}"; pat="${pat//\]/\\]}"; pat="${pat//\?/\\?}"
    # shellcheck disable=SC2254  # unquoted on purpose: allow-list lines are glob patterns; only * is special (see escaping above)
    case "$1" in $pat) return 0 ;; esac
  done < "$ALLOW"
  return 1
}

DENIED=""
while IFS= read -r abs; do
  [ -n "$abs" ] || continue
  REL="$(rel_of "$abs")"
  [ -n "$REL" ] || continue
  allowed "$REL" || DENIED="$DENIED$REL"$'\n'
done <<EOF
$PATHS
EOF
[ -z "$DENIED" ] && exit 0

{
  printf '%s' "$DENIED" | while IFS= read -r rel; do
    echo "[sdlc guard] $ROLE 不能写 $rel（不在本次工作包允许清单 $ITER_DIR/tracks/.allow-$ROLE 内）。"
  done
  echo "如确需修改：停止该任务，在 $ITER_DIR/tracks/$ROLE.md 标 blocked，并在「公共文件修改请求」写明文件与原因；不要改用 Bash 等方式绕过。"
} >&2
exit 2
