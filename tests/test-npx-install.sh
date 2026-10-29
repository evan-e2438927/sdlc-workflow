#!/bin/bash
# 端到端：npx skills@1.7.4 从本仓库安装到临时项目，再用装好的核心 init。
# 无 npx 或 SDLC_SKIP_NPX=1 时跳过。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$HERE/.." && pwd)"
export DO_NOT_TRACK=1
SKILLS="skills@1.7.4"
if [ "${SDLC_SKIP_NPX:-0}" = 1 ] || ! command -v npx >/dev/null 2>&1; then echo "SKIP: npx 不可用"; exit 0; fi
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0
ck() { [ "$1" = "$2" ] || { echo "FAIL $3（期望 $2，实际 $1）"; fail=1; }; }
NAMES="sdlc-accept sdlc-apply sdlc-doit sdlc-init sdlc-mini sdlc-pr sdlc-proposal sdlc-qa sdlc-review sdlc-update sdlc-workflow sdlc-worktree"

# N1：--list 列出 12 个 skill
npx -y "$SKILLS" add "$REPO_DIR" --list >"$TMP/list" 2>&1; ck "$?" 0 "N1 --list 退出码"
n=0; for s in $NAMES; do grep -qE "(^|[^a-z-])$s([^a-z-]|$)" "$TMP/list" && n=$((n + 1)); done
ck "$n" 12 "N1 --list 识别出的 skill 数"

# N2：项目级安装
P="$TMP/proj"; mkdir -p "$P"; git -C "$P" init -q
(cd "$P" && npx -y "$SKILLS" add "$REPO_DIR" --skill '*' -a claude-code -a codex -y) >"$TMP/add" 2>&1; ck "$?" 0 "N2 add 退出码"
ck "$(find "$P/.agents/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" 12 "N2 .agents/skills 目录数"
for s in $NAMES; do
  [ -L "$P/.claude/skills/$s" ] && [ "$(readlink "$P/.claude/skills/$s")" = "../../.agents/skills/$s" ] \
    || { echo "FAIL N2 .claude/skills/$s 应为指向 ../../.agents/skills/$s 的软链接"; fail=1; }
done
[ -f "$P/skills-lock.json" ] || { echo "FAIL N2 缺少 skills-lock.json"; fail=1; }
found="$(find "$P/.agents/skills" \( -name '__tests__' -o -name tests -o -name 'test-*.sh' \) -print)"
[ -z "$found" ] || { echo "FAIL N2 装出来的文件中有测试: $found"; fail=1; }

# N3：用装好的核心 init
CORE="$P/.agents/skills/sdlc-workflow"
bash "$CORE/scripts/init-project.sh" "$P" >"$TMP/init" 2>&1; ck "$?" 0 "N3 init 退出码"
for f in AGENTS.md config.json; do [ -f "$P/.agents/$f" ] || { echo "FAIL N3 缺少 .agents/$f"; fail=1; }; done
for f in AGENTS.md CLAUDE.md; do
  [ -L "$P/$f" ] && [ "$(readlink "$P/$f")" = ".agents/AGENTS.md" ] || { echo "FAIL N3 根 $f 应为指向 .agents/AGENTS.md 的软链接"; fail=1; }
done
for f in .claude/settings.json .mcp.json .codex/config.toml .codex/hooks.json; do
  [ -f "$P/$f" ] || { echo "FAIL N3 缺少 $f"; fail=1; }
  git -C "$P" check-ignore -q "$f" || { echo "FAIL N3 $f 应被 gitignore"; fail=1; }
done
for f in AGENTS.md CLAUDE.md $(cd "$P" && ls -d .claude/skills/*); do
  git -C "$P" check-ignore -q "$f" && { echo "FAIL N3 $f 不应被 gitignore"; fail=1; }
done
bash "$CORE/scripts/sdlc-sync-agents.sh" --check "$P" >"$TMP/chk" 2>&1; ck "$?" 0 "N3 --check"
snap() { (cd "$P" && find . -path ./.git -prune -o \( -type f -o -type l \) -print | sort | while IFS= read -r f; do
  if [ -L "$f" ]; then echo "$f -> $(readlink "$f")"; else echo "$f $(cksum < "$f")"; fi; done); }
before="$(snap)"
bash "$CORE/scripts/sdlc-sync-agents.sh" "$P" >"$TMP/s1" 2>&1
bash "$CORE/scripts/sdlc-sync-agents.sh" "$P" >"$TMP/s2" 2>&1
ck "$(snap)" "$before" "N3 连续同步两次无变化"

# N4：角色子 agent 软链接有效
for r in backend frontend test; do
  f="$P/.claude/agents/sdlc-$r-dev.md"
  [ -L "$f" ] && grep -q "^name: sdlc-$r-dev" "$f" 2>/dev/null || { echo "FAIL N4 $f 应为有效软链接"; fail=1; }
done

# N5：插件安装方式的 agents/ 不受影响
for r in backend frontend test; do
  grep -q "^name: sdlc-$r-dev" "$REPO_DIR/agents/sdlc-$r-dev.md" || { echo "FAIL N5 仓库 agents/sdlc-$r-dev.md 不可读"; fail=1; }
done

[ "$fail" = "0" ] && echo PASS || exit 1
