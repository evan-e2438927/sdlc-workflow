---
name: sdlc-workflow
description: >-
  Full SDLC automation pipeline with dual-model review gates
  (Claude Code generates, Codex CLI reviews).
  Use when starting a new feature, processing requirements from text/URL/JIRA,
  running automated development workflow.
  Triggers: start workflow, new feature, process requirement, run pipeline,
  SDLC, digital worker, development automation, requirements to PR.
argument-hint: "init [配置] | proposal <需求> | apply <迭代目录> | doit <需求> | mini <小任务> | worktree <create|list|status|remove|gc>"
homepage: https://github.com/evan-taojiangcb/sdlc-workflow
metadata:
  openclaw:
    emoji: "🏭"
    requires:
      bins: ["codex", "gh", "openclaw"]
    install:
      - id: codex
        kind: npm
        package: "@openai/codex"
        bins: ["codex"]
        label: "Install Codex CLI (OpenAI)"
      - id: gh
        kind: brew
        formula: "gh"
        bins: ["gh"]
        label: "Install GitHub CLI"
      - id: openclaw
        kind: npm
        package: "openclaw"
        bins: ["openclaw"]
        label: "Install OpenClaw CLI"
---

## 命令分工

当前稳定入口是单入口多模式：

- `/sdlc-workflow init`：初始化或接入项目
- `/sdlc-workflow proposal`：需求拆解（到 Gate 1 通过），产出 proposal 产物后暂停，等待人工审核
- `/sdlc-workflow apply`：人工审核通过后，从 proposal 产物继续执行开发到 PR
- `/sdlc-workflow doit`：全自动模式（内部 proposal + apply 不停顿）
- `/sdlc-workflow mini`：小任务轻量流程
- `/sdlc-workflow worktree create <slug> <type>`：创建并行工作区（worktree 隔离）
- `/sdlc-workflow worktree list`：列出所有并行工作区
- `/sdlc-workflow worktree status`：全局并行状态总览
- `/sdlc-workflow worktree remove <seq|slug>`：移除已完成的并行工作区
- `/sdlc-workflow worktree gc`：清理已合并的并行工作区

### proposal — 需求拆解命令

```bash
/sdlc-workflow proposal <需求>
```

接受三种输入格式：纯文本、`file:///path` 本地文件、URL（自动 Playwright MCP 提取）。

执行步骤 ①-⑤：
```
① requirements-ingestion → requirements.md
② requirements-clarifier → 标注版 requirements.md
③ design-generator       → design.md
④ task-generator          → tasks.md
⑤ design-reviewer (Gate 1)
⑤.1 增量文档同步（若经修订）
```

产出：
- `docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/` 下的 requirements.md / design.md / tasks.md / status.json
- `status.json` 标记 `phase: "pending_review"`
- TG 通知: 📋 需求拆解完成，等待人工审核
- ⚓ 暂停，等待 `apply`

详细规范见 `references/proposal.md`。

### apply — 需求开发命令

```bash
/sdlc-workflow apply <迭代目录>
# 示例
/sdlc-workflow apply docs/iterations/2026-04-16/001-user-login-feature/
```

若不指定路径，自动查找最近一个 `phase == "pending_review" | "approved"` 的迭代目录。

前置检查：
- status.json 存在且 `phase` 为 `pending_review`（视为审核通过）或 `approved`
- `phase == applied` → 拒绝重复执行
- `phase == rejected` → 提示修改后重新 proposal

执行步骤 ⑥-⑪：
```
⑥ Claude Code 开发（支持 Agent Team 并行）
⑦ test-generator
⑧ code-reviewer (Gate 2)
⑨ test-pipeline
⑩ docs-updater
⑪ git-committer → branch → commit → push → PR
```

完成后更新 `status.json` 为 `phase: "applied"`。

详细规范见 `references/apply.md`。

### doit — 全自动模式

```bash
/sdlc-workflow doit <需求>
```

内部等价于 `proposal + apply` 不停顿，适用于完全信任 AI 处理的场景。
Gate 1 通过后直接继续开发，不写 `status.json`，不暂停。

### mini — 小任务轻量流程

```bash
/sdlc-workflow mini <小任务>
```

轻量流程，但不是跳过流程。仍必须执行：
- iteration 产物生成
- mini Gate 1
- validation capability detection
- mini Gate 2
- Playwright MCP + CDP 最终验收

详细规范见 `references/mini-pipeline.md`。

### worktree — 并行开发管理

通过 Git Worktree 创建隔离的并行工作区，每个工作区独立运行 pipeline。

```bash
# 创建并行工作区
/sdlc-workflow worktree create <slug> <type>
# 示例
/sdlc-workflow worktree create user-login feature
/sdlc-workflow worktree create password-reset fix

# 列出所有并行工作区
/sdlc-workflow worktree list

# 全局状态总览（聚合所有 worktree 的 status.json）
/sdlc-workflow worktree status

# 移除已完成的工作区
/sdlc-workflow worktree remove <seq|slug>
/sdlc-workflow worktree remove --all-merged

# 检查可清理的工作区
/sdlc-workflow worktree gc
```

**create** 行为：
1. 从 `main` 创建分支 `{type-prefix}/{slug}-{date}-wt{seq}`
2. `git worktree add ../wt-<seq>-<slug>-<type> -b <branch>`
3. 在新 worktree 初始化迭代目录
4. 自动分配端口（`PORT=3000+seq, API_PORT=4000+seq`）
5. 注册到 `.worktrees/worktree-registry.json`

**典型流程**：
```bash
# 1. 创建并行工作区
sdlc-worktree.sh create user-login feature
cd ../wt-001-user-login-feature
pnpm install

# 2. 在 worktree 中跑 pipeline
/sdlc-workflow proposal "用户登录功能"
# → 审核通过后
/sdlc-workflow apply docs/iterations/2026-04-16/001-user-login-feature/

# 3. 同时在另一个 worktree 开发别的需求
cd ../main-repo
sdlc-worktree.sh create payment fix
cd ../wt-002-payment-fix
/sdlc-workflow doit "支付修复"

# 4. 完成后清理
cd ../main-repo
sdlc-worktree.sh remove 001
```

详细规范见 `references/parallel-dev.md`。
脚本位置：`scripts/sdlc-worktree.sh`。

## 项目初始化

检查当前项目是否已初始化 SDLC 工作流结构：

1. 先判断当前项目是 fresh project 还是 existing project：
   - 若已存在 `apps/`、`packages/`、`src/`、`package.json`、`pnpm-workspace.yaml`、`turbo.json`、`.git/` 等业务/工程结构 → existing project
   - 若目录基本为空，仅准备首次接入 workflow → fresh project
2. 检测 `.claude/CLAUDE.md` 和 `.claude/ARCHITECTURE.md` 是否存在
3. 若两者都存在 → 项目已初始化，跳过，直接进入 Part 2
4. 若任一不存在 → 执行初始化：
   - 运行 `bash <skill-root>/sdlc-workflow/scripts/init-project.sh .`（`<skill-root>` 为 Skill 安装目录，如 `~/.claude/skills`）
   - 生成项目结构（.claude/, docs/, tests/, .env.example）
   - 提醒用户：若 `.env` 不存在，从 `.env.example` 复制并填写 TG_USERNAME
5. 若判定为 existing project，则初始化后必须先执行 `references/existing-project-intake.md`：
   - 生成 `.claude/PROJECT_BASELINE.md`
   - 生成 `.claude/EXISTING_STRUCTURE.md`
   - 生成 `.claude/TEST_BASELINE.md`
   - 在基线完成前，不得直接进入 requirements/design/tasks

## TG_USERNAME 自动检测

Pipeline 启动时按以下优先级确定 TG_USERNAME：

1. **运行时上下文检测**（TG/OpenClaw 触发场景）：
   - 检查环境变量 `OPENCLAW_TRIGGER_USER`（OpenClaw 触发时自动注入）
   - 若存在 → 初始化阶段自动创建 `.env`（若缺失）并写入 `TG_USERNAME`
   - 日志: "📱 检测到 TG 用户: <user_id>，已自动配置"

2. **读取 `.env` 文件**：
   - 若 `.env` 存在且 TG_USERNAME 已设置 → 使用该值
   - 若 `.env` 不存在且未处于 TG 触发场景 → 提示用户从 `.env.example` 复制
   - 若 TG_USERNAME 为空 → 提示用户手动配置

3. **兜底**：
   - 若以上均无法获取 → 提示 "请在 .env 中设置 TG_USERNAME" → 暂停

## 配置读取

从项目 `.env` 文件读取所有配置变量。未设置的变量使用默认值：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| TG_USERNAME | (空) | 必需，Telegram 账号数字 ID 或 chat_id |
| TEST_FRAMEWORK | jest | 单元测试框架 |
| E2E_FRAMEWORK | playwright | 固定 E2E 测试框架 |
| LINT_TOOL | eslint | Lint 工具 |
| REVIEW_MAX_ROUNDS | 1 | 审查最大轮数 |
| GIT_BRANCH_PREFIX | feat/ | Git 分支前缀 |
| COMMIT_SCOPE | (空) | Commit scope |

## 迭代目录命名规则

每次 Pipeline 运行创建一个迭代目录：

  docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/

命名规则：
- YYYY-MM-DD: 当天日期
- <seq>: 当天内递增的 3 位序号，从 `001` 开始
- <slug>: 需求名称的 kebab-case 形式（从需求内容提取关键词，≤30 字符）
- <type>: 变更类型，从以下枚举中选择：
  feature | fix | refactor | docs | test | chore

示例：
  docs/iterations/2026-03-25/001-user-login-feature/
  docs/iterations/2026-03-25/002-password-reset-fix/
  docs/iterations/2026-03-26/001-cache-layer-refactor/

该目录下包含：requirements.md, design.md, tasks.md, status.json

## Pipeline 编排

### 步骤概览

| 步骤 | 名称 | 说明 | 命令归属 |
|------|------|------|----------|
| ⓪ | 初始化 + 模式识别 | fresh/existing 分流 → init-project.sh → existing intake → TG_USERNAME → .env → 迭代目录 | proposal/doit |
| ① | requirements-ingestion | 识别输入类型 → 提取/读取/解析 → requirements.md | proposal/doit |
| ② | requirements-clarifier | 逐条分析置信度，标注确认/假设/提问 | proposal/doit |
| ③ | design-generator | 生成 design.md（引用历史 iterations） | proposal/doit |
| ④ | task-generator | design.md → tasks.md（任务级 AC 必须引用需求级 AC-ID，保留 Given-When-Then + 场景维度） | proposal/doit |
| ⑤ | design-reviewer | **Gate 1**: Codex CLI 审查设计 + AC 覆盖度检查 | proposal/doit |
| — | **proposal 暂停点** | 写入 status.json → TG 通知 → 等待人工审核 | **仅 proposal** |
| ⑥ | Claude Code 开发 | 按 tasks.md 逐任务实现代码 | apply/doit |
| ⑦ | test-generator | 生成 tests/unit/ + tests/e2e/ | apply/doit |
| ⑧ | code-reviewer | **Gate 2**: Codex CLI 审查代码 | apply/doit |
| ⑨ | test-pipeline | lint → unit → Playwright 预检 → Playwright MCP 功能验收（不可跳过）→ CDP 复核 → 生成 HTML 验收报告 | apply/doit |
| ⑩ | docs-updater | 更新文档 + CLAUDE.md iterations 引用 | apply/doit |
| ⑪ | git-committer | branch → commit → push → PR | apply/doit |

### 详细流程

#### ⓪ 初始化
```
MODE=$(detect_project_mode)  # fresh | existing

IF NOT (.claude/CLAUDE.md AND .claude/ARCHITECTURE.md):
  RUN init-project.sh

IF MODE == existing:
  RUN existing-project-intake
  REQUIRE .claude/PROJECT_BASELINE.md
  REQUIRE .claude/EXISTING_STRUCTURE.md
  REQUIRE .claude/TEST_BASELINE.md

IF OPENCLAW_TRIGGER_USER:
  ENSURE .env EXISTS (copy from .env.example if missing)
  WRITE .env TG_USERNAME=OPENCLAW_TRIGGER_USER
  LOG "📱 检测到 TG 用户: @<username>，已自动配置"

IF NOT .env:
  COPY .env.example TO .env
  LOG "请编辑 .env 设置 TG_USERNAME"

READ .env

SLUG=$(generate_slug_from_requirements "$INPUT")  # 优先语义化英文 slug，失败则 req-<hash8>
TYPE=$(infer_type "$INPUT")  # feature|fix|refactor|docs|test|chore
DATE=$(date +%Y-%m-%d)
DATE_DIR="docs/iterations/$DATE"
MKDIR -p "$DATE_DIR"
LAST_SEQ=$(find "$DATE_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | \
  sed -n 's/^\([0-9][0-9][0-9]\)-.*/\1/p' | sort | tail -n1)
IF [ -n "$LAST_SEQ" ]; THEN
  SEQ=$(printf "%03d" $((10#$LAST_SEQ + 1)))
ELSE
  SEQ="001"
FI
ITER_DIR="$DATE_DIR/$SEQ-$SLUG-$TYPE/"
MKDIR -p "$ITER_DIR"
```

#### ① requirements-ingestion
- 输入类型路由：文本 → 直接解析；file:// → 读取文件；URL → Playwright MCP
- **验收标准生成**：每个 Requirement 必须按 5 个维度系统化枚举 AC（happy-path / error / boundary / ui-state / security），禁止只写 happy path
- 输出：docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/requirements.md
- 通知 TG：📥 需求已收录

#### ② requirements-clarifier
- 逐条分析 confidence：
  - 高(≥0.8): 添加 [✅ 已确认]
  - 中(0.5-0.8): 添加 [⚠️ 假设: ...]
  - 低(<0.5):
    - **交互模式**（proposal / mini，且非 OPENCLAW_TRIGGER_USER）：主会话内通过 AskUserQuestion 发起选择询问，用户作答后写入需求并标注 [✅ 已确认（用户选择）]
    - **无人值守模式**（doit / TG 触发）：fallback 为 auto-assume，标注 [⚠️ 假设: ...]，不阻塞
  - 用户跳过/工具不可用 → fallback 为 auto-assume
- TG 仅作完成状态摘要（"❓ 需求澄清完成: 已确认N / 已假设M"），不发起提问
- 输出：更新后的 requirements.md

#### ③ design-generator
- 读取：requirements.md + .claude/ARCHITECTURE.md + .claude/SECURITY.md + docs/iterations/（历史）
- 若为 existing project，额外读取：`.claude/PROJECT_BASELINE.md` + `.claude/EXISTING_STRUCTURE.md` + `.claude/TEST_BASELINE.md`
- 设计必须声明代码落位：默认遵循 Better-T-Stack 风格 `apps/web` / `apps/server` / 条件启用的 `packages/*`
- 若为 existing project，必须明确说明"沿用既有结构"还是"本轮经批准的结构调整"
- 输出：docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/design.md
- 通知 TG: 🎨 设计文档已生成

#### ④ task-generator
- 输入：design.md
- 输出：docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/tasks.md
- **验收标准规则**：
  - 每个任务的 AC 必须引用 requirements.md 中的 AC-ID（如 `AC-001`），不得凭空编写
  - 保留 Given-When-Then 格式和场景维度标注（happy-path / error / boundary / ui-state / security）
  - 补充实现层面的具体判定条件（HTTP 状态码、响应体结构、UI 选择器、数值约束）
  - 每个 Requirement 至少覆盖 happy-path + error 两个维度
  - 禁止退化为模糊 checkbox（如 "功能正常"、"数据正确"）
- 通知 TG: 📋 任务分解完成: <任务数> 个任务 | 预估工时: <总工时>

#### ⑤ design-reviewer (Gate 1)
```
round=1
WHILE round <= REVIEW_MAX_ROUNDS:
  result=$(codex exec --full-auto "审查设计...
    额外检查第 7 项: AC 覆盖度
    - requirements.md 每个 AC-ID 是否在 tasks.md 被引用
    - tasks.md AC 是否保留 Given-When-Then + 场景维度
    - 是否存在模糊不可验证的 AC
    - 每个 Requirement 是否至少覆盖 happy-path + error")
  IF result == PASS:
    通知 TG: 🔍 设计 Review: PASS ✅
    BREAK
  ELSE:
    IF round < REVIEW_MAX_ROUNDS:
      通知 TG: 🔍 设计 Review 第{round}轮: <问题>
      CLAUDE 修订 design.md + tasks.md
    ELSE:
      通知 TG: ⚠️ 设计 Review 超过 {N} 轮，需人工介入
      ABORT
  round+=1
```

#### ⑤.1 Gate 1 后增量文档同步

Gate 1 通过后，若经过 ≥1 轮修订，必须同步更新受影响的文档：

```
IF Gate 1 审查经过修订（round > 1）:
  DIFF = diff(requirements.md + design.md + tasks.md 原始版本, 当前版本)
  IF DIFF 涉及需求范围变更:
    同步更新 requirements.md 中的 [⚠️ 假设] 标注
  IF DIFF 涉及架构决策变更:
    同步更新 .claude/ARCHITECTURE.md 对应章节
  IF DIFF 涉及安全设计变更:
    同步更新 .claude/SECURITY.md 对应章节
  IF DIFF 涉及目录结构调整:
    同步更新 .claude/EXISTING_STRUCTURE.md（existing project）
  IF DIFF 涉及任务拆分/验收标准变更:
    确认 tasks.md 与修订后的 design.md 一致
  LOG "📄 Gate 1 修订已同步到基线文档"
```

**原则**：只更新被修订影响的章节，不做全量重写。确保 ⑥ 开发阶段读取到的 .claude/ARCHITECTURE.md 与 design.md 决策一致。

#### ⑤.2 Proposal 暂停（仅 proposal 命令）

```
IF 当前为 proposal 模式:
  # 提取 summary
  REQ_COUNT=$(从 requirements.md 提取需求数)
  TASK_COUNT=$(从 tasks.md 提取任务数)
  TOTAL_HOURS=$(从 tasks.md 提取总工时)

  # 写入 status.json
  WRITE "$ITER_DIR/status.json" {
    "phase": "pending_review",
    "proposal_at": "$(date -Iseconds)",
    "reviewed_at": null,
    "applied_at": null,
    "reviewer": null,
    "iter_dir": "$ITER_DIR",
    "summary": {
      "requirement_count": $REQ_COUNT,
      "task_count": $TASK_COUNT,
      "estimated_hours": $TOTAL_HOURS
    }
  }

  通知 TG: 📋 需求拆解完成，等待人工审核
    📂 迭代目录: $ITER_DIR
    📝 需求数: $REQ_COUNT | 任务数: $TASK_COUNT | 预估工时: ${TOTAL_HOURS}h
    👉 审阅后请运行: /sdlc-workflow apply $ITER_DIR

  STOP  # proposal 到此结束

IF 当前为 doit 模式:
  # 不写 status.json，直接继续步骤 ⑥
```

#### ⑤→⑥ 上下文检查点
```
IF context_usage > 80%:
  确认 requirements.md / design.md / tasks.md / status.json 已持久化到迭代目录
  执行 /compact
  重新加载: $ITER_DIR/{requirements,design,tasks}.md + .claude/{ARCHITECTURE,SECURITY}.md
```

#### ⑥ Apply 入口检查（仅 apply 命令）

```
IF 当前为 apply 模式:
  STATUS_FILE="$ITER_DIR/status.json"

  IF NOT exists(STATUS_FILE):
    ERROR "未找到 status.json，请先运行 /sdlc-workflow proposal"
    ABORT

  PHASE = read(STATUS_FILE, "phase")

  IF PHASE == "pending_review":
    # 用户直接 apply 视为审核通过
    UPDATE STATUS_FILE: phase="approved", reviewed_at=now, reviewer="cli-apply"
    通知 TG: 🚀 Proposal 审核通过，开始开发

  ELSE IF PHASE == "approved":
    通知 TG: 🚀 开始执行需求开发

  ELSE IF PHASE == "applied":
    ERROR "该 proposal 已执行过 apply"
    ABORT

  ELSE IF PHASE == "rejected":
    ERROR "该 proposal 已被拒绝，请修改后重新 proposal"
    ABORT
```

#### ⑥ Claude Code 开发
- 通知 TG: 🔨 开始实现: <需求摘要前50字>

##### ⑥.1 依赖分析与并行分组

```
TASKS = parse_tasks("$ITER_DIR/tasks.md")
DEP_GRAPH = build_dependency_graph(TASKS)  # 从"依赖关系"和 Phase 分组推导

# 拓扑排序，识别可并行层
LAYERS = topological_layers(DEP_GRAPH)
# 示例：
#   Layer 0: [T-001, T-002]    ← 无前置依赖，可并行
#   Layer 1: [T-003, T-004]    ← 依赖 Layer 0，组内可并行
#   Layer 2: [T-005]           ← 依赖 Layer 1

PARALLEL_ELIGIBLE = any(len(layer) > 1 for layer in LAYERS) AND total_tasks >= 3
```

##### ⑥.2 执行模式选择

```
IF PARALLEL_ELIGIBLE:
  MODE = "agent-team"
  通知 TG: 🔨 开始实现（Agent Team 并行模式）: <层数> 层 / <总任务数> 任务
ELSE:
  MODE = "sequential"
  通知 TG: 🔨 开始实现（顺序模式）: <总任务数> 任务
```

##### ⑥.3a 顺序模式（默认）

按 tasks.md 逐任务实现代码，并在实现偏离 design.md 时同步修订 design/tasks，避免 Gate 2 审查对象与真实代码脱节。每完成一个任务后，必须同步回写 `tasks.md`。

##### ⑥.3b Agent Team 并行模式

```
FOR layer IN LAYERS:
  IF len(layer) == 1:
    # 单任务层，主 Agent 直接执行
    execute_task(layer[0])
  ELSE:
    # 多任务层，分发给子 Agent
    # ⚠️ 并行前置条件：
    #   - 同层任务的目标文件（Target Files）无交集
    #   - 若有文件交集 → 降级为顺序执行该层
    IF has_file_overlap(layer):
      LOG "⚠️ Layer 任务存在目标文件交集，降级顺序执行"
      FOR task IN layer: execute_task(task)
    ELSE:
      sub_agents = []
      FOR task IN layer:
        agent = spawn_sub_agent(
          prompt = """
            你是 SDLC 开发子 Agent，负责实现单个任务。
            任务: {task}
            角色定位（Track）: {task.track}（请遵循该端的代码风格、依赖偏好、测试惯例）
            设计文档: {design.md 相关章节}
            架构约束: {ARCHITECTURE.md}
            编码规范: {CODING_GUIDELINES.md}
            规则:
            - 只修改任务 Target Files 范围内的文件
            - 修改文件路径必须落在 Track 对应范围内（frontend→apps/web, backend→apps/server, shared→packages/{config,env,auth}, infra→db/migrations|root configs, test→tests/）
            - 不得修改其他任务的目标文件
            - 完成后报告: 修改的文件列表 + 验收标准完成情况
          """
        )
        sub_agents.append(agent)

      # 等待所有子 Agent 完成
      results = await_all(sub_agents)

      # 冲突检测与合并
      modified_files = collect_all_modified_files(results)
      IF has_conflict(modified_files):
        LOG "⚠️ 子 Agent 产出文件冲突，主 Agent 手动合并"
        resolve_conflicts(results)

  # 每层完成后同步回写 tasks.md
  FOR task IN layer:
    更新 tasks.md: ### [ ] T-xxx → ### [x] T-xxx
    勾选已满足的验收标准
```

##### ⑥.4 任务完成回写（两种模式通用）

- 将任务标题从 `### [ ] T-xxx` 改为 `### [x] T-xxx`
- 将该任务下已实际满足的验收标准勾选为 `[x]`
- 未完成或部分完成的任务不得提前勾选
- 实现偏离 design.md 时同步修订 design/tasks，避免 Gate 2 审查对象与真实代码脱节

- 通知 TG: 🔨 实现完成: <已完成任务数>/<总任务数>

#### ⑦ test-generator
- 输入：tasks.md + git diff
- **测试用例必须引用 AC-ID 和场景维度**（如 `it('AC-002 (error): 密码错误返回 401')`）
- 输出：
  - tests/unit/web|server|packages/...
  - tests/e2e/<slug>/E2E-<nnn>-<scenario>.e2e.ts
  - tests/reports/<slug>-coverage.md（含 AC 覆盖率汇总和场景维度覆盖统计）
- 通知 TG: 🧪 测试用例已生成

#### ⑧ code-reviewer (Gate 2)
```
round=1
WHILE round <= REVIEW_MAX_ROUNDS:
  result=$(codex exec --full-auto "审查代码...")
  IF result == PASS:
    通知 TG: 🔍 Code Review: PASS ✅
    BREAK
  ELSE:
    IF round < REVIEW_MAX_ROUNDS:
      通知 TG: 🔍 Code Review 第{round}轮: <问题>
      CLAUDE 修复代码
    ELSE:
      通知 TG: ⚠️ Code Review 超过 {N} 轮，需人工介入
      ABORT
  round+=1
```

Gate 2 还必须检查 `tasks.md` 状态是否与真实实现一致：

- 已实现的任务是否同步勾选
- 已勾选的验收标准是否能被代码、测试和报告支撑
- 是否存在"代码已完成但任务仍未完成"或"任务已勾选但证据不足"的状态漂移

#### ⑧→⑨ 上下文检查点
```
IF context_usage > 80%:
  确认代码变更已 git add（暂存）
  执行 /compact
  重新加载: tasks.md + git diff --cached 摘要 + 失败的 review 反馈（如有）
```

#### ⑧→⑨ Pipeline 阶段持久化
```
# 进入 test-pipeline 前，必须将当前阶段写入 status.json
UPDATE "$ITER_DIR/status.json": pipeline_stage="test-pipeline"
# 这确保 token 耗尽后新会话可通过 status.json 发现未完成的 test-pipeline
```

#### ⑨ test-pipeline
```
STAGE 1: npx $LINT_TOOL .        # 快速失败
STAGE 2: npx $TEST_FRAMEWORK     # unit tests
STAGE 3: npx playwright test     # Playwright 预检
STAGE 4: Playwright MCP 功能验收（⚠️ 不可跳过）
  ⚠️ 前置：Agent 必须自行启动 dev server
    → 读取 package.json scripts 检测启动命令（dev > start > serve）
    → 后台启动 dev server，等待 ready/listening 关键词
    → 从输出中提取实际 URL 和端口
    → ❌ 禁止因 "dev server 未运行" 跳过或标记 Pending
  → 必须真正调用 Playwright MCP 工具:
    browser_navigate → browser_snapshot → browser_click/type
    → browser_console_messages → browser_screenshot
  → 产出: tests/reports/playwright/<slug>-<scenario>.md + 截图
STAGE 5: CDP 交互复核（Chrome DevTools Protocol）
  → 产出: tests/reports/cdp/<slug>-<scenario>.md
STAGE 6: 生成最终验收报告（HTML 图表）
  → 产出: tests/reports/<slug>-acceptance-report.html

# ⑨.artifact-gate: 产物验证门禁（必须在标记完成前执行）
REQUIRED_ARTIFACTS = [
  "tests/reports/playwright/<slug>-*.md",
  "tests/reports/<slug>-acceptance-report.html"
]
FOR artifact IN REQUIRED_ARTIFACTS:
  IF NOT glob_exists(artifact):
    LOG "❌ 产物缺失: $artifact"
    IF token_budget_low:
      UPDATE status.json: pipeline_stage="test-pipeline-incomplete"
      通知 TG: ⚠️ test-pipeline 未完成，缺少产物: $artifact，需下轮会话继续
      ABORT  # 不能标记 completed
    ELSE:
      RETRY from missing STAGE
LOG "✅ 产物验证通过"

IF any failure:
  IF round < REVIEW_MAX_ROUNDS:
    通知 TG: 🧪 失败用例: <列表>
    CLAUDE 修复

    # ⑨.1 测试修复后增量文档同步
    IF 修复过程中修改了 design.md 或 tasks.md:
      同步 .claude/ARCHITECTURE.md / .claude/SECURITY.md 受影响章节
      LOG "📄 测试修复引起的设计/任务变更已同步到基线文档"

    # ⑨.2 上下文检查点
    IF context_usage > 80%:
      执行 /compact
      重新加载: 失败测试报告 + tasks.md + git diff --cached 摘要

    retry
  ELSE:
    通知 TG: ⚠️ 测试修复超过 {N} 轮
    ABORT

通知 TG: 🧪 测试结果: <通过数>/<总数>
```

> **规则**：测试修复阶段如果涉及 design.md（技术方案调整）或 tasks.md（任务范围变更），必须在 retry 前同步更新 .claude/ARCHITECTURE.md / .claude/SECURITY.md / EXISTING_STRUCTURE.md 中受影响的章节，防止文档与实际实现脱节。

#### ⑩ docs-updater
按变更更新：
- README.md — 新增功能说明
- .claude/ARCHITECTURE.md — 架构层面变更
- .claude/SECURITY.md — 安全相关变更
- .claude/CODING_GUIDELINES.md — 新模式/约定
- .claude/CLAUDE.md — **更新 iterations 引用列表**
- 通知 TG: 📝 文档已更新: <更新文件列表>

#### ⑪ git-committer
```bash
# 检测是否在 worktree 中
IS_WORKTREE=$(git rev-parse --git-common-dir 2>/dev/null | grep -q '/worktrees/' && echo 1 || echo 0)

IF IS_WORKTREE:
  # Worktree 模式：分支已在 worktree create 时创建，直接使用
  CURRENT_BRANCH=$(git branch --show-current)
  git add -A
  git commit -m "<type>(scope): <摘要>"
  git push origin "$CURRENT_BRANCH"
  gh pr create --base main --title "<type>(scope): <摘要>" --body "..."
  PR_URL=$(gh pr view --json url --jq .url)
  # 更新注册表中的 pr_url（若注册表可达）
ELSE:
  # 传统模式：创建新分支
  git checkout -b ${GIT_BRANCH_PREFIX}<slug>-YYYY-MM-DD
  git add -A
  git commit -m "<type>(scope): <摘要>"
  git push origin ${GIT_BRANCH_PREFIX}<slug>-YYYY-MM-DD
  gh pr create --title "<type>(scope): <摘要>" --body "..."
  PR_URL=$(gh pr view --json url --jq .url)
```

#### ⑪.1 Apply 状态更新（仅 apply 命令）

```
IF 当前为 apply 模式:
  UPDATE status.json: phase="applied", applied_at=now
```

#### 最终通知
通知 TG: ✅ PR: <url> | 变更: N files | 测试: 全部通过

## TG 通知命令

所有通知统一使用 OpenClaw CLI（用户需提前配置：`openclaw auth login && openclaw channel connect telegram`）：
```bash
# TG_USERNAME 为 Telegram 账号数字 ID 或 chat_id
openclaw message send --channel telegram --target "$TG_USERNAME" --message "$MSG"
```

通知列表（共 15 个通知点，覆盖所有关键环节）：
1. 初始化完成：🚀 项目初始化完成（fresh/existing）
2. 需求收录：📥 需求已收录: <摘要前50字>
3. 需求澄清：❓ 需求澄清完成: 已确认 <N> / 已假设 <M>（澄清在主会话内交互完成；TG 不承载提问）
4. 设计生成：🎨 设计文档已生成
5. 任务分解：📋 任务分解完成: <任务数> 个任务 | 预估工时: <总工时>
6. 设计 Review：🔍 设计 Review: PASS ✅ 或 🔍 设计 Review 第N轮: <问题摘要>
7. **Proposal 完成**：📋 需求拆解完成，等待人工审核（仅 proposal 命令）
8. **Apply 启动**：🚀 开始执行需求开发（仅 apply 命令）
9. 开始实现：🔨 开始实现: <需求摘要> → 实现完成: <已完成>/<总数>
10. 测试生成：🧪 测试用例已生成
11. Code Review：🔍 Code Review: PASS ✅ 或 🔍 Code Review 第N轮: <问题列表>
12. 测试结果：🧪 测试结果: <通过数>/<总数> 通过 或 🧪 失败用例: <列表>
13. 文档更新：📝 文档已更新: <更新文件列表>
14. 迭代完成：✅ PR: <url> | 变更: N files | 测试: 全部通过

超限通知（任何 Gate/测试循环超限时触发）：
- ⚠️ 需人工介入: <Gate名称> 超过 N 轮未通过

## 循环与回退规则

| 循环点 | 触发条件 | 回退到 | 最大轮数 | 超限行为 |
|--------|----------|--------|----------|----------|
| Gate 1 (⑤) | Codex 返回 FAIL | 步骤③ design-generator | REVIEW_MAX_ROUNDS | 📱 TG 中止通知 |
| Gate 2 (⑧) | Codex 返回 FAIL | 步骤⑥ Claude Code 开发 | REVIEW_MAX_ROUNDS | 📱 TG 中止通知 |
| Test (⑨) | 测试失败 | 步骤⑥ Claude Code 开发 | REVIEW_MAX_ROUNDS | 📱 TG 中止通知 |

## 全局规则

1. **单 Agent 模式**：所有步骤由一个 Claude Code Agent 执行
2. **双模型把关**：Claude Code 生成，Codex CLI 审查
3. **循环上限**：每个 Gate/Test ≤ REVIEW_MAX_ROUNDS（默认 1）
4. **Conventional Commits**：`<type>(scope): description`
5. **禁止直推**：所有变更通过 feature branch + PR
6. **通知不中断**：TG 通知失败只 log，不影响 Pipeline
7. **安全优先**：禁止在通知/日志中泄露敏感信息
8. **文件隔离**：所有文件操作限项目根目录内
9. **渐进式加载**：SKILL.md ≤500 行，详细规范按需从 references/ 加载
10. **模板不覆盖**：init-project.sh 不覆盖已存在的文件
11. **统一测试目录**：单元测试只能写入 `tests/unit/web|server|packages`，E2E 只能写入 `tests/e2e/`，报告写入 `tests/reports/`
12. **E2E 证据要求**：关键用户路径的最终报告必须以 Playwright MCP 和 CDP 的交互验证结果为准；Playwright 仅作为预检
13. **需求到测试唯一映射**：requirements、tasks、E2E 场景必须有唯一 ID 映射，禁止重复覆盖同一需求路径
14. **迭代可追溯**：docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/
15. **审查门禁不可降级**：Codex CLI 不可用时必须中止，不能自动跳过 Gate
16. **全栈目录约束**：默认采用 Better-T-Stack 风格 monorepo，业务代码不应随意落到根目录级 `web/`/`api/`/`server/`
17. **文档统一放置**：ARCHITECTURE.md、SECURITY.md、CODING_GUIDELINES.md 与 CLAUDE.md 统一放在 `.claude/` 目录
18. **proposal 状态管理**：proposal 完成后必须写入 status.json；apply 启动前必须校验 status.json
19. **上下文管理**：Pipeline 步骤间检测上下文占用，超过 80% 时执行 `/compact`。关键检查点：Gate 1 通过后进入开发前（⑤→⑥）、Gate 2 通过后进入测试前（⑧→⑨）、测试修复 retry 前（⑨ 内）。compact 前必须确保当前步骤产物已写入文件（requirements.md / design.md / tasks.md / status.json / git add），compact 后显式重新加载迭代目录产物 + .claude/ 基线文档恢复工作上下文
20. **Agent Team 并行**：在步骤 ⑦ test-generator（单元测试 + E2E 可并行生成）、⑨ test-pipeline Stage 2-3（unit + Playwright 预检可并行）、⑩ docs-updater（多文档可并行更新）使用 Agent Team 分发子任务以加速执行；Gate 审查（⑤⑧）和顺序依赖步骤（①→②→③→④）不适合并行
21. **Worktree 并行开发**：通过 `worktree create` 创建隔离工作区，每个 worktree 独立运行 pipeline；详见 `references/parallel-dev.md`
22. **Worktree 端口隔离**：并行工作区的 dev server 端口按 `PORT=3000+seq, API_PORT=4000+seq` 分配，避免冲突
23. **Worktree 注册表**：`.worktrees/worktree-registry.json` 记录所有并行工作区元数据，`git-committer` 完成后更新 `pr_url`
24. **Worktree 文件冲突检测**：创建并行工作区前检查目标文件与已有工作区的交集，存在冲突时警告
