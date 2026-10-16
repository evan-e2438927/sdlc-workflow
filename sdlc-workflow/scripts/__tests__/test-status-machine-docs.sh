#!/bin/bash
# 状态机 / 修复轮数 / QA 回流相关 markdown 规范的结构断言。各任务在 "# ── END ──" 前追加自己的断言段。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/../.." && pwd)"
REPO_DIR="$(cd "$SKILL_DIR/.." && pwd)"
R="$SKILL_DIR/references"
fail=0
has()    { grep -qF -- "$2" "$1" 2>/dev/null || { echo "FAIL: $1 缺少: $2"; fail=1; }; }
lacks()  { ! grep -qF -- "$2" "$1" 2>/dev/null || { echo "FAIL: $1 不应包含: $2"; fail=1; }; }
exists() { [ -f "$1" ] || { echo "FAIL: 缺少文件 $1"; fail=1; }; }

# ── Task 3: SKILL.md ──
has   "$SKILL_DIR/SKILL.md" 'bins: ["codex", "gh", "jq"]'
has   "$SKILL_DIR/SKILL.md" '## 迭代状态（phase）'
has   "$SKILL_DIR/SKILL.md" 'phase 取值：pending_review | approved | applied | qa_failed | qa_passed | accepted | pr_created | rejected'
has   "$SKILL_DIR/SKILL.md" '${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/scripts/sdlc-status.sh'
has   "$SKILL_DIR/SKILL.md" '### 修复轮数（唯一定义）'
has   "$SKILL_DIR/SKILL.md" '已修轮数 == N → 停下，phase 不变，输出失败项，转人工'
has   "$SKILL_DIR/SKILL.md" '"$SDLC_STATUS" transition "$ITER_DIR" pending_review --by doit --flags'
has   "$SKILL_DIR/SKILL.md" 'mode=doit'
lacks "$SKILL_DIR/SKILL.md" '不写 status.json，直接继续步骤 ⑥'
lacks "$SKILL_DIR/SKILL.md" 'IF round < REVIEW_MAX_ROUNDS'
lacks "$SKILL_DIR/SKILL.md" 'WRITE "$ITER_DIR/status.json"'
lacks "$SKILL_DIR/SKILL.md" 'UPDATE status.json: phase='

# ── END ──
[ $fail -eq 0 ] && echo PASS; exit $fail
