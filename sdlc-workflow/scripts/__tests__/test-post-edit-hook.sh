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

# Fake linters: each logs "<name> <cwd>" to $TMP/calls.log and exits with its configured code
fake_linter() { # $1=path $2=name $3=exit-code
  mkdir -p "$(dirname "$1")"
  printf '#!/bin/bash\necho "%s $(pwd -P)" >> "%s/calls.log"\necho "%s lint output"\nexit %s\n' "$2" "$TMP" "$2" "$3" > "$1"
  chmod +x "$1"
}
printf 'EDIT_CHECK=on\nLINT_TOOL=biome\n' > "$TMP/.claude/.sdlc-config"
fake_linter "$TMP/globalbin/biome" global 1
PATH="$TMP/globalbin:/usr/bin:/bin"

# Case 4: project-local linter (nearest node_modules/.bin) wins over PATH, runs from its package dir
fake_linter "$TMP/apps/web/node_modules/.bin/biome" local-web 0
mkdir -p "$TMP/apps/web/src"; echo "const x=1" > "$TMP/apps/web/src/x.ts"
: > "$TMP/calls.log"
[ "$(run "$TMP/apps/web/src/x.ts")" = "0" ] || { echo "FAIL c4 exit"; fail=1; }
grep -q "^local-web $(cd "$TMP/apps/web" && pwd -P)$" "$TMP/calls.log" || { echo "FAIL c4 local not used from package dir"; fail=1; }
! grep -q '^global' "$TMP/calls.log" || { echo "FAIL c4 global used"; fail=1; }

# Case 5: failing local linter -> exit 2 with its output fed back
fake_linter "$TMP/apps/server/node_modules/.bin/biome" local-server 1
mkdir -p "$TMP/apps/server/src"; echo "const y=1" > "$TMP/apps/server/src/y.ts"
[ "$(run "$TMP/apps/server/src/y.ts")" = "2" ] || { echo "FAIL c5 exit"; fail=1; }

# Case 6: no local linter anywhere up to the project root -> falls back to PATH
fake_linter "$TMP/globalbin/biome" global 0
mkdir -p "$TMP/packages/shared/src"; echo "const z=1" > "$TMP/packages/shared/src/z.ts"
: > "$TMP/calls.log"
[ "$(run "$TMP/packages/shared/src/z.ts")" = "0" ] || { echo "FAIL c6 exit"; fail=1; }
grep -q '^global' "$TMP/calls.log" || { echo "FAIL c6 global not used"; fail=1; }

[ "$fail" = "0" ] && echo PASS || { echo "SOME FAILED"; exit 1; }
