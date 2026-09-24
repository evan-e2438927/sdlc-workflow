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
has   "$R/track-paths.md" '"unit-test": ["tests/unit/"]'
has   "$R/track-paths.md" '"qa":        ["tests/e2e/"]'
has   "$R/track-paths.md" '"packages/contracts/"'
lacks "$R/05-design-reviewer.md" 'track == "test"'
lacks "$R/05-design-reviewer.md" '（frontend / backend / shared / infra / test）'
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

# ── Task 8: 概览与 README ──
P="$R/pipeline-overview.md"
has   "$P" 'A_S6_FOUND["⑥.1 主 agent 打地基'
has   "$P" '| **Parallelization** | 步骤⑥.2 backend / frontend 角色并行开发（多 agent 模式）|'
lacks "$P" 'Agent Team'
W="$REPO_DIR/docs/workflow-overview.md"
has   "$W" 'AGENT_MODE'
lacks "$W" 'Agent Team'
has   "$REPO_DIR/README.zh-CN.md" '## 单 / 多 agent 模式'
has   "$REPO_DIR/README.zh-CN.md" '`[--review] [--agents single\|multi] [迭代目录]`'
has   "$REPO_DIR/README.md"       '## Single- / multi-agent mode'
has   "$REPO_DIR/README.md"       '`[--review] [--agents single\|multi] [iter dir]`'
# 全仓不再出现旧的 Agent Team 说法（spec/plan 目录除外）
for f in "$SKILL_DIR/SKILL.md" "$R"/*.md "$REPO_DIR"/skills/sdlc-*/SKILL.md "$W" "$REPO_DIR/README.md" "$REPO_DIR/README.zh-CN.md"; do
  [ -L "$f" ] && continue
  lacks "$f" 'Agent Team'
done

# ── Final fix wave ──
# F1: 命令模板与 §4 loop 对齐 —— 越界/契约块出现次数
n=$(grep -c '越界：' "$R/08-code-reviewer.md"); [ "$n" = "3" ] || { echo "FAIL: 08 越界： 出现 $n 次，应为 3"; fail=1; }
n=$(grep -c '=== design.md 接口契约 ===' "$R/08-code-reviewer.md"); [ "$n" = "2" ] || { echo "FAIL: 08 === design.md 接口契约 === 出现 $n 次，应为 2"; fail=1; }

# F2: Gate 2 prompt 不再依赖 references/roles/*.md，改内联白名单 + tracks 汇报 + 未跟踪新文件
lacks "$R/08-code-reviewer.md" '越界：各 Track 的改动是否落在对应角色白名单内（references/roles/*.md）'
has   "$R/08-code-reviewer.md" '$ITER_DIR/tracks/*.md 是否如实列出修改文件'
has   "$R/08-code-reviewer.md" 'tests/unit/packages/{api,db}/**'
n=$(grep -c '=== 未跟踪的新文件 ===' "$R/08-code-reviewer.md"); [ "$n" = "3" ] || { echo "FAIL: 08 === 未跟踪的新文件 === 出现 $n 次，应为 3"; fail=1; }
n=$(grep -c '=== tracks 汇报 ===' "$R/08-code-reviewer.md"); [ "$n" = "3" ] || { echo "FAIL: 08 === tracks 汇报 === 出现 $n 次，应为 3"; fail=1; }

# F3: 测试文件归属路径在 04/05/roles/tpl 间同步
has "$R/04-task-generator.md" 'references/track-paths.md'
has "$R/05-design-reviewer.md" 'TRACK_PATH_RULES = references/track-paths.md 的 tracks 字段'
has "$R/roles/backend.md" 'tests/unit/packages/api/**'
has "$R/roles/backend.md" 'tests/unit/packages/db/**'
has "$R/roles/frontend.md" 'tests/unit/packages/ui/**'
has "$SKILL_DIR/templates/workflow-rules.md.tpl" 'packages/contracts/*'

# F4: 历史迭代兼容（旧标题 fallback）
has "$F" 'API 接口设计'
has "$R/08-code-reviewer.md" "API 接口设计/,/^## 4"
has "$R/05-design-reviewer.md" '历史迭代兼容'

# F5: PRE_CHANGED / CHANGED 同口径，排除迭代目录自身，无提交仓库兜底
has "$F" '.pre-changed'
has "$F" 'CHANGED = SNAPSHOT() − PRE_CHANGED − "$ITER_DIR/**"'
has "$F" 'SNAPSHOT() = (git ls-files) ∪ (git ls-files --others --exclude-standard)'

# F6: 修复回合
has "$F" '## 修复回合'
has "$S" '修复回合，见 flow-apply.md'

# F7: test-generator 只新增 + 失败用例处理
has   "$R/07-test-generator.md" '保留失败用例，在 tracks/test.md「与设计的偏差」写明，状态记 partial'
has   "$R/07-test-generator.md" '[ -e "$TEST_FILE" ] || cat > "$TEST_FILE"'
lacks "$R/07-test-generator.md" '生成 TODO 标记，待 Claude Code 实现后补充'

# M1: 插件命名空间派发类型
has "$F" 'sdlc-workflow:sdlc-backend-dev'

# M2 → 实测修订：hook 对子 agent 编辑同样触发，汇总阶段不再重复跑 LINT_TOOL
lacks "$F" 'multi 模式下主 agent 在此对 owner 为子 agent 的代码文件统一跑一次'
lacks "$F" '若 PostToolUse 编辑检查 hook 对子 agent 的编辑不生效'
has   "$F" '子 agent 的 Edit/Write 同样触发 PostToolUse 编辑检查 hook'

# M3: mini 检查置于执行模式解析器最前
has   "$F" 'mini: 固定 single'
lacks "$F" 'auto: mini'

# M4: foundation 的 skipped 判定
has "$F" '`foundation` 例外'

# M5: ⑦.1 重跑勾选自检 + 显式 pipeline_stage
has "$F" '对 unit-test 任务重跑一次 ⑥.5 式勾选属实自检'

# M6: 角色禁止项补充
has "$R/roles/backend.md"  '不在全仓运行带 `--fix`'
has "$R/roles/frontend.md" '不在全仓运行带 `--fix`'
has "$R/roles/test.md"     '不在全仓运行带 `--fix`'

# M7: 派活 prompt 的 CTX.skills 索引须含 SKILL.md 路径
has "$F" 'CTX.skills 索引格式要求'

# M8: workflow-overview.md 对齐新版 ⑥/⑦ 流程
has "$W" '⑥ 开发（打地基 → 前后端角色 → 汇总）'

# M9: sdlc-review SKILL.md 摘要补充 Gate 1/2 检查项
has "$REPO_DIR/skills/sdlc-review/SKILL.md" 'Track 一致性'
has "$REPO_DIR/skills/sdlc-review/SKILL.md" '契约一致性'
has "$REPO_DIR/skills/sdlc-review/SKILL.md" '越界'
# ── 实测修订：契约形态沿用既有惯例 + hook 本地 linter ──
has   "$R/03-design-generator.md" '沿用既有惯例'
has   "$R/05-design-reviewer.md"  '登记了沿用既有惯例的理由'
lacks "$SKILL_DIR/templates/sdlc-config.tpl" '仅装在 node_modules/.bin 的项目本地 linter 会被跳过'
has   "$SKILL_DIR/templates/sdlc-config.tpl" '优先使用离被改文件最近的 node_modules/.bin'

# ── END ──
[ "$fail" = "0" ] && echo PASS || exit 1
