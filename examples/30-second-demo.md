# 上手教程与 30 秒演示

本文分两部分：

- **[全流程使用教程](#全流程使用教程)**：从安装到提 PR，按步骤带你在一个真实项目里跑通一遍。第一次使用、给团队做培训时看这部分。
- **[30 秒演示脚本](#30-秒版本)**：用于 GitHub 推广、录屏、推文或演示会议。

---

## 全流程使用教程

主线五步：**proposal → apply → qa → accept → pr**。每一步都会留下文件和状态，中断后可以接着做。

下文的 `/sdlc-xxx` 是 Claude Code 里的写法。在 Codex 里直接说出意图即可，例如「用 sdlc 跑 proposal：增加导出按钮」。两边用的是同一套 skill。

### 0. 准备

| 需要 | 用途 | 没有会怎样 |
|------|------|------------|
| `git`、`bash`、[jq](https://jqlang.org/)、Node.js | 安装与同步脚本 | 必需 |
| Claude Code 或 Codex | 跑流程的 agent | 必需 |
| [Codex CLI](https://github.com/openai/codex) | `--review` 时的设计审查 / 代码审查 | 不加 `--review` 就用不到 |
| [GitHub CLI](https://cli.github.com/)（已 `gh auth login`） | `pr` 推送并建 PR | 只影响最后一步 |
| Playwright MCP | `qa` 浏览器验收 | 已预置在 `.agents/config.json`，同步后自动生成，一般不用管 |

### 1. 安装（项目级，推荐）

在项目根目录执行：

```bash
npx skills add evan-e2438927/sdlc-workflow --skill '*' -a claude-code -a codex -y
```

会生成：

- `.agents/skills/` —— 12 个 sdlc skill 的实体文件
- `.claude/skills/<name>` —— 指向上面目录的软链接（Claude Code 只从这里发现 skill）
- `skills-lock.json` —— 锁定的版本

> 本机还装了 sdlc 的 Claude Code 插件的话，在这个项目里先用 `/plugin` 把插件停用，避免命令出现两份。
> Windows：clone 前开启开发者模式，并执行 `git config core.symlinks true`，否则软链接会变成文本文件。

### 2. 初始化：`/sdlc-init`

**新开一个** Claude Code 会话（让它发现刚装好的 skill），执行：

```text
/sdlc-init
```

它会：

1. 判断项目类型。空目录是 fresh；已有 `package.json`、`src/`、`apps/` 等就是 existing。
2. 生成 `.agents/`（规则、配置、hooks、同步入口），以及根目录的 `AGENTS.md`、`CLAUDE.md` 软链接。
3. 生成各工具的配置：`.claude/settings.json`、`.mcp.json`、`.codex/`、`.cursor/mcp.json`。这些是生成文件，已经写进 `.gitignore`。
4. **existing 项目**还会读真实代码，生成基线三件套：`PROJECT_BASELINE.md`、`EXISTING_STRUCTURE.md`、`TEST_BASELINE.md`。同时按真实结构填写 `ARCHITECTURE.md` 和 `SECURITY.md`。**这一步别跳过**，它防止 AI 把你现有的目录当成新项目重建。

可选参数，写进 `.agents/.sdlc-config`：

```text
/sdlc-init review=1 branch=feat/ test-framework=vitest lint=eslint
```

然后提交：

```bash
git add AGENTS.md CLAUDE.md .agents .claude/skills .claude/agents skills-lock.json .gitignore
git commit -m "chore: set up sdlc workflow"
```

同事 clone 后不需要额外步骤。第一次执行任意 sdlc 命令时，gitignore 掉的生成文件会自动补齐。

> Codex 用户：第一次在这个项目里用 Codex 时，打开 `/hooks`，信任本项目的 `.codex/hooks.json`。不信任的话，编辑后的 lint 检查不会运行。

### 3. 配置（按需）

| 想改什么 | 改哪里 | 改完要做什么 |
|----------|--------|--------------|
| 项目概述、技术栈、约定 | `.agents/AGENTS.md`（以及 `ARCHITECTURE.md` 等） | 提交 |
| 测试框架、lint 工具、修复轮数、分支前缀 | `.agents/.sdlc-config`（每人一份，不提交） | 无 |
| MCP 服务器、Claude 权限、Codex 的 model 等 | `.agents/config.json` | 执行 `.agents/bin/sdlc-sync`，重启工具，提交 `config.json` |
| 项目自己的 skill | `.agents/skills/<name>/SKILL.md` | 执行 `.agents/bin/sdlc-sync`（会生成 `.claude/skills/` 软链接），提交 |

`.claude/settings.json`、`.mcp.json`、`.codex/config.toml` 这些文件不要手改，每次同步都会整份重写。改 `.agents/config.json` 才算数。例如加一个 MCP 服务器：

```json
"mcpServers": {
  "playwright": { "transport": "stdio", "command": "npx", "args": ["@playwright/mcp@latest"] },
  "docs":       { "transport": "http",  "url": "https://example.com/mcp" }
}
```

```bash
.agents/bin/sdlc-sync            # 重新生成各工具的配置
.agents/bin/sdlc-sync --check    # 只检查，不写入
```

### 4. 拆需求：`/sdlc-proposal`

```text
/sdlc-proposal 给订单页加一个导出 CSV 的按钮
```

需求可以是一段文字、`file:///本地路径`，也可以是 URL（会用浏览器把正文抓下来）。

它会依次做：需求整理 → 澄清 → 设计 → 按 track 拆任务，然后**停下来等你审核**。产物在：

```text
docs/iterations/2026-10-30/001-order-export-feature/
├── requirements.md    # 结构化需求
├── design.md          # 技术设计（含接口契约）
├── tasks.md           # 任务拆分（frontend / backend / unit-test / qa …）
└── status.json        # phase: pending_review
```

**这里是第一个人工确认点。** 打开 `design.md` 和 `tasks.md` 看方案，有意见直接在对话里说，例如「导出的字段再加一个下单时间」。它会原地修改这三份文档，phase 不变。

加 `--review` 会让 Codex CLI 独立审查设计。这一步叫 Gate 1，审查不过会停下，不会静默跳过。

### 5. 开发：`/sdlc-apply`

```text
/sdlc-apply
```

不用写迭代目录，它会自动找最近一个待开发的迭代。它按 `tasks.md` 写代码、补单元测试、跑 lint 和单测，**不提交**。完成后 phase 是 `applied`。

- `--review`：开发完让 Codex CLI 审查代码（Gate 2）。
- `--agents single|multi`：前后端都有任务时，默认（`AGENT_MODE=auto`）用多个角色子 agent 并行开发；也可以指定。
- lint 或单测失败时会自动修，最多修 `REVIEW_MAX_ROUNDS` 轮（默认 1）。修不好就停下来交给你。

### 6. 浏览器验收：`/sdlc-qa`

```text
/sdlc-qa
```

它把 qa track 的验收点写成 Playwright 脚本，在真实浏览器里点一遍，并生成报告：

- `tests/reports/<slug>-e2e-report.md`（提交）
- 截图（gitignore，不进主分支，`pr` 时贴进 PR 描述）

全部通过时 phase 变成 `qa_passed`。发现代码缺陷时变成 `qa_failed`，再执行一次 `/sdlc-apply` 会进入修复模式，修完重新跑 `/sdlc-qa`。

纯后端或文档改动可以跳过 qa，直接 accept。

### 7. 本地提交：`/sdlc-accept`

```text
/sdlc-accept
```

它会总结这次改了什么，更新受影响的文档（`README.md`、`ARCHITECTURE.md`，以及 `AGENTS.md` 里的迭代历史），再按 Conventional Commits **在本地提交**，不 push。顺便检查 `AGENTS.md` 里引用的路径还在不在，失效的会列出来提示，但不阻断提交。

**这里是第二个人工确认点。** 用 `git show` 看一眼这次提交，没问题再往下走。

### 8. 推送并建 PR：`/sdlc-pr`

```text
/sdlc-pr
```

它会 push 当前分支，然后用 `gh pr create` 建 PR，PR 描述里带上需求、设计、测试结果，以及 qa 截图。这是整个流程里唯一和远程交互的一步。完成后 phase 是 `pr_created`。

### 9. 中断、续跑与放弃

- 每个迭代的进度都记在 `status.json` 里。会话断了，新会话里说「继续」或直接执行下一步命令就能接上。
- 想看进度，问它「现在这个迭代到哪一步了」即可。
- 不想做了，说「放弃这个迭代」。phase 会变成 `rejected`，已经写的代码不会回滚。

### 10. 快捷方式

```text
/sdlc-doit --qa 给订单页加导出按钮     # 一口气从 proposal 跑到 pr，不停下来审核
/sdlc-mini 把登录按钮改成绿色          # 小改动的轻量流程；改动变大会自动升级为 doit
/sdlc-review code docs/iterations/2026-10-30/001-order-export-feature/   # 单独跑一次 Codex 代码审查，不触发其他步骤
```

第一次用建议手动分步走，感受每一步的产物和确认点；熟了再用 doit。

### 11. 多个需求并行：`/sdlc-worktree`

```text
/sdlc-worktree create order-export feature
```

它会在主仓库旁边建一个独立工作区 `../wt-001-order-export-feature`，用独立分支，自动分配端口 `PORT=3001`、`API_PORT=4001`，并在里面同步好各工具的配置。进到那个目录开新会话，照常跑 proposal 等命令。

```text
/sdlc-worktree status     # 所有工作区的进度
/sdlc-worktree gc         # 清理已合并的工作区
```

### 12. 升级与同事协作

- **升级 sdlc**：
  ```bash
  npx skills update -p -y
  ```
  如果提示没有可更新的，重新执行一次第 1 步的安装命令也可以。然后执行 `/sdlc-update`，并提交变更。
- **旧项目迁移**：用旧版初始化过的项目（规则还放在 `.claude/` 目录下），执行一次 `/sdlc-update` 就会迁移到 `.agents/`。原文件备份在 `.agents/.backup/<时间戳>/`。迁移报告里如果提示 `git rm --cached`，照做即可。
- **同事拉代码后**：不用做任何事。生成文件有缺失或过期时，下一个 sdlc 命令会自动同步，并告诉你改了什么。

### 13. 常见问题

| 现象 | 处理 |
|------|------|
| Claude Code 里看不到 `/sdlc-*` 命令 | 新开会话；确认 `.claude/skills/` 下是软链接，不是文本文件（Windows 见第 1 步） |
| 命令出现两份 | 本机还装着插件，在这个项目里停用插件 |
| `--check` 报 `conflict` | 软链接的位置上已经有你自己的实体文件（比如 `web/CLAUDE.md`）。sdlc 不会覆盖它，自己决定保留还是删掉 |
| 提示「缺少核心 skill sdlc-workflow」 | 重新执行第 1 步的安装命令 |
| 同步时报缺少 jq | `brew install jq`（或用系统的包管理器安装） |
| Codex 里编辑后没有 lint 检查 | 在 Codex 的 `/hooks` 里信任本项目的 hooks |
| 改了 MCP 但没生效 | 执行 `.agents/bin/sdlc-sync`，然后重启 Claude Code / Codex / Cursor |
| 提示检测到旧布局 | 执行 `/sdlc-update` 迁移 |

### 速查表

| 我想… | 命令 |
|-------|------|
| 接入项目 | `/sdlc-init` |
| 拆需求，等我审核 | `/sdlc-proposal <需求>` |
| 开发 + 单测 + lint | `/sdlc-apply` |
| 浏览器验收 | `/sdlc-qa` |
| 更新文档 + 本地提交 | `/sdlc-accept` |
| 推送并建 PR | `/sdlc-pr` |
| 一口气跑完 | `/sdlc-doit [--qa] <需求>` |
| 小改动 | `/sdlc-mini <描述>` |
| 并行开发 | `/sdlc-worktree create <slug> <type>` |
| 升级 / 迁移旧项目 | `npx skills update -p -y`，然后 `/sdlc-update` |
| 改了 `.agents/config.json` | `.agents/bin/sdlc-sync` |

---

## 30 秒演示脚本

目标不是讲完整实现细节，而是在 30 秒内让别人理解：

1. 这是一个能接入现有项目的 workflow
2. 它不是自由发挥，而是有 gate 和 evidence 的工程流程
3. 它有人工审核门，AI 不会全权决定设计
4. 它最终用浏览器交互证据验收

### Demo Goal

推荐演示场景：

- 选一个 existing project，提前装好（`npx skills add …`，见教程第 1 步）
- 先执行 `init`
- 运行 `proposal` 需求拆解
- 审阅产物后执行 `apply`
- 展示 iteration 产物、status.json、浏览器验收和 git commit

推荐需求：

```text
/sdlc-proposal 增加用户登录模块，支持邮箱和手机号注册
```

这个需求足够展示：

- 需求拆解全流程
- 人工审核暂停点
- 结构约束

如果时间有限，也可以用 mini：

```text
/sdlc-mini 把首页背景改成黑色
```

## 30 秒版本

### 开场一句话

> 这是一个给 Claude Code / Codex 用的 SDLC workflow（两端共用同一套 skill）。它不是直接让模型改代码，而是先拆解需求、等人工审核、再开发。最后用浏览器交互证据做验收。

### 演示步骤

1. 展示仓库目录

说明：

> 这是一个 existing project，不是空项目。workflow 不会先重建架构，而是先接入现有结构。

2. 运行初始化

```text
/sdlc-init review=1
```

说明：

> init 会自动识别这是 existing project，然后生成 baseline 文档和 workflow 配置。规则和配置都放在 `.agents/`，Claude Code、Codex、Cursor 共用一份。

3. 快速展示生成结果

重点展示：

- `.agents/PROJECT_BASELINE.md`
- `.agents/EXISTING_STRUCTURE.md`
- `.agents/TEST_BASELINE.md`

说明：

> 这一步的作用是把现有结构固化成流程真相源，后面模型不能自由发挥打乱它。

4. 运行 proposal 需求拆解

```text
/sdlc-proposal 增加用户登录模块
```

说明：

> proposal 会走完需求采集、澄清、设计、任务分解（加 `--review` 时还有 Gate 1 审查），然后暂停等人工审核。

5. 展示 proposal 产物

重点展示：

```text
docs/iterations/YYYY-MM-DD/001-user-login-feature/
├── requirements.md    # 结构化需求
├── design.md          # 技术设计
├── tasks.md           # 任务分解
└── status.json        # phase: "pending_review"
```

说明：

> 每次需求都有完整的拆解记录。status.json 标记了 pending_review 状态，需要人工审核后才能继续。

6. 审核通过，执行 apply → qa → accept → pr

```text
/sdlc-apply     # 开发 + 单元测试 + lint（不提交）
/sdlc-qa        # Playwright 浏览器功能验收
/sdlc-accept    # 总结变更 → 更新文档 → 本地 commit
/sdlc-pr        # push → 创建 PR
```

说明：

> apply 自动找到最近的 pending proposal，做开发 + 单测 + lint；qa 跑浏览器验收（发现代码缺陷时进入 `qa_failed`，再跑一次 apply 即自动修复）；accept 在本地定稿提交；pr 才推送发布。各阶段独立、可单独重跑。

7. 展示最终验收产物

重点展示：

- `tests/reports/<slug>-e2e-report.md`
- `tests/reports/<slug>/screenshots/`

说明：

> 最终通过不是靠模型说"我改好了"，而是靠 qa 命令通过 Playwright + Playwright MCP 的真实浏览器交互证据。

8. 收尾

说明：

> 这套 workflow 适合 full-stack monorepo，尤其是 existing project 接入、需求拆解审核和 AI 协作交付。

## 60 秒扩展版

如果你有 1 分钟，可以多补三点：

1. Proposal / Apply 分离

说明：

> proposal 做需求拆解（加 `--review` 时到 Gate 1），暂停等人工审核。apply 从审核通过的产物继续开发。doit 是全自动模式，跳过人工审核，一路跑到 PR。

2. 目录 guardrails

说明：

> 它默认约束 `apps/web`、`apps/server`、`packages/*`，不会让模型随便新建根目录 `web/`、`api/`、`server/`。

3. 双模型 gate

说明：

> Claude 负责生成，Codex CLI 负责 Gate 1 和 Gate 2 审查（`--review` 开启）。gate 失败不能静默跳过。
