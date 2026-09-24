#!/bin/bash
# 双模式（单/多 agent）相关 markdown 规范的结构断言。各任务在 "# ── END ──" 前追加自己的断言段。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/../.." && pwd)"
REPO_DIR="$(cd "$SKILL_DIR/.." && pwd)"
R="$SKILL_DIR/references"
fail=0
has()    { grep -qF -- "$2" "$1" 2>/dev/null || { echo "FAIL: $1 缺少: $2"; fail=1; }; }
lacks()  { ! grep -qF -- "$2" "$1" 2>/dev/null || { echo "FAIL: $1 不应包含: $2"; fail=1; }; }
exists() { [ -f "$1" ] || { echo "FAIL: 缺少文件 $1"; fail=1; }; }

# ── Task 2: Track 统一 + Gate 1 名单 ──
has   "$R/05-design-reviewer.md" '["frontend","backend","shared","infra","unit-test","qa"]'
has   "$R/05-design-reviewer.md" '"unit-test": ["tests/unit/"]'
has   "$R/05-design-reviewer.md" '["tests/e2e/"]'
has   "$R/05-design-reviewer.md" '"packages/contracts/"'
lacks "$R/05-design-reviewer.md" 'track == "test"'
lacks "$R/05-design-reviewer.md" '（frontend / backend / shared / infra / test）'
has   "$R/04-task-generator.md"  '`packages/auth/**`, `packages/contracts/**`'
has   "$SKILL_DIR/SKILL.md"      'track: frontend|backend|shared|infra|unit-test|qa'

# ── Task 3: 接口契约 ──
has   "$R/03-design-generator.md" '### 1.6 判定契约形态'
has   "$R/03-design-generator.md" '## 3. 接口契约'
has   "$R/03-design-generator.md" '- **契约形态**: table | ts-types | openapi | none'
lacks "$R/03-design-generator.md" '## 3. API 接口设计'
has   "$R/03-design-generator.md" '### 5.3 新增依赖'
lacks "$R/03-design-generator.md" '### 5.3 依赖管理'
has   "$R/04-task-generator.md"   '不得仅为获知接口形状而依赖 backend 任务'
has   "$R/04-task-generator.md"   '**角色并行提示**'
lacks "$R/04-task-generator.md"   'Agent Team 并行提示'
has   "$R/05-design-reviewer.md"  '### 2.3 接口契约检查规则（Gate 1 必做）'
has   "$R/05-design-reviewer.md"  '10) 接口契约:'
n=$(grep -c '10) 接口契约' "$R/05-design-reviewer.md"); [ "$n" = "3" ] || { echo "FAIL: 05 item 10 出现 $n 次，应为 3"; fail=1; }

# ── Task 4: 角色说明 + 子 agent 入口 ──
exists "$R/roles/track-report.md"
has    "$R/roles/track-report.md" '- 状态: done | partial | blocked'
for role in backend frontend test; do
  f="$R/roles/$role.md"
  exists "$f"
  for sec in '## 职责' '## 可改路径白名单' '## 必读' '## 禁止' '## 遇到阻塞'; do has "$f" "$sec"; done
  has "$f" "\$ITER_DIR/tracks/$role.md"
  a="$REPO_DIR/agents/sdlc-$role-dev.md"
  exists "$a"
  has "$a" "name: sdlc-$role-dev"
  has "$a" 'blocked: 缺少角色说明'
done
has "$R/roles/test.md" '只新增测试'

# ── Task 5: apply 编排 ──
F="$R/flow-apply.md"
for s in '## 执行模式选择' '## 工作包与派活' '## 汇总：越界检测与公共文件请求' '## blocked 处理' '## 断点续跑'; do has "$F" "$s"; done
has   "$F" '⑥.1 打地基'
has   "$F" '⑦ 查漏'
has   "$F" '"agent_mode": "multi"'
has   "$F" '--agents single'
lacks "$F" '只实现 frontend / backend / unit-test 三类 track'
lacks "$F" 'Agent Team'
S="$SKILL_DIR/SKILL.md"
has   "$S" '#### ⑥ 开发（单 / 多 agent 双模式）'
has   "$S" '#### ⑦ 查漏（test 角色）'
has   "$S" '[--agents single|multi]'
has   "$S" '1. **执行模式**'
has   "$S" '18. **角色分工**'
has   "$S" '##### ⑥.5 勾选属实自检'
lacks "$S" 'spawn_sub_agent'
lacks "$S" 'Agent Team'
lacks "$S" '1. **单 Agent 模式**'
lacks "$S" '步骤⑥ Claude Code 开发'
lacks "$F" 'Claude Code 开发'

# ── Task 6: 测试角色 + skill 入口 + mini ──
has   "$R/07-test-generator.md" '# 步骤 ⑦: Test Generator — 查漏补缺（test 角色）'
has   "$R/07-test-generator.md" '执行者：test 角色'
has   "$R/07-test-generator.md" '$ITER_DIR/tracks/test.md'
has   "$REPO_DIR/skills/sdlc-apply/SKILL.md" '--agents single|multi'
has   "$REPO_DIR/skills/sdlc-apply/SKILL.md" '⑥.1 打地基'
lacks "$REPO_DIR/skills/sdlc-apply/SKILL.md" 'Agent Team'
has   "$REPO_DIR/skills/sdlc-doit/SKILL.md"  '--agents single|multi'
has   "$R/flow-mini.md" '执行模式固定 single'

# ── Task 7: Gate 2 ──
has "$R/08-code-reviewer.md" '8) 接口契约一致性'
has "$R/08-code-reviewer.md" '9) 越界：'
has "$R/08-code-reviewer.md" '10) 越界：'
has "$R/08-code-reviewer.md" '| 接口契约 |'
has "$R/08-code-reviewer.md" '=== design.md 接口契约 ==='
# ── END ──
[ "$fail" = "0" ] && echo PASS || exit 1
