#!/bin/bash
# 打包结构：角色子 agent 随核心 skill 分发；插件 agents/ 仍可用；核心目录内无测试。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$HERE/.." && pwd)"; SKILL_DIR="$REPO_DIR/sdlc-workflow"
fail=0
for f in sdlc-backend-dev.md sdlc-frontend-dev.md sdlc-test-dev.md; do
  [ -f "$SKILL_DIR/agents/$f" ] && [ ! -L "$SKILL_DIR/agents/$f" ] || { echo "FAIL: 核心缺少实体 agents/$f"; fail=1; }
  [ -L "$REPO_DIR/agents/$f" ] || { echo "FAIL: 仓库根 agents/$f 应为软链接"; fail=1; }
  [ "$(readlink "$REPO_DIR/agents/$f")" = "../sdlc-workflow/agents/$f" ] || { echo "FAIL: agents/$f 链接目标错误"; fail=1; }
  grep -q '^name:' "$REPO_DIR/agents/$f" 2>/dev/null || { echo "FAIL: agents/$f 不可读"; fail=1; }
done
found="$(find "$SKILL_DIR" \( -name '__tests__' -o -name 'tests' \) -print)"
[ -z "$found" ] || { echo "FAIL: 核心目录内有测试目录: $found"; fail=1; }
[ "$(readlink "$REPO_DIR/skills/sdlc-workflow")" = "../sdlc-workflow" ] || { echo "FAIL: skills/sdlc-workflow 链接被改"; fail=1; }
[ "$fail" = "0" ] && echo PASS || exit 1
