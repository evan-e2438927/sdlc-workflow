# 30-Second Demo Script

这个文档用于 GitHub 推广、录屏、推文或演示会议。目标不是讲完整实现细节，而是在 30 秒内让别人理解：

1. 这是一个能接入现有项目的 workflow
2. 它不是自由发挥，而是有 gate 和 evidence 的工程流程
3. 它有人工审核门，AI 不会全权决定设计
4. 它最终用浏览器交互证据验收

## Demo Goal

推荐演示场景：

- 选一个 existing project
- 先执行 `init`
- 运行 `proposal` 需求拆解
- 审阅产物后执行 `apply`
- 展示 iteration 产物、status.json、浏览器验收和 git commit

推荐需求：

```text
sdlc-proposal 增加用户登录模块，支持邮箱和手机号注册
```

这个需求足够展示：

- 需求拆解全流程
- 人工审核暂停点
- 结构约束

如果时间有限，也可以用 mini：

```text
sdlc-mini 把首页背景改成黑色
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
sdlc-init "review=1"
```

说明：

> init 会自动识别这是 existing project，然后生成 baseline 文档和 workflow 配置。

3. 快速展示生成结果

重点展示：

- `.claude/PROJECT_BASELINE.md`
- `.claude/EXISTING_STRUCTURE.md`
- `.claude/TEST_BASELINE.md`

说明：

> 这一步的作用是把现有结构固化成流程真相源，后面模型不能自由发挥打乱它。

4. 运行 proposal 需求拆解

```text
sdlc-proposal 增加用户登录模块
```

说明：

> proposal 会走完需求采集、澄清、设计、任务分解和 Gate 1 审查，然后暂停等人工审核。

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
sdlc-apply     # 开发 + 单元测试 + lint（不提交）
sdlc-qa        # Playwright 浏览器功能验收
sdlc-accept    # 总结变更 → 更新文档 → 本地 commit
sdlc-pr        # push → 创建 PR
```

说明：

> apply 自动找到最近的 pending proposal，做开发 + 单测 + lint；qa 跑浏览器验收；accept 在本地定稿提交；pr 才推送发布。各阶段独立、可单独重跑。

7. 展示最终验收产物

重点展示：

- `tests/reports/<slug>-e2e-report.md`
- `tests/reports/<slug>/screenshots/`

说明：

> 最终通过不是靠模型说"我改好了"，而是靠 qa 命令通过 Playwright + Playwright MCP 的真实浏览器交互证据。

8. 收尾

说明：

> 这套 workflow 适合 full-stack monorepo，尤其是 existing project 接入、需求拆解审核和 AI 协作交付。

## 60-Second Expanded Version

如果你有 1 分钟，可以多补三点：

1. Proposal / Apply 分离

说明：

> proposal 做需求拆解到 Gate 1，暂停等人工审核。apply 从审核通过的产物继续开发到 PR。doit 是全自动模式，跳过人工审核。

2. 目录 guardrails

说明：

> 它默认约束 `apps/web`、`apps/server`、`packages/*`，不会让模型随便新建根目录 `web/`、`api/`、`server/`。

3. 双模型 gate

说明：

> Claude 负责生成，Codex CLI 负责 Gate 1 和 Gate 2 审查。gate 失败不能静默跳过。
