#!/bin/bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/../.." && pwd)"
HOOK="$SKILL_DIR/templates/hooks/sdlc-post-edit-check.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.claude"

run() { # $1=file_path  -> echoes exit code
  printf '{"tool_input":{"file_path":"%s"}}' "$1" | ( cd "$TMP" && CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK"; echo "EXIT:$?" >&2 ) 2>&1 | sed -n 's/.*EXIT:\([0-9]*\)/\1/p'
}

fail=0

# Case 1: EDIT_CHECK disabled -> always exit 0
printf 'EDIT_CHECK=off\n' > "$TMP/.claude/.sdlc-config"
echo "x" > "$TMP/a.txt"
[ "$(run "$TMP/a.txt")" = "0" ] || { echo "FAIL c1"; fail=1; }

# Case 2: EDIT_CHECK on, non-code file -> exit 0 (no applicable check)
printf 'EDIT_CHECK=on\nLINT_TOOL=eslint\n' > "$TMP/.claude/.sdlc-config"
[ "$(run "$TMP/a.txt")" = "0" ] || { echo "FAIL c2"; fail=1; }

# Case 3: EDIT_CHECK on, code file, linter binary absent -> graceful exit 0 (no hard block)
echo "const x=1" > "$TMP/b.ts"
PATH="/usr/bin:/bin" # eslint not resolvable
[ "$(run "$TMP/b.ts")" = "0" ] || { echo "FAIL c3"; fail=1; }

[ "$fail" = "0" ] && echo PASS || { echo "SOME FAILED"; exit 1; }
