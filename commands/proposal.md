---
description: 需求拆解（①-④）产出 proposal，暂停等待人工审核
argument-hint: <需求描述> | file:///path/to/req.md | https://jira.xxx/PROJ-123 [--review]
---

执行 `sdlc-workflow proposal`，参数：$ARGUMENTS

读取并遵循 `${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/SKILL.md` 中的完整规范。当前执行 **proposal** 模式（步骤 ⓪→①→②→③→④→[⑤]→暂停）。

## 执行步骤

**⓪ 初始化 + 统一上下文加载**：检测 fresh/existing 项目（未初始化则回退 `init`）→ 执行统一上下文加载（全局 `~/.claude/` → 项目 `.claude/`，项目覆盖；详见 `${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/references/context-loader.md`）→ 创建迭代目录 `docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/`。

**① requirements-ingestion**：识别输入类型（文本/file:///URL）→ 提取需求 → 按 5 个维度生成 AC（happy-path / error / boundary / ui-state / security）→ 输出 `requirements.md`。

**② requirements-clarifier**：逐条分析 confidence，低置信度项（及有设计影响的中置信度项）通过 AskUserQuestion 询问用户，更新 `requirements.md`。**澄清 Gate**：交互模式下，凡"会影响设计决策"的项必须真正问过（provenance=asked）才能进入 ③——"从未提问"（never-asked）一律拦截，不得静默假设后直接设计。

**③ design-generator**：**先复核澄清 Gate**（存在 never-asked 的设计影响项则回到 ② 澄清），再读取 requirements.md + .claude/ARCHITECTURE.md → 生成 `design.md`；被假设驱动的设计决策须登记到「设计假设」小节。

**④ task-generator**：design.md → `tasks.md`。

任务必须按 **Track** 分组拆分：

| Track | 内容 | 执行阶段 |
|-------|------|----------|
| `frontend` | 页面、组件、路由、UI 状态 | apply |
| `backend` | API、业务逻辑、数据库、中间件 | apply |
| `unit-test` | 前后端单元测试用例 | apply |
| `qa` | 浏览器自动化验收脚本规格（Given-When-Then + 选择器约束） | qa 命令 |

规则：
- 每个任务标注 `track:` 字段
- 任务 AC 必须引用 requirements.md 中的 AC-ID，保留 Given-When-Then 格式
- `qa` track 任务只写验收规格（测试场景描述），不写实现代码
- `unit-test` track 任务聚焦逻辑单元，不包含浏览器操作

**[⑤ Gate 1]**（仅 `--review`）：Codex CLI 审查设计，失败则修订，超过 REVIEW_MAX_ROUNDS 轮中止。

**暂停**：写入 `status.json`（phase: "pending_review"），输出：
```
📋 需求拆解完成，等待人工审核
   📂 迭代目录: docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/
   📝 需求数: N | 任务数: N | 预估工时: Nh
   👉 审阅后请运行: /sdlc-workflow:apply <迭代目录>
```
