#!/bin/bash
set -euo pipefail

PROJECT_ROOT="."
REVIEW_MAX_ROUNDS_VALUE=""
GIT_BRANCH_PREFIX_VALUE=""
TEST_BOOTSTRAP_POLICY_VALUE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --project-root)
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --review-rounds)
      REVIEW_MAX_ROUNDS_VALUE="$2"
      shift 2
      ;;
    --branch-prefix)
      GIT_BRANCH_PREFIX_VALUE="$2"
      shift 2
      ;;
    --test-bootstrap-policy)
      TEST_BOOTSTRAP_POLICY_VALUE="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

CONFIG_FILE="$PROJECT_ROOT/.claude/.sdlc-config"
CONFIG_TEMPLATE="$(cd "$(dirname "$0")/.." && pwd)/templates/sdlc-config.tpl"

if [ ! -f "$CONFIG_FILE" ]; then
  mkdir -p "$(dirname "$CONFIG_FILE")"
  if [ -f "$CONFIG_TEMPLATE" ]; then
    cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"
  else
    touch "$CONFIG_FILE"
  fi
fi

sync_config_var() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp
  tmp="$(mktemp)"

  if grep -q "^${key}=" "$file" 2>/dev/null; then
    awk -v key="$key" -v value="$value" '
      BEGIN { replaced = 0 }
      $0 ~ ("^" key "=") {
        print key "=" value
        replaced = 1
        next
      }
      { print }
      END {
        if (!replaced) {
          print key "=" value
        }
      }
    ' "$file" > "$tmp"
  else
    cat "$file" > "$tmp" 2>/dev/null || true
    printf '%s=%s\n' "$key" "$value" >> "$tmp"
  fi

  mv "$tmp" "$file"
}

if [ -n "$REVIEW_MAX_ROUNDS_VALUE" ]; then
  sync_config_var "$CONFIG_FILE" "REVIEW_MAX_ROUNDS" "$REVIEW_MAX_ROUNDS_VALUE"
fi

if [ -n "$GIT_BRANCH_PREFIX_VALUE" ]; then
  sync_config_var "$CONFIG_FILE" "GIT_BRANCH_PREFIX" "$GIT_BRANCH_PREFIX_VALUE"
fi

if [ -n "$TEST_BOOTSTRAP_POLICY_VALUE" ]; then
  sync_config_var "$CONFIG_FILE" "TEST_BOOTSTRAP_POLICY" "$TEST_BOOTSTRAP_POLICY_VALUE"
fi

echo "Updated workflow config in $CONFIG_FILE"
