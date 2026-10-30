# <项目名称>

## 项目概述
<!-- 请填写项目简介 -->

## 技术栈
<!-- 请填写项目使用的技术栈 -->

## 目录结构
<!-- 请描述项目目录结构 -->

## 开发约定
- 参考 .agents/ARCHITECTURE.md 了解架构设计
- 参考 .agents/SECURITY.md 了解安全规范
- 参考 .agents/CODING_GUIDELINES.md 了解编码规范
- 若项目为 existing project，先参考 `.agents/PROJECT_BASELINE.md`、`.agents/EXISTING_STRUCTURE.md`、`.agents/TEST_BASELINE.md`
- 提交遵循 Conventional Commits 1.0.0：`<type>[scope][!]: <description>`（type: feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert；破坏性变更加 `!` 或 footer `BREAKING CHANGE:`）
- 默认遵循 Better-T-Stack 风格目录：
  - `apps/web/src` 放 Web 前端代码
  - `apps/server/src` 放后端代码
  - `packages/config` 为基础包
  - `packages/env|api|auth|db|infra|ui` 按能力启用并承载共享逻辑
- 默认不新建根目录级 `web/`、`api/`、`server/` 等目录，除非设计文档明确批准

## 迭代历史

历史迭代记录存放在 `docs/iterations/` 目录下，按日期和需求顺序组织：

```
docs/iterations/
└── YYYY-MM-DD/
    └── <序号>-<需求名>-<变更类型>/
        ├── requirements.md    # 结构化需求
        ├── design.md          # 技术设计
        ├── tasks.md           # 任务分解
        └── status.json        # proposal/apply 状态
```

**在处理新需求时，先阅读 `docs/iterations/` 下最近 `HISTORY_ITER_DEPTH` 个迭代**（默认 2，`0`=全部；见 `.agents/.sdlc-config`）的 requirements.md 与 design.md，了解已有的设计决策、架构变更和业务上下文，避免：
- 与已有设计冲突
- 重复实现已存在的功能
- 引入与历史决策矛盾的方案

**若项目已经有既有技术架构，不得把它当 fresh project 重建目录。** 必须先尊重 baseline，再决定是否需要结构调整。

## SDLC Workflow
本项目使用 sdlc-workflow 技能进行自动化开发。主线：**proposal → apply → qa → accept → pr**
- 首次接入运行 `/sdlc-workflow init`
- 需求拆解运行 `/sdlc-workflow proposal <需求>` → 等待人工审核
- 审核通过后运行 `/sdlc-workflow apply <迭代目录>` → 开发 + 单元测试 + lint（不提交）
- 浏览器验收运行 `/sdlc-workflow qa <迭代目录>`
- 验收提交运行 `/sdlc-workflow accept <迭代目录>` → 更新文档 + 本地 commit
- 推送建 PR 运行 `/sdlc-workflow pr <迭代目录>`
- 全自动模式运行 `/sdlc-workflow doit <需求>`；小任务运行 `/sdlc-workflow mini <需求>`
- 配置见 `.agents/.sdlc-config`

## 自定义 Skills
把项目专属 skill 放到 `.agents/skills/<name>/SKILL.md`（frontmatter 需含 `name` 与 `description`）。SDLC pipeline 会自动发现它们，并在 `description` 与当前阶段相关时**优先调用**（先 skill、后自造）。
- Claude Code：同步脚本自动生成 `.claude/skills/<name>` 软链接，harness 原生发现（软链接需提交）。
- Codex：原生读取 `.agents/skills/`，并由统一上下文加载入口建立索引。
- 想让某 skill 只在特定阶段用，在其 `description` 里点明阶段即可，无需额外配置。

## 目录约定（.agents/ 是唯一事实来源）
- 规则、配置（`.agents/config.json`）、项目 skill、hooks 都放在 `.agents/`；根目录 `AGENTS.md`、`CLAUDE.md` 是指向本文件的软链接。
- `.claude/settings.json`、`.mcp.json`、`.codex/`、`.cursor/mcp.json` 由 sdlc 同步脚本生成并已 gitignore，不要手改；要改 MCP 或平台设置，改 `.agents/config.json`，然后在重启工具前执行 `.agents/bin/sdlc-sync`（任意 sdlc 命令开头也会自动同步）。
- 子目录可放自己的 `AGENTS.md`，同步时会在旁边生成 `CLAUDE.md` 软链接。
