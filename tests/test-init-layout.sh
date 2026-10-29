#!/bin/bash
# init 生成 .agents/ 新布局，平台文件由同步脚本生成。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$HERE/.." && pwd)"; SKILL_DIR="$REPO_DIR/sdlc-workflow"
INIT="${SDLC_INIT:-$SKILL_DIR/scripts/init-project.sh}"
SYNC="$(dirname "$INIT")/sdlc-sync-agents.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0
ck() { [ "$1" = "$2" ] || { echo "FAIL $3（期望 $2，实际 $1）"; fail=1; }; }
link_is() { [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ] || { echo "FAIL $3：$1 应为指向 $2 的软链接"; fail=1; }; }
snapshot() { (cd "$P" && find . -path ./.git -prune -o \( -type f -o -type l \) -print | sort | while IFS= read -r f; do
  if [ -L "$f" ]; then echo "$f -> $(readlink "$f")"; else echo "$f $(cksum < "$f")"; fi; done); }

P="$TMP/fresh"; mkdir -p "$P"; git -C "$P" init -q
bash "$INIT" "$P" >"$TMP/out" 2>&1; ck "$?" 0 "I0 init 退出码"
for f in AGENTS.md ARCHITECTURE.md SECURITY.md CODING_GUIDELINES.md rules/workflow-rules.md config.json .sdlc-config \
         hooks/sdlc-hook-lib.sh hooks/sdlc-pre-edit-guard.sh hooks/sdlc-post-edit-check.sh; do
  [ -f "$P/.agents/$f" ] || { echo "FAIL I1 缺少 .agents/$f"; fail=1; }
done
link_is "$P/AGENTS.md" ".agents/AGENTS.md" "I2 根 AGENTS.md"
link_is "$P/CLAUDE.md" ".agents/AGENTS.md" "I2 根 CLAUDE.md"
for f in .claude/settings.json .mcp.json .codex/config.toml .codex/hooks.json .cursor/mcp.json; do
  [ -f "$P/$f" ] || { echo "FAIL I3 缺少 $f"; fail=1; }
  git -C "$P" check-ignore -q "$f" || { echo "FAIL I3 $f 应被 gitignore"; fail=1; }
done
for f in AGENTS.md CLAUDE.md .agents/AGENTS.md .agents/config.json .agents/hooks/sdlc-pre-edit-guard.sh; do
  git -C "$P" check-ignore -q "$f" && { echo "FAIL I3 $f 不应被 gitignore"; fail=1; }
done
git -C "$P" check-ignore -q .agents/.sdlc-config || { echo "FAIL I3 .agents/.sdlc-config 应被 gitignore"; fail=1; }
bash "$SYNC" --check "$P" >"$TMP/out" 2>&1; ck "$?" 0 "I4 --check"
before="$(snapshot)"
bash "$SYNC" "$P" >"$TMP/out" 2>&1; ck "$?" 0 "I5 再次同步"
ck "$(snapshot)" "$before" "I5 第二次同步无变化"
bash "$INIT" "$P" >"$TMP/out" 2>&1; ck "$?" 0 "I5b 重复 init"
ck "$(snapshot)" "$before" "I5b 重复 init 无变化"
# I8：规则文件不再引用旧的 .claude/ 规则路径（.claude/skills、.claude/settings.json 等平台路径除外）
RX='\.claude/(CLAUDE|ARCHITECTURE|SECURITY|CODING_GUIDELINES|PROJECT_BASELINE|EXISTING_STRUCTURE|TEST_BASELINE)\.md|\.claude/(rules|hooks)/|\.claude/\.sdlc-'
for f in "$P"/.agents/*.md "$P"/.agents/rules/*.md "$P"/.agents/skills/README.md "$P"/.agents/.sdlc-config; do
  sed 's#~/\.claude/##g' "$f" | grep -En "$RX" && { echo "FAIL I8 $f 仍引用旧 .claude/ 规则路径"; fail=1; }
done
# I8b：--check-paths 可运行（模板里有 existing 项目才有的基线文件等条件性引用，只作提示，不要求 0）
bash "$SYNC" --check-paths "$P" >"$TMP/out" 2>&1; rc=$?; [ "$rc" = 0 ] || [ "$rc" = 1 ] || { echo "FAIL I8b --check-paths 出错（$rc）"; fail=1; }

# I6：existing 项目已有实体根 CLAUDE.md → 备份后并入，根变为软链接
P="$TMP/existing"; mkdir -p "$P/src"; git -C "$P" init -q
printf 'MY RULES\n' > "$P/CLAUDE.md"; printf '{"name":"x"}\n' > "$P/package.json"
bash "$INIT" "$P" >"$TMP/out" 2>&1; ck "$?" 0 "I6 init 退出码"
link_is "$P/CLAUDE.md" ".agents/AGENTS.md" "I6 根 CLAUDE.md 变为软链接"
grep -qx 'MY RULES' "$P/.agents/AGENTS.md" || { echo "FAIL I6 原 CLAUDE.md 内容未并入"; fail=1; }
ls "$P"/.agents/.backup/*/CLAUDE.md >/dev/null 2>&1 || { echo "FAIL I6 原 CLAUDE.md 未备份"; fail=1; }
grep -q '/hooks' "$TMP/out" || { echo "FAIL I6 init 输出应提示 Codex /hooks 信任"; fail=1; }

# I7：旧布局 → 提示 update，不创建 .agents/
P="$TMP/legacy"; mkdir -p "$P/.claude"; printf '# old\n' > "$P/.claude/CLAUDE.md"
bash "$INIT" "$P" >"$TMP/out" 2>&1; ck "$?" 1 "I7 旧布局 init 退出码"
grep -q 'update' "$TMP/out" || { echo "FAIL I7 应提示执行 update"; fail=1; }
[ -e "$P/.agents" ] && { echo "FAIL I7 旧布局不应创建 .agents/"; fail=1; }

[ "$fail" = "0" ] && echo PASS || exit 1
