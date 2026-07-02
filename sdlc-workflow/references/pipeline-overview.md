# Pipeline 概览：五命令 SDLC 流程（proposal → apply → qa → accept → pr）

## 0. 主线总览

```
proposal ──→ apply ──→ qa ──→ accept ──→ pr
  ①-⑤        ⑥-⑨      ⑩      ⑪⑫        ⑬
拆解+暂停    开发+单测  浏览器验收  文档+本地commit  push+PR
pending_     applied   qa_passed  accepted     pr_created
review
```

| 命令 | 职责 | 不做什么 | phase 产出 |
|------|------|----------|-----------|
| `proposal` | 需求拆解，产出 requirements/design/tasks（按 track 拆分），暂停待审 | 不写代码 | pending_review |
| `apply` | 实现 frontend/backend/unit-test track + 单元测试 + lint | 不做浏览器测试、不提交、不推 PR | applied |
| `qa` | 编写并执行 qa track 的 Playwright 浏览器功能验收 | 不写业务代码、不提交 | qa_passed |
| `accept` | 总结变更 → 更新文档 → 本地 commit | 不写业务代码、不做功能测试、不 push、不建 PR | accepted |
| `pr` | push 当前分支 → gh pr create | 不写代码、不改文档（唯一远程动作） | pr_created |

所有命令在执行前经**统一上下文加载入口**（全局 `~/.claude/` → 项目 `.claude/`，项目覆盖），
见 `references/context-loader.md`。

`doit` = 上述五步全自动串联（`--qa` 时含 qa）；`mini` = 轻量串联；`review` = 单独跑 Codex Gate。

## 1. 流程图

```mermaid
graph TD
    START["/sdlc-workflow <input>"] --> CMD{命令类型?}
    CMD -->|init| INIT_RUN["运行 init-project.sh"]
    CMD -->|proposal| PROPOSAL_FLOW
    CMD -->|apply| APPLY_FLOW
    CMD -->|qa| QA_FLOW
    CMD -->|accept| ACCEPT_FLOW
    CMD -->|pr| PR_FLOW
    CMD -->|doit| DOIT_FLOW
    CMD -->|mini| MINI_FLOW["mini-pipeline"]

    subgraph PROPOSAL_FLOW [proposal 流程]
      P_INIT{项目已初始化?}
      P_INIT -->|否| P_INIT_RUN["运行 init-project.sh"]
      P_INIT_RUN --> P_MODE{"fresh 还是 existing?"}
      P_INIT -->|是| P_MODE

      P_MODE -->|fresh| P_SLUG
      P_MODE -->|existing| P_INTAKE["existing-project-intake<br/>→ PROJECT_BASELINE / EXISTING_STRUCTURE / TEST_BASELINE"]
      P_INTAKE --> P_SLUG

      P_SLUG["生成迭代目录<br/>docs/iterations/YYYY-MM-DD/001-slug-type/"]
      P_SLUG --> P_ROUTE{输入类型路由}
      P_ROUTE -->|文本| P_C1[直接解析]
      P_ROUTE -->|"file://"| P_C2[读取文件]
      P_ROUTE -->|URL| P_C3["Playwright MCP 提取"]

      P_C1 --> P_S1
      P_C2 --> P_S1
      P_C3 --> P_S1

      P_S1["① requirements-ingestion<br/>→ requirements.md"]
      P_S1 --> P_S2["② requirements-clarifier<br/>交互式选择询问"]
      P_S2 -->|低置信度 · proposal/mini| P_ASK["💬 主会话：AskUserQuestion 选择询问"]
      P_S2 -->|低置信度 · doit| P_AUTO["⚠️ 无人值守：auto-assume fallback"]
      P_ASK --> P_S3["③ design-generator<br/>→ design.md"]
      P_AUTO --> P_S3

      P_S3 --> P_S4["④ task-generator<br/>→ tasks.md"]

      P_S4 -->|默认| P_STATUS
      P_S4 -->|"--review"| P_S5["⑤ design-reviewer · Gate 1<br/>Codex CLI 审查设计（可选）"]
      P_S5 -->|FAIL & round ≤ N| P_S3
      P_S5 -->|PASS 经修订| P_S5_1["⑤.1 增量文档同步<br/>ARCHITECTURE / SECURITY"]
      P_S5 -->|PASS 首轮通过| P_STATUS
      P_S5 -->|"FAIL & round > N"| P_ESCALATE["❌ 需人工介入 → 中止"]
      P_S5_1 --> P_STATUS

      P_STATUS["写入 status.json<br/>phase: pending_review"]
      P_STATUS --> P_END["⏸ 暂停，等待 apply"]
    end

    subgraph APPLY_FLOW [apply 流程]
      A_CHECK["读取 status.json<br/>校验 phase"]
      A_CHECK -->|approved / pending_review| A_S6_DEP["⑥.1 依赖分析 + 拓扑分层"]
      A_CHECK -->|rejected / applied| A_ABORT["❌ 中止"]

      A_S6_DEP --> A_S6_MODE{"并行层 > 1 且任务 ≥ 3?"}
      A_S6_MODE -->|是| A_S6_TEAM["⑥.3b Agent Team 并行<br/>按层分发子 Agent"]
      A_S6_MODE -->|否| A_S6_SEQ["⑥.3a 顺序逐任务开发"]
      A_S6_TEAM --> A_S6["⑥.4 tasks.md 回写"]
      A_S6_SEQ --> A_S6["⑥.4 tasks.md 回写"]

      A_S6 --> A_S7["⑦ test-generator<br/>→ tests/unit/（仅单元测试）"]
      A_S7 -->|默认| A_S9
      A_S7 -->|"--review"| A_S8["⑧ code-reviewer · Gate 2<br/>Codex CLI 审查代码（可选）"]
      A_S8 -->|FAIL & round ≤ N| A_S6
      A_S8 -->|PASS| A_S9["⑨ test-pipeline<br/>lint → unit（两阶段）"]
      A_S8 -->|"FAIL & round > N"| A_ESCALATE["❌ 需人工介入 → 中止"]

      A_S9 -->|失败 & round ≤ N| A_S9_1{"修复涉及<br/>design/tasks 变更?"}
      A_S9_1 -->|是| A_S9_SYNC["⑨.1 增量文档同步"] --> A_S6
      A_S9_1 -->|否| A_S6
      A_S9 -->|全部通过| A_STATUS["更新 status.json<br/>phase: applied"]
      A_S9 -->|"失败 & round > N"| A_ESCALATE
    end

    subgraph QA_FLOW [qa 浏览器功能验收]
      Q_CHECK["校验 phase == applied"]
      Q_CHECK --> Q_WRITE["⑩.1 读 qa track 任务<br/>编写 Playwright 脚本 → tests/e2e/"]
      Q_WRITE --> Q_RUN["⑩.2 Playwright MCP 执行<br/>navigate → snapshot → click → screenshot"]
      Q_RUN --> Q_REPORT["⑩.3 生成 e2e 报告"]
      Q_REPORT -->|全部 PASS| Q_OK["更新 status.json<br/>phase: qa_passed"]
      Q_REPORT -->|有 FAIL| Q_FAIL["记录失败，建议修复后重跑 apply"]
    end

    subgraph ACCEPT_FLOW [accept 验收提交流程（本地）]
      AC_CHECK["校验 phase == qa_passed / applied"]
      AC_CHECK --> AC_SUM["变更总结<br/>git diff + tasks.md"]
      AC_SUM --> AC_S11["⑪ docs-updater<br/>更新受影响文档"]
      AC_S11 --> AC_S12["⑫ git-committer<br/>branch → commit（本地，不 push）"]
      AC_S12 --> AC_OK["更新 status.json<br/>phase: accepted"]
    end

    subgraph PR_FLOW [pr 推送并创建 PR]
      PR_CHECK["校验 phase == accepted<br/>且分支非 main/master"]
      PR_CHECK --> PR_PUSH["⑬.1 git push -u origin <branch>"]
      PR_PUSH --> PR_CREATE["⑬.2 gh pr create --base main"]
      PR_CREATE --> PR_OK["更新 status.json<br/>phase: pr_created + pr_url"]
    end

    subgraph DOIT_FLOW [doit 全自动流程]
      D_NOTE["内部串联 proposal + apply + (qa) + accept + pr<br/>不暂停，不等待人工审核"]
    end
```

## 2. 命令入口映射

| 命令 | 说明 | 执行范围 | phase |
|------|------|----------|--------|
| `init` | 初始化项目 | ⓪ | — |
| `update` | 插件升级后同步脚手架到已初始化项目（幂等，不覆盖用户内容） | — | — |
| `proposal [--review]` | 需求拆解（按 track）；`--review` 时执行 Gate 1 | ①②③④[⑤] | → pending_review（暂停） |
| `apply [--review]` | 开发 + 单元测试 + lint；`--review` 时执行 Gate 2 | ⑥⑦[⑧]⑨ | → applied |
| `qa` | 编写并执行 Playwright 浏览器功能验收 | ⑩ | → qa_passed |
| `accept` | 总结变更 → 更新文档 → 本地 commit | ⑪⑫ | → accepted |
| `pr` | push → gh pr create | ⑬ | → pr_created |
| `review proposal\|code` | 单独运行 Codex 审查 | ⑤ 或 ⑧ | — |
| `doit [--review] [--qa]` | 全自动（proposal + apply + [qa] + accept + pr） | ①-⑬ | 不暂停 |
| `mini [--review] [--qa]` | 小任务轻量流程 | 参见 flow-mini.md | — |

## 3. 步骤详解表

| 步骤 | 名称 | Pattern | 输入 | 输出 | 工具 | 命令归属 |
|------|------|---------|------|------|------|----------|
| ⓪ | 初始化 + 模式识别 | — | 项目目录 | 初始化结构 + existing baseline | init-project.sh + existing-project-intake | proposal/doit |
| ① | requirements-ingestion | Router + Tool Wrapper | 文本/file/URL | requirements.md | Read + Playwright MCP | proposal/doit |
| ② | requirements-clarifier | Evaluator | requirements.md | requirements.md (标注版) | Claude Code 内置 | proposal/doit |
| ③ | design-generator | Generator | requirements.md + .claude/ARCHITECTURE.md + .claude/SECURITY.md + 历史 | design.md | Claude Code | proposal/doit |
| ④ | task-generator | Generator | design.md | tasks.md | Claude Code | proposal/doit |
| [⑤] | design-reviewer | Evaluator-Optimizer | design.md + tasks.md | PASS/FAIL | Codex CLI | proposal --review |
| [⑤.1] | 增量文档同步 | Tool Wrapper | design.md 修订 diff | 更新后的 ARCHITECTURE/SECURITY | Claude Code | proposal --review |
| — | **status.json 写入** | — | proposal 摘要 | status.json (pending_review) | — | **仅 proposal** |
| ⑥ | Claude Code 开发 | Orchestrator-Workers | tasks.md（frontend/backend/unit-test track，依赖分析→拓扑分层） | 代码变更 | Claude Code + Agent Team（并行层） | apply/doit |
| ⑦ | test-generator | Generator | tasks.md（unit-test track） | tests/unit/ | Claude Code | apply/doit |
| [⑧] | code-reviewer | Evaluator-Optimizer | git diff + .claude/CODING_GUIDELINES.md + .claude/SECURITY.md | PASS/FAIL | Codex CLI | apply --review |
| ⑨ | test-pipeline | Pipeline | tests/unit/ | tests/reports/ | Lint → Unit（两阶段） | apply/doit |
| ⑨.1 | 测试修复文档同步 | Tool Wrapper | design.md/tasks.md 修复 diff | 更新后的 ARCHITECTURE/SECURITY | Claude Code | apply/doit |
| ⑩ | qa（浏览器功能验收） | Generator + Tool Wrapper | tasks.md（qa track） | tests/e2e/ + tests/reports/<slug>-e2e-report.md | Playwright（脚本 + MCP） | qa / doit --qa |
| ⑪ | docs-updater | Tool Wrapper | 变更总结 + 迭代产物 | 更新后的文档 | Claude Code | accept/doit |
| ⑫ | git-committer | Tool Wrapper | 所有变更 | 本地 commit | Git | accept/doit |
| ⑬ | pr-creator | Tool Wrapper | 本地 commit + 迭代产物 | 远程分支 + PR URL | Git + GitHub CLI | pr/doit |

## 4. Google Cloud 5 Agent Pattern 映射

| Pattern | 体现 |
|---------|------|
| **Sequential Chain** | 五命令 proposal → apply → qa → accept → pr 顺序串联 |
| **Routing** | 步骤① 根据输入类型（文本/文件/URL）路由到不同提取策略 |
| **Parallelization** | 步骤⑥ Agent Team 按拓扑层并行开发 |
| **Orchestrator-Workers** | SKILL.md = Orchestrator；references/ 各步骤规范 = Workers |
| **Evaluator-Optimizer** | design-reviewer + code-reviewer + test-pipeline 三处评估-优化循环 |

对 existing project，还增加一个前置基线模式：

- existing-project-intake：先确认现有结构和约束，再允许进入需求与设计

## 5. 双模型把关架构

```
Claude Code (生成)                  Codex CLI (审查)
━━━━━━━━━━━━━━━━━                  ━━━━━━━━━━━━━━━━
design.md + tasks.md  ──────→  🔍 Gate 1: design-reviewer
                                (可行性/安全/架构/完整性)
                                     ├─ PASS → proposal 暂停 / doit 继续开发
                                     └─ FAIL → Claude Code 修订 → 重审 (≤N轮)

git diff (代码变更)   ──────→  🔍 Gate 2: code-reviewer
                                (质量/安全漏洞/编码规范)
                                     ├─ PASS → 进入测试
                                     └─ FAIL → Claude Code 修复 → 重审 (≤N轮)
```

## 6. 两层架构

```
┌─────────────────────────────────────────────────────────┐
│  用户级（安装一次，永久可用）                               │
│  ~/.agents/skills/sdlc-workflow/                         │
│  ├── SKILL.md                                           │
│  ├── references/       ← 步骤详细规范                    │
│  │   ├── context-loader.md ← 统一上下文加载入口          │
│  │   ├── flow-proposal.md  ← 需求拆解流程                │
│  │   ├── flow-apply.md     ← 开发流程                    │
│  │   ├── flow-qa.md        ← 浏览器功能验收流程          │
│  │   ├── flow-accept.md    ← 验收提交流程（本地）        │
│  │   └── 00..12-*.md       ← 各步骤规范（含 12-pr-creator）│
│  ├── templates/        ← 6 个项目初始化模板               │
│  └── scripts/          ← init-project.sh                │
└──────────────────────┬──────────────────────────────────┘
                       │ 首次运行 /sdlc-workflow 时自动生成 ↓
┌──────────────────────▼──────────────────────────────────┐
│  项目级（每个项目独立，从模板生成）                          │
│  your-project/                                          │
│  ├── .claude/                                           │
│  │   ├── CLAUDE.md                                      │
│  │   ├── ARCHITECTURE.md                                │
│  │   ├── SECURITY.md                                    │
│  │   ├── CODING_GUIDELINES.md                           │
│  │   ├── PROJECT_BASELINE.md    ← existing project       │
│  │   ├── EXISTING_STRUCTURE.md                           │
│  │   ├── TEST_BASELINE.md                                │
│  │   ├── .sdlc-config           ← 配置（gitignored）     │
│  │   └── rules/                                         │
│  │       └── workflow-rules.md                           │
│  ├── docs/                                              │
│  │   └── iterations/                                    │
│  │       └── YYYY-MM-DD/                                │
│  │           └── <seq>-<slug>-<type>/                   │
│  │               ├── requirements.md                     │
│  │               ├── design.md                           │
│  │               ├── tasks.md                            │
│  │               └── status.json                         │
│  ├── apps/                                               │
│  │   ├── web/                                            │
│  │   ├── server/                                         │
│  │   └── native/                                         │
│  ├── packages/                                           │
│  │   ├── config/                                         │
│  │   ├── env/                                            │
│  │   ├── api/                                            │
│  │   ├── auth/                                           │
│  │   ├── db/                                             │
│  │   ├── infra/                                          │
│  │   └── ui/                                             │
│  ├── tests/                                              │
│  │   ├── unit/web/                                      │
│  │   ├── unit/server/                                   │
│  │   ├── unit/packages/                                 │
│  │   ├── e2e/                                           │
│  │   └── reports/playwright/                                │
│  └── (配置见 .claude/.sdlc-config)                       │
└─────────────────────────────────────────────────────────┘
```

## 7. 关键设计决策

### 7.0 Existing Project Intake
- existing project 不能被当成 fresh project 直接套模板
- existing project mode 必须先产出：
  - `.claude/PROJECT_BASELINE.md`
  - `.claude/EXISTING_STRUCTURE.md`
  - `.claude/TEST_BASELINE.md`
- 后续 requirements / design / tasks 必须基于 intake 结论，而不是模型猜测
- 只有在 `design.md` 明确批准时，才允许调整既有技术架构

### 7.1 统一测试目录
- 取消 `specs/` 目录，v6 中 specs/ 和 tests/ 职责重叠
- v7 统一为 `tests/`
- v8 进一步要求单元测试镜像 workspace 目录，不得写回源码目录
- 测试报告统一写入 `tests/reports/`，其中浏览器验证证据写入 `tests/reports/playwright/`；qa 通过截图写入迭代目录 `docs/iterations/<迭代>/evidence/`

### 7.2 迭代目录命名
- v6 扁平 `YYYY-MM-DD/` 结构导致同日多需求冲突
- v7 改为 `YYYY-MM-DD/<slug>-<type>/` 支持同日多需求并行
- v8 再补 `<seq>`，形成 `YYYY-MM-DD/<seq>-<slug>-<type>/`，显式记录同日执行顺序

### 7.3 CLAUDE.md 引入 iterations
- 使 Claude 在后续交互中可自动读取历史迭代上下文
- 避免重复设计和冲突方案

### 7.4 qa / accept / pr 三段分离
- `qa`：apply 完成后运行，编写并执行 qa track 的 Playwright 浏览器功能验收，
  产出 e2e 报告，通过后 `phase: qa_passed`
- `accept`：qa 通过（或跳过 qa）后运行，总结变更 → 更新文档 → **本地 commit**，
  完成后 `phase: accepted`（不 push、不建 PR）
- `pr`：accept 完成后运行，`git push` + `gh pr create`，完成后 `phase: pr_created`
- 浏览器测试（qa）、本地定稿（accept）、远程发布（pr）是三件事，各自独立成命令，
  其中 `pr` 是唯一与远程 / GitHub 交互的动作

### 7.8 统一上下文加载
- 规范来源（全局 `~/.claude/` + 项目 `<project>/.claude/`）与合并优先级（项目覆盖全局）
  只在 `references/context-loader.md` 定义一次
- 所有命令在步骤 ① 前经此单一入口加载，命令与各 reference 不再各自罗列 `.claude/*` 清单

### 7.5 全栈目录约束
- 默认遵循 Better-T-Stack 风格 monorepo：`apps/web`、`apps/server`、`packages/*`
- Web 代码默认进入 `apps/web/src/`
- 后端代码默认进入 `apps/server/src/`
- `packages/config` 始终存在；`packages/env`、`api`、`auth`、`db`、`infra`、`ui` 按所选能力启用
- 共享逻辑默认进入 `packages/*`
- 默认不接受新增根目录级 `web/`、`api/`、`server/`

### 7.6 Proposal / Apply 分离
- 参考 OpenSpec 模式，将需求拆解与需求开发分离
- `proposal` 产出 requirements.md + design.md + tasks.md + status.json
- 中间插入人工审核环节，避免 AI 自行决定所有设计决策
- `apply` 从审核通过的 proposal 产物继续执行开发
- `doit` 保留为全自动模式（内部自动完成 proposal + apply）

### 7.7 文档放置
- ARCHITECTURE.md、SECURITY.md、CODING_GUIDELINES.md 与 CLAUDE.md 统一放在 `.claude/` 目录
- `docs/` 目录仅保留迭代产物和 existing project baseline
- 减少文件分散，使 Claude 上下文加载更集中

## 8. 配置

所有配置统一放在 `.claude/.sdlc-config`（KEY=VALUE，gitignored；全局默认可放
`~/.claude/.sdlc-config`，项目级覆盖全局）。由统一上下文加载入口读取，见
`references/context-loader.md`。

| 变量 | 默认值 | 说明 |
|------|--------|------|
| TEST_FRAMEWORK | jest | 单元测试框架（jest/vitest/mocha） |
| E2E_FRAMEWORK | playwright | 固定 E2E 框架（qa 命令用） |
| LINT_TOOL | eslint | Lint 工具（eslint/biome） |
| TEST_BOOTSTRAP_POLICY | report | 测试基础设施缺口处理（report/auto/never） |
| REVIEW_MAX_ROUNDS | 1 | Codex 审查最大轮数（`--review` 时生效） |
| GIT_BRANCH_PREFIX | feat/ | Git 分支前缀 |
| COMMIT_TYPE | (空) | Conventional Commits type（留空按迭代 type 推断） |
| COMMIT_SCOPE | (空) | Conventional Commits scope（留空自动推断） |
| PR_TEMPLATE | (空) | 自定义 PR body 模板路径 |
