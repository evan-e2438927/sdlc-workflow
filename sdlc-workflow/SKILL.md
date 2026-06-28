---
name: sdlc-workflow
description: >-
  Full SDLC automation pipeline with dual-model review gates
  (Claude Code generates, Codex CLI reviews).
  Use when starting a new feature, processing requirements from text/URL/JIRA,
  running automated development workflow.
  Triggers: start workflow, new feature, process requirement, run pipeline,
  SDLC, digital worker, development automation, requirements to PR.
argument-hint: "init [配置] | update [项目目录] | proposal <需求> | apply [--review] <迭代目录> | qa [<迭代目录>] | accept [<迭代目录>] | pr [<迭代目录>] | review [proposal|code] <迭代目录> | doit [--review] [--qa] <需求> | mini [--review] [--qa] <小任务> | worktree <create|list|status|remove|gc>"
homepage: https://github.com/evan-e2438927/sdlc-workflow
metadata:
  openclaw:
    emoji: "🏭"
    requires:
      bins: ["codex", "gh"]
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
---

## 命令分工

当前稳定入口是单入口多模式：

主线：**proposal → apply → qa → accept → pr**

- `/sdlc-workflow init`：初始化或接入项目
- `/sdlc-workflow update [项目目录]`：两阶段升级同步——阶段一安全同步最新脚手架（结构/配置/规则模板，不覆盖用户内容）；阶段二读真实代码做漂移感知增量刷新（基线自动刷新、用户文档逐项确认）
- `/sdlc-workflow proposal`：需求拆解（①-④，按 track 拆分），产出 proposal 产物后暂停，等待人工审核
- `/sdlc-workflow apply [--review]`：人工审核通过后，开发 + 单元测试 + lint（⑥-⑨）；**不提交、不推 PR**；`--review` 触发 Codex 审查（Gate 1 + Gate 2）
- `/sdlc-workflow qa [<迭代目录>]`：编写并执行 qa track 的 Playwright 浏览器功能验收（⑩）
- `/sdlc-workflow accept [<迭代目录>]`：总结变更 → 更新文档 → 本地 commit（⑪⑫）；**不 push、不建 PR**
- `/sdlc-workflow pr [<迭代目录>]`：push 当前分支 → gh pr create（⑬）；唯一与远程交互的命令
- `/sdlc-workflow review [proposal|code] <迭代目录>`：单独运行 Codex 审查，不触发其他流程
- `/sdlc-workflow doit [--review] [--qa]`：全自动模式（proposal + apply + [qa] + accept + pr 不停顿）；`--qa` 含浏览器验收
- `/sdlc-workflow mini [--review] [--qa]`：小任务轻量流程；`--qa` 含浏览器验收
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

执行步骤 ①-④（默认跳过 Gate 1，加 `--review` 则执行 ⑤）：
```
① requirements-ingestion → requirements.md
② requirements-clarifier → 标注版 requirements.md
③ design-generator       → design.md
④ task-generator          → tasks.md
[⑤ design-reviewer (Gate 1)   ← 仅 --review 模式]
[⑤.1 增量文档同步              ← 仅 --review 且经修订]
```

产出：
- `docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/` 下的 requirements.md / design.md / tasks.md / status.json
- `status.json` 标记 `phase: "pending_review"`
- 控制台输出: 需求拆解完成，等待人工审核
- ⚓ 暂停，等待 `apply`

详细规范见 `references/flow-proposal.md`。

### apply — 需求开发命令

```bash
/sdlc-workflow apply [--review] <迭代目录>
# 示例
/sdlc-workflow apply docs/iterations/2026-04-16/001-user-login-feature/
/sdlc-workflow apply --review docs/iterations/2026-04-16/001-user-login-feature/
```

若不指定路径，自动查找最近一个 `phase == "pending_review" | "approved"` 的迭代目录。

前置检查：
- status.json 存在且 `phase` 为 `pending_review`（视为审核通过）或 `approved`
- `phase == applied` → 拒绝重复执行
- `phase == rejected` → 提示修改后重新 proposal

执行步骤 ⑥-⑨（默认跳过 Gate 2，加 `--review` 则执行 ⑧）：
```
⑥ Claude Code 开发（frontend/backend/unit-test track，支持 Agent Team 并行）
⑦ test-generator（仅单元测试 tests/unit/）
[⑧ code-reviewer (Gate 2)   ← 仅 --review 模式]
⑨ test-pipeline（lint → unit 两阶段）
```

完成后更新 `status.json` 为 `phase: "applied"`。**不更新文档、不提交、不推 PR。**
浏览器功能验收交给 `qa`，文档/commit/PR 交给 `accept`。

详细规范见 `references/flow-apply.md`。

### review — 独立 Codex 审查命令

```bash
/sdlc-workflow review proposal <迭代目录>   # 运行 Gate 1：设计审查
/sdlc-workflow review code <迭代目录>       # 运行 Gate 2：代码审查
```

在 proposal 或 apply 流程之外，单独触发 Codex CLI 审查，不影响其他步骤。
审查结果打印到控制台；若 FAIL 则建议修订后重跑对应步骤。

### qa — 浏览器功能验收

```bash
/sdlc-workflow qa [<迭代目录>]
```

apply（`phase == applied`）后运行。读取 tasks.md 中 `track: qa` 的任务，编写 Playwright
脚本到 `tests/e2e/<slug>/`，通过 Playwright MCP 执行，产出 `tests/reports/<slug>-e2e-report.md`。
全部通过后将 status.json 更新为 `phase: "qa_passed"`。

### accept — 验收提交（更新文档 + 本地 commit）

```bash
/sdlc-workflow accept [<迭代目录>]
```

qa 通过（`qa_passed`）或跳过 qa（`applied`）后运行。总结本次变更 → docs-updater 更新受
影响文档 → git-committer branch → commit（**本地，不 push、不建 PR**）。完成后 status.json
更新为 `phase: "accepted"`。详细规范见 `references/flow-accept.md`。

### pr — 推送并创建 PR

```bash
/sdlc-workflow pr [<迭代目录>]
```

accept 完成本地提交（`phase == accepted`）后运行。`git push -u origin <branch>` → `gh pr
create --base main`。完成后 status.json 更新为 `phase: "pr_created"`（含 pr_url）。
这是**唯一与远程 / GitHub 交互**的命令。详细规范见 `references/12-pr-creator.md`。

### doit — 全自动模式

```bash
/sdlc-workflow doit [--review] [--qa] <需求>
```

内部等价于 `proposal + apply + [qa] + accept + pr` 不停顿，适用于完全信任 AI 处理的场景。
默认跳过 Gate 1 / Gate 2；加 `--review` 则两个 Gate 均启用。
加 `--qa` 在提交前插入 Playwright 浏览器功能验收。

### mini — 小任务轻量流程

```bash
/sdlc-workflow mini <小任务>
```

轻量流程，但不是跳过流程。仍必须执行：
- iteration 产物生成
- mini Gate 1（加 `--review` 时）
- validation capability detection
- mini Gate 2（加 `--review` 时）

详细规范见 `references/flow-mini.md`。

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
   - 运行 `bash ${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/scripts/init-project.sh .`（`${CLAUDE_PLUGIN_ROOT}` 为插件根目录，由 Claude Code 注入；手动安装时替换为实际 skill 路径）
   - 生成项目结构（.claude/, docs/, tests/）+ 配置文件 `.claude/.sdlc-config`
   - 提醒用户：按需编辑 `.claude/.sdlc-config`（已自动加入 .gitignore）
5. 若判定为 existing project，则初始化后必须先执行 `references/00-existing-project-intake.md`：
   - 生成 `.claude/PROJECT_BASELINE.md`
   - 生成 `.claude/EXISTING_STRUCTURE.md`
   - 生成 `.claude/TEST_BASELINE.md`
   - **基于真实代码填实** `.claude/ARCHITECTURE.md` 与 `.claude/SECURITY.md`（覆盖 init 拷贝的模板占位），并对齐 `CODING_GUIDELINES.md` / `CLAUDE.md`——非 monorepo 项目不得保留模板里的 `apps/web`/`apps/server`/`packages/*` 默认约定
   - 在基线完成前，不得直接进入 requirements/design/tasks

## 上下文加载（统一入口）

**所有命令在执行任何业务步骤前，统一经此入口加载规范，不在各命令/各 reference 里重复罗列。**

加载层级（**后者覆盖前者**，项目级 > 全局级）：

1. **全局级** `~/.claude/` — 用户跨项目通用规范
2. **项目级** `<project>/.claude/` — 当前项目专属规范，覆盖全局同名约定

每层加载清单：`CLAUDE.md` / `ARCHITECTURE.md` / `SECURITY.md` / `CODING_GUIDELINES.md` /
`rules/*.md`；existing project 额外加载项目级 `PROJECT_BASELINE.md` / `EXISTING_STRUCTURE.md`
/ `TEST_BASELINE.md`。运行时配置 `<project>/.claude/.sdlc-config`（缺省回退全局 `~/.claude/.sdlc-config` → 内置默认）。
命令运行时参数（`--review` / `--qa`）优先级最高。

调用时机：步骤 ⓪ 之后、步骤 ① 之前统一调用一次；`/compact` 后重新进入 pipeline 须重新加载；
worktree 内 `<project>` 指向该 worktree 根目录，全局级仍为 `~/.claude/`。

> 完整规则见 `references/context-loader.md`。各步骤 reference 中出现的 `.claude/*` 仅表示该步骤
> **消费**哪些上下文，实际加载一律由本入口完成。

## 配置读取

由上下文加载入口统一从 `<project>/.claude/.sdlc-config`（回退全局 `~/.claude/.sdlc-config`）读取。未设置的变量使用默认值：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| TEST_FRAMEWORK | jest | 单元测试框架（jest/vitest/mocha） |
| E2E_FRAMEWORK | playwright | 固定 E2E 框架（qa 命令用） |
| LINT_TOOL | eslint | Lint 工具（eslint/biome） |
| TEST_BOOTSTRAP_POLICY | report | 测试基础设施缺口处理（report/auto/never） |
| REVIEW_MAX_ROUNDS | 1 | Codex 审查最大轮数（--review 时生效） |
| GIT_BRANCH_PREFIX | feat/ | Git 分支前缀 |
| COMMIT_TYPE | (空) | Conventional Commits type，留空则按迭代 type 推断 |
| COMMIT_SCOPE | (空) | Conventional Commits scope，留空则自动推断 |
| PR_TEMPLATE | (空) | 自定义 PR body 模板路径 |

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
| ⓪ | 初始化 + 模式识别 | fresh/existing 分流 → init-project.sh → existing intake → 统一上下文加载（.claude/.sdlc-config）→ 迭代目录 | proposal/doit |
| ① | requirements-ingestion | 识别输入类型 → 提取/读取/解析 → requirements.md | proposal/doit |
| ② | requirements-clarifier | 逐条分析置信度，标注确认/假设/提问 | proposal/doit |
| ③ | design-generator | 生成 design.md（引用历史 iterations） | proposal/doit |
| ④ | task-generator | design.md → tasks.md（任务级 AC 必须引用需求级 AC-ID，保留 Given-When-Then + 场景维度） | proposal/doit |
| [⑤] | design-reviewer | **Gate 1（可选）**: Codex CLI 审查设计 + AC 覆盖度检查；仅 `--review` 时执行 | proposal --review |
| — | **proposal 暂停点** | 写入 status.json → 控制台输出 → 等待人工审核 | **仅 proposal** |
| ⑥ | Claude Code 开发 | 按 tasks.md 逐任务实现代码（frontend/backend/unit-test track） | apply/doit |
| ⑦ | test-generator | 仅生成单元测试 tests/unit/（unit-test track） | apply/doit |
| [⑧] | code-reviewer | **Gate 2（可选）**: Codex CLI 审查代码；仅 `--review` 时执行 | apply --review |
| ⑨ | test-pipeline | lint → unit（两阶段，不含浏览器 E2E） | apply/doit |
| — | **apply 完成点** | 更新 status.json → phase: applied（不提交、不推 PR） | **仅 apply** |
| ⑩ | qa | 编写并执行 qa track 的 Playwright 浏览器功能验收 → phase: qa_passed | qa / doit --qa |
| ⑪ | docs-updater | 总结变更 → 更新文档 + CLAUDE.md iterations 引用 | accept/doit |
| ⑫ | git-committer | branch → commit（**本地，不 push、不建 PR**）→ phase: accepted | accept/doit |
| ⑬ | pr-creator | push → gh pr create → phase: pr_created | pr / doit |

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

# 统一上下文加载（见 references/context-loader.md）：
#   先 ~/.claude/ 再 <project>/.claude/（项目覆盖全局）
#   读取 .claude/.sdlc-config（缺则由 init 从模板生成）
LOAD_CONTEXT()   # 加载规范 + .claude/.sdlc-config

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

#### ② requirements-clarifier
- 逐条分析 confidence：
  - 高(≥0.8): 添加 [✅ 已确认]
  - 中(0.5-0.8): 添加 [⚠️ 假设: ...]；**但有设计影响的假设，交互模式下升级为提问**
  - 低(<0.5):
    - **交互模式**（proposal / mini）：主会话内通过 AskUserQuestion 发起选择询问，用户作答后写入需求并标注 [✅ 已确认（用户选择）]
    - **无人值守模式**（doit）：fallback 为 auto-assume，标注 [⚠️ 假设: ...]，不阻塞
  - 用户跳过/工具不可用 → fallback 为 user-skipped（provenance=asked，已问过即放行）
- **澄清 Gate（§4.7）**：交互模式下进入 ③ 前，凡"会影响设计决策"的项必须 provenance=asked；存在 never-asked 则拦截、回到提问。仅 doit 允许 never-asked。
- 输出：更新后的 requirements.md

#### ③ design-generator
- **前置门禁**：先复核澄清 Gate——交互模式下若存在 never-asked 的设计影响项，停止并回到 ② 澄清，严禁凭未澄清假设直接做设计决策
- 读取：requirements.md（含假设记录）+ .claude/ARCHITECTURE.md + .claude/SECURITY.md + docs/iterations/（历史）
- 被假设驱动的设计决策须登记到 design.md 的「设计假设」小节（关联 ASM-ID + 理由 + 假设错误影响）
- 若为 existing project，额外读取：`.claude/PROJECT_BASELINE.md` + `.claude/EXISTING_STRUCTURE.md` + `.claude/TEST_BASELINE.md`
- 设计必须声明代码落位：默认遵循 Better-T-Stack 风格 `apps/web` / `apps/server` / 条件启用的 `packages/*`
- 若为 existing project，必须明确说明"沿用既有结构"还是"本轮经批准的结构调整"
- 输出：docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/design.md

#### ④ task-generator
- 输入：design.md
- 输出：docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/tasks.md
- **验收标准规则**：
  - 每个任务的 AC 必须引用 requirements.md 中的 AC-ID（如 `AC-001`），不得凭空编写
  - 保留 Given-When-Then 格式和场景维度标注（happy-path / error / boundary / ui-state / security）
  - 补充实现层面的具体判定条件（HTTP 状态码、响应体结构、UI 选择器、数值约束）
  - 每个 Requirement 至少覆盖 happy-path + error 两个维度
  - 禁止退化为模糊 checkbox（如 "功能正常"、"数据正确"）
- 控制台输出：任务分解完成: <任务数> 个任务 | 预估工时: <总工时>

#### ⑤ design-reviewer (Gate 1) — 仅 `--review` 模式

```
IF NOT --review:
  SKIP Gate 1

round=1
WHILE round <= REVIEW_MAX_ROUNDS:
  result=$(codex exec --full-auto "审查设计...
    额外检查第 7 项: AC 覆盖度
    - requirements.md 每个 AC-ID 是否在 tasks.md 被引用
    - tasks.md AC 是否保留 Given-When-Then + 场景维度
    - 是否存在模糊不可验证的 AC
    - 每个 Requirement 是否至少覆盖 happy-path + error")
  IF result == PASS:
    LOG "✅ 设计 Review PASS"
    BREAK
  ELSE:
    IF round < REVIEW_MAX_ROUNDS:
      LOG "⚠️ 设计 Review 第{round}轮: <问题>"
      CLAUDE 修订 design.md + tasks.md
    ELSE:
      LOG "❌ 设计 Review 超过 {N} 轮，需人工介入"
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

  LOG "📋 需求拆解完成，等待人工审核"
  LOG "   📂 迭代目录: $ITER_DIR"
  LOG "   📝 需求数: $REQ_COUNT | 任务数: $TASK_COUNT | 预估工时: ${TOTAL_HOURS}h"
  LOG "   👉 审阅后请运行: /sdlc-workflow apply $ITER_DIR"

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
    LOG "🚀 Proposal 审核通过，开始开发"

  ELSE IF PHASE == "approved":
    LOG "🚀 开始执行需求开发"

  ELSE IF PHASE == "applied":
    ERROR "该 proposal 已执行过 apply"
    ABORT

  ELSE IF PHASE == "rejected":
    ERROR "该 proposal 已被拒绝，请修改后重新 proposal"
    ABORT
```

#### ⑥ Claude Code 开发

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
  LOG "🔨 Agent Team 并行模式: <层数> 层 / <总任务数> 任务"
ELSE:
  MODE = "sequential"
  LOG "🔨 顺序模式: <总任务数> 任务"
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
    # ⚠️ 并行前置条件（任一不满足 → 降级顺序执行该层）：
    #   - 同层任务都**显式且完整声明**了 Target Files（声明不全/缺失的任务不得进并行层）
    #   - 同层任务的目标文件（Target Files）两两无交集
    IF has_file_overlap(layer) OR any(task.target_files is missing/incomplete for task in layer):
      LOG "⚠️ Layer 存在文件交集或 Target Files 声明不全，降级顺序执行"
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

- LOG: 实现完成: <已完成任务数>/<总任务数>

##### ⑥.5 勾选属实自检（默认执行，不依赖 `--review`）

Gate 2 的"状态漂移"检查只在 `--review` 时跑，但"勾选是否属实"是基本一致性，**默认路径也必须自检**
（不调用 Codex，由主 Agent 自查）：

- 逐个已勾选 `[x]` 的任务/AC，确认有对应的代码改动、单元测试或报告支撑
- 发现"任务已勾选但证据不足"或"代码已完成但任务仍 `[ ]`"的漂移 → 回写纠正到真实状态
- 仍无法满足的 AC：取消勾选并在 tasks.md 标注原因，不得带病进入 ⑨ / phase=applied
- LOG: 🔎 勾选属实自检: <核对任务数>，纠正漂移 <N> 处

#### ⑦ test-generator
- 输入：tasks.md + git diff
- **测试用例必须引用 AC-ID 和场景维度**（如 `it('AC-002 (error): 密码错误返回 401')`）
- **仅生成单元测试**；`track: qa` / 验证方式为 qa·playwright-mcp 的 AC 不在此生成，coverage.md 标记 `deferred to qa`（E2E 脚本由 ⑩ qa 命令编写）
- 输出：
  - tests/unit/web|server|packages/...
  - tests/reports/<slug>-coverage.md（含 AC 覆盖率汇总和场景维度覆盖统计，E2E/MCP 项标 deferred to qa）
- LOG: 🧪 单元测试用例已生成

#### ⑧ code-reviewer (Gate 2) — 仅 `--review` 模式

```
IF NOT --review:
  SKIP Gate 2

round=1
WHILE round <= REVIEW_MAX_ROUNDS:
  result=$(codex exec --full-auto "审查代码...")
  IF result == PASS:
    LOG "✅ Code Review PASS"
    BREAK
  ELSE:
    IF round < REVIEW_MAX_ROUNDS:
      LOG "⚠️ Code Review 第{round}轮: <问题>"
      CLAUDE 修复代码
    ELSE:
      LOG "❌ Code Review 超过 {N} 轮，需人工介入"
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
# 浏览器 E2E 不在此处——已独立为 qa 命令（步骤 ⑩）

IF any failure:
  IF round < REVIEW_MAX_ROUNDS:
    LOG "⚠️ 失败用例: <列表>"
    CLAUDE 修复

    # ⑨.1 测试修复后增量文档同步
    IF 修复过程中修改了 design.md 或 tasks.md:
      同步 .claude/ARCHITECTURE.md / .claude/SECURITY.md 受影响章节

    # ⑨.2 上下文检查点
    IF context_usage > 80%:
      执行 /compact
      重新加载: 失败测试报告 + tasks.md + git diff --cached 摘要

    retry
  ELSE:
    LOG "❌ 测试修复超过 {N} 轮，需人工介入"
    ABORT

LOG "✅ 测试通过: <通过数>/<总数>"
```

> **规则**：测试修复阶段如果涉及 design.md 或 tasks.md 变更，必须在 retry 前同步更新 .claude/ARCHITECTURE.md / .claude/SECURITY.md 中受影响的章节。

#### ⑨.3 Apply 完成（仅 apply / doit）
```
# test-pipeline 通过即为 apply 终点——不提交、不推 PR
UPDATE status.json: phase="applied", applied_at=now
LOG "✅ 开发完成: N 个任务 | 测试: lint + unit 全部通过"
LOG "👉 浏览器验收: /sdlc-workflow:qa   👉 提交: /sdlc-workflow:accept"
```

#### ⑩ qa（qa 命令 / doit --qa）
```
# 前置：phase == applied
读取 tasks.md 中 track: qa 的任务
# deferred 闭环：核对 coverage.md 中 "deferred to qa" 的 AC 都有对应 qa 场景，缺失报警
FOR EACH qa 场景:
  编写 Playwright 脚本 → tests/e2e/<slug>/E2E-<nnn>-<scenario>.e2e.ts
  通过 Playwright MCP 执行：navigate → snapshot → click/type → 断言 → 失败截图
执行完毕 teardown 后台 dev server（释放端口）
生成 tests/reports/<slug>-e2e-report.md
IF 全部 PASS: UPDATE status.json: phase="qa_passed"
ELSE: 按根因分流——
  脚本/选择器问题 → qa 内就地修复重跑（≤REVIEW_MAX_ROUNDS），phase 保持 applied
  代码缺陷 → phase 退回 approved（.qa_failed_at=now），提示修复后重跑 apply
  超限 → 中止，输出失败列表 + 截图，人工介入
```

#### ⑪ docs-updater（accept 命令 / doit）
先基于 git diff + tasks.md 完成状态总结本次变更，再按变更更新：
- README.md — 新增功能说明
- .claude/ARCHITECTURE.md — 架构层面变更
- .claude/SECURITY.md — 安全相关变更
- .claude/CODING_GUIDELINES.md — 新模式/约定
- .claude/CLAUDE.md — **更新 iterations 引用列表**

#### ⑫ git-committer（accept 命令 / doit）— 本地提交，不 push、不建 PR
```bash
# 检测是否在 worktree 中
IS_WORKTREE=$(git rev-parse --git-common-dir 2>/dev/null | grep -q '/worktrees/' && echo 1 || echo 0)

IF IS_WORKTREE:
  # Worktree 模式：分支已在 worktree create 时创建，直接复用
  CURRENT_BRANCH=$(git branch --show-current)
  git add -A
  git commit -m "<type>(scope): <摘要>"
ELSE:
  # 传统模式：创建新分支
  git checkout -b ${GIT_BRANCH_PREFIX}<slug>-YYYY-MM-DD
  git add -A
  git commit -m "<type>(scope): <摘要>"
```

#### ⑫.1 Accept 状态更新（accept 命令 / doit）

```
UPDATE status.json: phase="accepted", accepted_at=now
LOG "✅ 已本地提交 | 变更: N files"
LOG "👉 推送并创建 PR: /sdlc-workflow:pr"
```

#### ⑬ pr-creator（pr 命令 / doit）— push + 创建 PR
```bash
# 前置：phase == accepted；当前分支不能是 main/master
CURRENT_BRANCH=$(git branch --show-current)
git push -u origin "$CURRENT_BRANCH"
gh pr create --base main --title "<type>(scope): <摘要>" --body "..."
PR_URL=$(gh pr view --json url --jq .url)
# worktree 模式：同步注册表中的 pr_url（若注册表可达）
```

#### ⑬.1 PR 状态更新与完成输出

```
UPDATE status.json: phase="pr_created", pr_created_at=now, pr_url=<url>
LOG "✅ PR: <url> | 分支: $CURRENT_BRANCH"
```

## 循环与回退规则

| 循环点 | 触发条件 | 回退到 | 最大轮数 | 超限行为 |
|--------|----------|--------|----------|----------|
| Gate 1 (⑤) | Codex 返回 FAIL（--review 时） | 步骤③ design-generator | REVIEW_MAX_ROUNDS | 控制台报错，中止 |
| Gate 2 (⑧) | Codex 返回 FAIL（--review 时） | 步骤⑥ Claude Code 开发 | REVIEW_MAX_ROUNDS | 控制台报错，中止 |
| Test (⑨) | 测试失败 | 步骤⑥ Claude Code 开发 | REVIEW_MAX_ROUNDS | 控制台报错，中止 |

## 全局规则

1. **单 Agent 模式**：所有步骤由一个 Claude Code Agent 执行
2. **双模型把关（可选）**：Claude Code 生成，Codex CLI 审查；`--review` 时启用 Gate 1 + Gate 2
3. **循环上限**：每个 Gate/Test ≤ REVIEW_MAX_ROUNDS（默认 1，--review 时生效）
4. **Conventional Commits**：统一遵循 [Conventional Commits 1.0.0](https://www.conventionalcommits.org/zh-hans/v1.0.0/)，格式 `<type>[scope][!]: description`（type: feat/fix/docs/style/refactor/perf/test/build/ci/chore/revert；破坏性变更加 `!` 或 footer `BREAKING CHANGE:`）。权威定义见 `references/11-git-committer.md`
5. **禁止直推**：所有变更通过 feature branch + PR
6. **安全优先**：禁止在日志中泄露敏感信息
7. **文件隔离**：所有文件操作限项目根目录内
8. **渐进式加载**：SKILL.md ≤500 行，详细规范按需从 references/ 加载
9. **模板不覆盖**：init-project.sh 不覆盖已存在的文件
10. **统一测试目录**：单元测试只能写入 `tests/unit/web|server|packages`，E2E 只能写入 `tests/e2e/`，报告写入 `tests/reports/`
11. **需求到测试唯一映射**：requirements、tasks、E2E 场景必须有唯一 ID 映射，禁止重复覆盖同一需求路径
12. **迭代可追溯**：docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/
13. **审查门禁不可降级**：Codex CLI 不可用时若指定 `--review` 必须中止，不能自动跳过 Gate
14. **全栈目录约束**：默认采用 Better-T-Stack 风格 monorepo，业务代码不应随意落到根目录级 `web/`/`api/`/`server/`
15. **文档统一放置**：ARCHITECTURE.md、SECURITY.md、CODING_GUIDELINES.md 与 CLAUDE.md 统一放在 `.claude/` 目录
16. **proposal 状态管理**：proposal 完成后必须写入 status.json；apply 启动前必须校验 status.json
17. **上下文管理**：Pipeline 步骤间检测上下文占用，超过 80% 时执行 `/compact`。关键检查点：开发前（④→⑥）、测试前（⑦→⑨）、测试修复 retry 前（⑨ 内）。compact 前必须确保当前步骤产物已写入文件，compact 后须经统一上下文加载入口重新加载迭代目录产物 + 全局/项目 `.claude/` 规范
17.1 **统一上下文加载**：所有命令在步骤 ① 前经唯一入口加载规范——先全局 `~/.claude/` 再项目 `<project>/.claude/`（项目覆盖全局）；加载清单与优先级只在 `references/context-loader.md` 定义一次，命令与 reference 不得各自罗列 `.claude/*` 清单
18. **Agent Team 并行**：在步骤 ⑦ test-generator、⑪ docs-updater 使用 Agent Team 并行；⑨ test-pipeline 串行（lint → unit）
19. **Worktree 并行开发**：通过 `worktree create` 创建隔离工作区，每个 worktree 独立运行 pipeline；详见 `references/parallel-dev.md`
20. **Worktree 端口隔离**：并行工作区的 dev server 端口按 `PORT=3000+seq, API_PORT=4000+seq` 分配，避免冲突
21. **Worktree 注册表**：`.worktrees/worktree-registry.json` 记录所有并行工作区元数据，`pr-creator` 完成后更新 `pr_url`
22. **Worktree 文件冲突检测**：创建并行工作区前检查目标文件与已有工作区的交集，存在冲突时警告
23. **五命令分工**：apply 只到 lint + unit（phase: applied，不提交）；`qa` 做 Playwright 浏览器功能验收（phase: qa_passed，可跳过）；`accept` 总结变更 → 更新文档 → 本地 commit（phase: accepted，不 push、不建 PR）；`pr` push + gh pr create（phase: pr_created，唯一远程动作）。doit 自动串联，`--qa` 时含 qa 步骤
24. **Track 拆分**：task-generator 必须将任务按 `track: frontend|backend|unit-test|qa` 拆分；apply 只实现前三类，`track: qa` 的浏览器验收脚本由 `qa` 命令编写执行
