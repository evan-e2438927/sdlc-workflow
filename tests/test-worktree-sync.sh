#!/bin/bash
# worktree create：复制 .agents/.sdlc-config*、端口覆写，并在新 worktree 中执行同步。
# 另含 update-workflow-config.sh 写 .agents/.sdlc-config。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$HERE/.." && pwd)"; SKILL_DIR="$REPO_DIR/sdlc-workflow"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0
ck() { [ "$1" = "$2" ] || { echo "FAIL $3（期望 $2，实际 $1）"; fail=1; }; }

P="$TMP/main"; mkdir -p "$P"; git -C "$P" init -q -b main
bash "$SKILL_DIR/scripts/init-project.sh" "$P" >/dev/null 2>&1 || { echo "FAIL init"; exit 1; }
git -C "$P" add -A && git -C "$P" -c user.email=t@t -c user.name=t commit -qm init

(cd "$P" && PROJECT_ROOT="$P" bash "$SKILL_DIR/scripts/sdlc-worktree.sh" create demo feature) >"$TMP/out" 2>&1
ck "$?" 0 "W0 worktree create"
WT="$(ls -d "$TMP"/wt-001-demo-feature 2>/dev/null)"
[ -n "$WT" ] || { echo "FAIL W0 未创建 worktree"; cat "$TMP/out"; exit 1; }
grep -qx 'PORT=3001' "$WT/.agents/.sdlc-config" || { echo "FAIL W1 端口未写入 .agents/.sdlc-config"; fail=1; }
grep -qx 'API_PORT=4001' "$WT/.agents/.sdlc-config" || { echo "FAIL W1 API 端口未写入"; fail=1; }
[ -e "$WT/.claude/.sdlc-config" ] && { echo "FAIL W1 不应再写 .claude/.sdlc-config"; fail=1; }
[ -f "$WT/.claude/settings.json" ] && [ -f "$WT/.codex/hooks.json" ] || { echo "FAIL W2 新 worktree 未生成平台文件"; fail=1; }
bash "$SKILL_DIR/scripts/sdlc-sync-agents.sh" --check "$WT" >"$TMP/chk" 2>&1; ck "$?" 0 "W3 新 worktree 中 --check"

bash "$SKILL_DIR/scripts/update-workflow-config.sh" --project-root "$P" --review-rounds 3 >/dev/null 2>&1
grep -qx 'REVIEW_MAX_ROUNDS=3' "$P/.agents/.sdlc-config" || { echo "FAIL W4 update-workflow-config 应写 .agents/.sdlc-config"; fail=1; }
[ -e "$P/.claude/.sdlc-config" ] && { echo "FAIL W4 不应写 .claude/.sdlc-config"; fail=1; }

git -C "$P" worktree remove --force "$WT" >/dev/null 2>&1
[ "$fail" = "0" ] && echo PASS || exit 1
