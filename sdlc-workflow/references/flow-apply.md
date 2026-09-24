# Apply — 需求开发命令

## 概述

`/sdlc-workflow apply <迭代目录>` 在 proposal 产物经人工审核后，
继续执行**开发 + 单元测试 + 静态检查**（步骤 ⑥-⑨）。

**apply 不更新文档、不提交、不推 PR**——这些属于 `accept` 验收流程；
浏览器功能验收（Playwright）属于 `qa` 命令。apply 只负责把代码写出来并通过
lint + unit 自检，产物停在 `phase == "applied"`。

## 入口

```
/sdlc-workflow apply <迭代目录>
```

参数为 proposal 生成的迭代目录路径：

```bash
# 示例
/sdlc-workflow apply docs/iterations/2026-04-13/001-user-login-feature/
/sdlc-workflow apply --agents single docs/iterations/2026-04-13/001-user-login-feature/   # 强制单 agent
/sdlc-workflow apply --agents multi  docs/iterations/2026-04-13/001-user-login-feature/   # 强制多 agent
```

若不指定路径，自动查找最近一个 `phase == "pending_review"` 或 `phase == "approved"` 的迭代目录。

## 前置检查

### 1. status.json 校验

```bash
STATUS_FILE="$ITER_DIR/status.json"

if [ ! -f "$STATUS_FILE" ]; then
  echo "❌ 未找到 status.json，请先运行 /sdlc-workflow proposal"
  exit 1
fi

PHASE=$(jq -r '.phase' "$STATUS_FILE")

case "$PHASE" in
  "pending_review")
    # 交互确认：用户直接 apply 视为审核通过
    echo "📋 该 proposal 尚处于 pending_review 状态"
    echo "   运行 apply 将视为审核通过并开始开发"
    # 更新状态为 approved
    jq '.phase = "approved" | .reviewed_at = now | .reviewer = "cli-apply"' \
      "$STATUS_FILE" > tmp.json && mv tmp.json "$STATUS_FILE"
    ;;
  "approved")
    echo "✅ Proposal 已通过审核，开始开发"
    ;;
  "applied")
    echo "⚠️ 该 proposal 已执行过 apply"
    echo "   如需重新执行，请手动将 status.json 中 phase 改为 approved"
    exit 1
    ;;
  "rejected")
    echo "❌ 该 proposal 已被拒绝"
    echo "   请修改后重新运行 /sdlc-workflow proposal"
    exit 1
    ;;
  *)
    echo "❌ 未知状态: $PHASE"
    exit 1
    ;;
esac
```

### 2. 产物完整性检查

```bash
REQUIRED_FILES=("requirements.md" "design.md" "tasks.md")
for f in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "$ITER_DIR/$f" ]; then
    echo "❌ 缺少必需文件: $f"
    exit 1
  fi
done
```

### 3. 初始化检查

```bash
if [ ! -f ".claude/CLAUDE.md" ] || [ ! -f ".claude/ARCHITECTURE.md" ]; then
  echo "❌ 项目未初始化，请先运行 /sdlc-workflow init"
  exit 1
fi
```

### 4. 统一上下文加载

apply 通常在**独立会话**里跑（与 proposal 分开），必须重新经统一入口加载上下文：

`LOAD_CONTEXT`（见 `references/context-loader.md`）——加载全局 + 项目 `.claude/` 规范
**及自定义 skill 索引 `CTX.skills`**（来源 `~/.claude/skills/` 与 `<project>/.claude/skills/`）。
不加载则 ⑥ 开发看不到用户扩展的 skills；Codex 无 harness 自动发现，尤其依赖此步。

## 执行步骤

```
读取 $ITER_DIR/status.json → 校验 phase
读取 $ITER_DIR/tasks.md → 获取任务列表

⑥ 开发（两种执行模式共用本流程，模式只决定"谁来执行"，见「执行模式选择」）
   ⑥.0 打包
        计算/复用 PRE_CHANGED 基线（首次进入本次 apply 的 ⑥.0 时计算并写入
          $ITER_DIR/tracks/.pre-changed；断点续跑复用同一份，见「汇总：越界检测与公共文件请求」）
        解析执行模式（见「执行模式选择」），写入 status.json
        历史迭代兼容：早于本次改动生成的 design.md 可能仍是旧标题「## 3. API 接口设计」/
          「### 5.3 依赖管理」——分别按新版「## 3. 接口契约」（契约形态 = table）/
          「### 5.3 新增依赖」等效处理，不因标题不同而跳过
        按 Track 生成工作包（WP）：
          WP = 角色说明全文（references/roles/<track>.md）+ 该 Track 任务（依赖顺序、目标文件、
               适用规范、AC）+ design.md「## 3. 接口契约」+ 规范上下文（LOAD_CONTEXT 摘录）
        所有角色在每个任务**执行前**，先读该任务的「适用规范」字段，对照命中的项目 skill
        （必要时才加载其正文；先 skill、后自造，见 context-loader.md「skills 优先级规则」）。
        规范检查是逐任务的，不是开发前一次性的——避免长会话注意力漂移。
   ⑥.1 打地基（主 agent 亲自执行，两种模式相同）
        · Track=infra、shared 的任务（含 ts-types 形态的「契约落地」任务）
        · 安装 design.md「### 5.3 新增依赖」中的依赖（唯一修改 package.json / lockfile 的时机）
        · 写 tracks/foundation.md；status.json: pipeline_stage=foundation，tracks.foundation=done
   ⑥.2 开发：backend WP、frontend WP
        single → 主 agent 依次扮演 backend、frontend 角色（同样遵守角色白名单与禁止项）
        multi  → 同时派发 sdlc-backend-dev、sdlc-frontend-dev 两个子 agent（见「工作包与派活」）
        每个角色写自己那部分单测，完成后写 tracks/<track>.md
        status.json: pipeline_stage=dev，tracks.backend / tracks.frontend 随进度更新
        （track: qa 的任务不在 apply 实现，留给 qa 命令）
   ⑥.3 汇总（主 agent）
        读 tracks/backend.md、tracks/frontend.md → 越界检测 → 处理公共文件请求 / blocked
        （见「汇总：越界检测与公共文件请求」「blocked 处理」）
        → 回写 tasks.md（只由主 agent 写）→ 勾选属实自检（SKILL.md ⑥.5）
        status.json: pipeline_stage=merge

⑦ 查漏（test 角色，⑥.3 完成后执行，不与开发并行）
   single → 主 agent 扮演 test 角色；multi → 派发 sdlc-test-dev 子 agent
   处理 Track=unit-test 任务；对照 AC 清单补 error / boundary / security 缺口
   生成 tests/reports/<slug>-coverage.md（规范见 07-test-generator.md）；写 tracks/test.md
   status.json: pipeline_stage=test-audit，tracks.test 随进度更新
⑦.1 汇总（主 agent）：读 tracks/test.md → 越界检测 → 回写 unit-test 任务
     → 对 unit-test 任务重跑一次 ⑥.5 式勾选属实自检 → status.json: pipeline_stage=merge（显式再写一次，标记本轮汇总完成）

[⑧ code-reviewer (Gate 2)   ← 仅 --review 模式]
   Codex CLI 审查代码（含契约一致性与越界检查）

⑨ test-pipeline
   lint → unit（两阶段，不含浏览器 E2E）

更新 status.json:
  phase: "applied"
  applied_at: <当前时间>
```

> ⑩ 浏览器功能验收 → `qa` 命令；⑪ docs-updater + ⑫ git-committer → `accept` 命令。

## 执行模式选择

```
MODE_REQ  = --agents 参数 ?? AGENT_MODE（.sdlc-config：项目 > 全局）?? "auto"
CAN_SPAWN = 当前会话提供子 agent 派发工具（Claude Code 有；Codex 无）
HAS_BE    = backend WP 非空；HAS_FE = frontend WP 非空
OVERLAP   = backend WP 与 frontend WP 的目标文件有交集（按 Track 路径规则本不应出现）

IF 当前为 mini:  # mini 固定 single，优先于 --agents / AGENT_MODE 的任何取值
  MODE="single"; REASON="mini: 固定 single"
ELIF MODE_REQ == "single":
  MODE="single"; REASON="指定 single"
ELIF MODE_REQ == "multi":
  IF NOT CAN_SPAWN:  MODE="single"; REASON="降级: 运行时不支持子 agent"
  ELIF OVERLAP:      MODE="single"; REASON="降级: 前后端目标文件有交集"
  ELSE:              MODE="multi";  REASON="指定 multi"
ELSE:  # auto
  IF NOT CAN_SPAWN:              MODE="single"; REASON="auto: 运行时不支持子 agent"
  ELIF NOT (HAS_BE AND HAS_FE):  MODE="single"; REASON="auto: 无可并行的开发角色"
  ELIF OVERLAP:                  MODE="single"; REASON="auto: 前后端目标文件有交集"
  ELSE:                          MODE="multi";  REASON="auto: backend+frontend 均有任务"

UPDATE status.json: agent_mode=MODE, agent_mode_reason=REASON
LOG "🤖 执行模式: $MODE（$REASON）"
```

> 降级不违反「审查门禁不可降级」：Gate 管质量标准；执行模式只影响速度，两种模式产出等价。
> 多 agent 模式下 test 角色（⑦）同样派给子 agent；单 agent 模式下三个角色都由主 agent 扮演。

## 工作包与派活

- **派发方式**（multi）：用当前运行时的子 agent 派发工具，类型取 `sdlc-backend-dev` / `sdlc-frontend-dev` / `sdlc-test-dev`；
  以插件形式安装时该类型可能带命名空间前缀，如 `sdlc-workflow:sdlc-backend-dev` / `sdlc-workflow:sdlc-frontend-dev` / `sdlc-workflow:sdlc-test-dev`，两种命名都需尝试；
  都不可用时改用通用子 agent（general-purpose），派活 prompt 不变。
- **并行**：backend 与 frontend 两个子 agent 在**同一轮**同时派发，全部返回后进入 ⑥.3；test 子 agent 在 ⑥.3 之后单独派发。
- **单 agent 模式**：主 agent 按同一份角色说明与工作包依次执行，同样写 `tracks/<track>.md`。
- **派活 prompt 模板**：

```
你是 SDLC 流水线的 <track> 角色。「角色说明」是你必须遵守的规则，「工作包」是你本次的任务。

=== 角色说明（references/roles/<track>.md 全文）===
<全文>

=== 汇报模板（references/roles/track-report.md 全文）===
<全文>

=== 工作包 ===
迭代目录: <ITER_DIR>
任务（按执行顺序）: <每个任务在 tasks.md 中的完整片段：标题、描述、目标文件、Track、适用规范、Requirement IDs、验收标准、依赖关系>
接口契约: <design.md「## 3. 接口契约」整节 + 契约文件路径>
规范上下文: <ARCHITECTURE / SECURITY / CODING_GUIDELINES 相关摘录 + CTX.skills 索引>
测试命令: TEST_FRAMEWORK=<值>，LINT_TOOL=<值>

完成后：写 <ITER_DIR>/tracks/<track>.md，并在最终回复中给出与其相同的内容。
```

> **CTX.skills 索引格式要求**：传给子 agent 的 `CTX.skills` 索引必须包含每个命中 skill 的
> **SKILL.md 文件路径**，不能只给 skill 名。子 agent 没有 Skill 工具，只能靠 `Read` 读取该路径
> 才能拿到 skill 正文；只给名字会导致子 agent 无法加载规范内容。

## 汇总：越界检测与公共文件请求

**SNAPSHOT()**（文件级、CHANGED 与 PRE_CHANGED 统一用这一口径，避免两者基线不一致）：

```
IF 仓库存在至少一次提交（git rev-parse HEAD 成功）:
  SNAPSHOT() = (git diff --name-only HEAD) ∪ (git ls-files --others --exclude-standard)
ELSE:  # 全新仓库，尚无 HEAD，git diff HEAD 会报错
  SNAPSHOT() = (git ls-files) ∪ (git ls-files --others --exclude-standard)
```

**PRE_CHANGED 基线**：⑥.0 打包阶段用 SNAPSHOT() 计算，只在**本次 apply 首次进入 ⑥.0** 时计算一次，
写入 `$ITER_DIR/tracks/.pre-changed`；断点续跑重新进入 ⑥.0 时该文件已存在则直接复用，不重新计算
（否则续跑前主 agent 自己写的文件会被误当作"开工前已存在"而漏检）。

在 ⑥.3（读 backend / frontend 汇报）与 ⑦.1（读 test 汇报）各执行一次：

```
CHANGED = SNAPSHOT() − PRE_CHANGED − "$ITER_DIR/**"   # 迭代目录自身产物（tracks/*.md、.pre-changed 等）不算越界
FOR f IN CHANGED:
  IF f 由主 agent 在 ⑥.1 或汇总中修改: CONTINUE
  owner = 在 tracks/*.md「修改的文件」「新增的测试」中列出 f 的角色
  IF owner 为空:                    LOG "⚠️ 未被汇报的改动: $f"   → 主 agent 复核
  ELIF f 不在 owner 角色白名单内:     LOG "⚠️ 越界改动: $f（$owner）" → 主 agent 复核
  复核结论: 合理 → 保留，并在对应 tracks/<track>.md 补记；不合理 → 回退该文件改动
FOR 每条「公共文件修改请求」: 主 agent 评估后执行（如安装依赖、注册路由），执行结果记入 tracks/foundation.md
```

multi 模式下主 agent 在此对 owner 为子 agent 的代码文件统一跑一次 `LINT_TOOL`
（PostToolUse hook 已触发时属冗余但无害），失败项退回对应角色修复。

## blocked 处理

1. 子 agent 遇计划外必须改公共文件 → 停止该任务，汇报标 `blocked` 并写明请求；status.json `tracks.<track>=blocked`。
2. 主 agent 处理请求（改公共文件）后，重派该 Track **一次**（只含未完成的任务）。
3. 仍 `blocked` → 主 agent 以 single 方式接手完成该 Track，汇报「执行者」记为 `main`，`agent_mode_reason` 追加 "；<track> 由主 agent 接手"。

## 断点续跑

- apply 重新进入时（phase 仍为 `approved`），若 status.json 已有 `tracks`：跳过值为 `done` / `skipped` 的 Track，从 `pipeline_stage` 所在步骤继续。
- 续跑时重新解析执行模式，可与上次不同（如 multi 中断后以 single 续跑剩余 Track）；更新 `agent_mode`，`agent_mode_reason` 前缀 "续跑: "。
- 无任务的 Track 在 ⑥.0 即记为 `skipped`；**`foundation` 例外**——只有同时满足"没有 infra / shared 任务"
  **且**"design.md「### 5.3 新增依赖」为空或写 `无`"两个条件才记 `skipped`；只要有一项不满足（哪怕只是要装依赖，没有
  infra/shared 任务），⑥.1 仍要跑一遍（至少完成依赖安装）。

## 修复回合

Gate 2（⑧，`--review` 模式）或 ⑨ test-pipeline 失败后需要修复代码，SKILL.md「循环与回退规则」的回退目标
是「步骤⑥ 开发」，但角色模型下**不**重新派发子 agent、也不整体重跑 ⑥.0-⑥.3，规则如下：

1. **谁来修**：无论 single/multi 模式，修复统一由**主 agent**以单 agent 方式直接改代码；改动仍须落在
   该问题所属角色（backend / frontend / test）的白名单内——公共文件本来就允许主 agent 改，不算越界。
2. **记录**：修复完成后，把改动文件 + 原因追加到问题所属的 `$ITER_DIR/tracks/<track>.md`，新增一个
   「修复记录」小节（不覆盖、不删除原有「完成的任务与 AC」「修改的文件」等小节）。
3. **回归范围**：
   - 必须重新执行 SKILL.md ⑥.5「勾选属实自检」，确认 tasks.md 状态与修复后的真实实现一致；
   - 只有修复改变了 AC 行为（而非纯格式化 / lint 修复）时，才重新跑一次 ⑦ 查漏；否则跳过 ⑦。
4. **Track 状态**：已经是 `done` 的 Track 保持 `done`，不因修复回合被重置为 `in_progress`，也不重新派发
   任何子 agent（无论 single/multi）。
5. **轮数**：修复回合仍计入 Gate 2 / ⑨ 各自的 `REVIEW_MAX_ROUNDS`，超限行为不变（控制台报错，中止，人工介入）。

## 自动查找最近 proposal

当用户不指定迭代目录时，自动定位：

```bash
find_latest_proposal() {
  find docs/iterations/ -name "status.json" -type f \
    | while read f; do
        phase=$(jq -r '.phase' "$f")
        if [ "$phase" = "pending_review" ] || [ "$phase" = "approved" ]; then
          echo "$f"
        fi
      done \
    | sort -r \
    | head -1 \
    | xargs dirname
}

if [ -z "$ITER_DIR" ]; then
  ITER_DIR=$(find_latest_proposal)
  if [ -z "$ITER_DIR" ]; then
    echo "❌ 未找到待处理的 proposal"
    echo "   请先运行 /sdlc-workflow proposal <需求>"
    exit 1
  fi
  echo "📂 自动定位到: $ITER_DIR"
fi
```

## 控制台输出

### Apply 启动

```
🚀 开始执行需求开发

📂 迭代目录: <iter_dir>
📝 任务数: <N> | 预估工时: <N>h
🔍 Proposal 审核通过 ✅
```

### Apply 完成

```
✅ 开发完成: N 个任务 | 测试: lint + unit 全部通过
📂 迭代目录: <iter_dir>
👉 浏览器验收请运行: /sdlc-workflow:qa
👉 确认无误后提交: /sdlc-workflow:accept
```

## 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| status.json 不存在 | 中止，提示先运行 proposal |
| phase 为 rejected | 中止，提示修改后重新 proposal |
| phase 为 applied | 中止，提示已执行过（需手动重置） |
| 产物文件缺失 | 中止，提示重新 proposal |
| Gate 2 超限（--review 时） | 中止，控制台输出错误，提示人工介入 |
| lint / unit 修复超限 | 中止，控制台输出错误，提示人工介入 |

## status.json 更新

### Apply 开始时

```json
{
  "phase": "approved",
  "reviewed_at": "2026-04-13T15:00:00+08:00",
  "reviewer": "cli-apply",
  "agent_mode": "multi",
  "agent_mode_reason": "auto: backend+frontend 均有任务",
  "pipeline_stage": "dev",
  "tracks": {
    "foundation": "done",
    "backend": "in_progress",
    "frontend": "in_progress",
    "test": "pending"
  }
}
```

- `tracks` 取值：`pending | in_progress | done | blocked | skipped`（无任务的 Track 记 `skipped`）。
- `pipeline_stage` 取值：`foundation | dev | merge | test-audit | test-pipeline`。

### Apply 完成时

```json
{
  "phase": "applied",
  "applied_at": "2026-04-13T16:30:00+08:00"
}
```

## 流程中的位置

```
proposal → 人工审核 → apply → qa → accept → pr
  ①-⑤              ⑥-⑨    ⑩    ⑪⑫       ⑬

proposal = 步骤①-⑤ + 暂停（pending_review）
apply    = 步骤⑥-⑨（开发 + 单元测试 + lint，phase: applied）
qa       = 步骤⑩（浏览器功能验收，phase: qa_passed）
accept   = 步骤⑪⑫（更新文档 + 本地 commit，phase: accepted）
pr       = 步骤⑬（push + 创建 PR，phase: pr_created）
doit     = proposal + apply (+ qa --qa) + accept + pr，不停顿
```

## 相关文件

- 输入：
  - docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/requirements.md
  - docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/design.md
  - docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/tasks.md
  - docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/status.json
- 输出：
  - 代码变更
  - tests/unit/ + tests/reports/
  - status.json（phase: applied）
- 参考：
  - references/flow-proposal.md（前置步骤）
  - references/08-code-reviewer.md（Gate 2）
  - references/09-test-pipeline.md（lint + unit）
  - references/flow-accept.md（后续：更新文档 + 提交）
