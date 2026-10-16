#!/bin/bash
# 状态机 / 修复轮数 / QA 回流相关 markdown 规范的结构断言。各任务在文件末尾 END 标记前追加自己的断言段。
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

# ── Task 4: proposal / mini / doit ──
has   "$R/flow-proposal.md" '"$SDLC_STATUS" transition "$ITER_DIR" pending_review --by proposal'
has   "$R/flow-proposal.md" '## 审核期间的修改（对话）'
has   "$R/flow-proposal.md" '三份文档联动'
lacks "$R/flow-proposal.md" '| status.json 写入失败 | LOG warning，不阻塞'
has   "$R/flow-mini.md"     '"$SDLC_STATUS" transition "$ITER_DIR" pending_review --by mini --flags'
lacks "$R/flow-mini.md"     'mini-incomplete'
lacks "$R/micro-change-mode.md" '最终通过结论仍然必须基于 **Playwright MCP** 的真实浏览器验收'
has   "$REPO_DIR/skills/sdlc-doit/SKILL.md" '--by doit --flags'
has   "$REPO_DIR/skills/sdlc-doit/SKILL.md" '按 status.json 的 flags 续跑'
lacks "$REPO_DIR/skills/sdlc-doit/SKILL.md" '不写 `pending_review` 暂停点'

# ── Task 5: 修复轮数 ──
for f in 05-design-reviewer.md 08-code-reviewer.md 09-test-pipeline.md; do
  has   "$R/$f" '见 SKILL.md「修复轮数（唯一定义）」'
  lacks "$R/$f" 'while [ $round -le'
  lacks "$R/$f" '[ $round -eq $'
  lacks "$R/$f" '[ $round -lt $'
done
has   "$SKILL_DIR/templates/sdlc-config.tpl" '最多自动修复轮数（0–10）'
lacks "$SKILL_DIR/templates/sdlc-config.tpl" '正整数(1-10)'
has   "$SKILL_DIR/templates/workflow-rules.md.tpl" '最多自动修复 REVIEW_MAX_ROUNDS 轮'
lacks "$R/09-test-pipeline.md" 'context_usage > 70%'

# ── Task 6: QA 回流 ──
has   "$R/flow-qa.md"    'qa-failures.md'
has   "$R/flow-qa.md"    '"$SDLC_STATUS" transition "$ITER_DIR" qa_failed --by qa'
has   "$R/flow-qa.md"    '"$SDLC_STATUS" find-latest applied'
has   "$R/flow-qa.md"    '执行全部场景'
lacks "$R/flow-qa.md"    '.qa_failed_at=now'
has   "$R/flow-apply.md" '## 修复模式（phase = qa_failed）'
has   "$R/flow-apply.md" '"$SDLC_STATUS" find-latest pending_review approved qa_failed'
has   "$R/flow-apply.md" '"$SDLC_STATUS" transition "$ITER_DIR" applied --by apply --note qa-fix'
has   "$R/flow-apply.md" '仅 e2e 可验'
lacks "$R/flow-apply.md" 'find_latest_proposal()'
lacks "$R/flow-apply.md" 'jq '"'"'.phase = "approved"'
has   "$REPO_DIR/skills/sdlc-apply/SKILL.md" 'qa_failed'
has   "$REPO_DIR/skills/sdlc-qa/SKILL.md"    'qa_failed'

# ── Task 7: accept / pr ──
has   "$R/flow-accept.md"   '"$SDLC_STATUS" find-latest qa_passed applied'
has   "$R/flow-accept.md"   '"$SDLC_STATUS" transition "$ITER_DIR" accepted --by accept'
has   "$R/flow-accept.md"   '上次 QA 失败、修复后尚未重新验收，确定跳过 qa 提交吗？'
lacks "$R/flow-accept.md"   'find_latest_acceptable()'
lacks "$R/flow-accept.md"   '.accepted_at = now'
has   "$R/12-pr-creator.md" '"$SDLC_STATUS" find-latest accepted'
has   "$R/12-pr-creator.md" '"$SDLC_STATUS" transition "$ITER_DIR" pr_created --by pr'
lacks "$R/12-pr-creator.md" '.pr_created_at = now'

# ── Task 8: 概览 / worktree ──
has   "$R/pipeline-overview.md" 'qa_failed'
has   "$R/pipeline-overview.md" '修复模式'
has   "$R/pipeline-overview.md" '| AGENT_MODE |'
has   "$SKILL_DIR/scripts/sdlc-worktree.sh" "'qa_failed':"
has   "$SKILL_DIR/scripts/sdlc-worktree.sh" "'pr_created':"

# ── END ──
[ $fail -eq 0 ] && echo PASS; exit $fail
