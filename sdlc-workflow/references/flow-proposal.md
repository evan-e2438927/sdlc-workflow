# Proposal — 需求拆解命令

## 概述

`/sdlc-workflow proposal <需求>` 执行需求采集、澄清、设计、任务分解和 Gate 1 审查，
产出完整的 proposal 产物后**暂停**，等待人工审核。

与 `doit` 的区别：`doit` 在 Gate 1 通过后自动继续开发；`proposal` 在此处停下来，
直到用户通过 `/sdlc-workflow apply <迭代目录>` 显式触发后续开发流程。

## 入口

```
/sdlc-workflow proposal <需求>
```

参数与 `doit` 相同，接受三种格式：

| 格式 | 示例 |
|------|------|
| 纯文本 | `proposal 创建一个用户登录模块` |
| file:// 路径 | `proposal file:///path/to/requirements.txt` |
| URL | `proposal https://jira.company.com/browse/PROJ-123` |

## 执行步骤

```
⓪ 初始化检查
   IF NOT (.claude/CLAUDE.md AND .claude/ARCHITECTURE.md):
     RUN init-project.sh
   IF MODE == existing:
     RUN existing-project-intake (若 baseline 不存在)

① requirements-ingestion
   → docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/requirements.md

② requirements-clarifier
   → 标注版 requirements.md
   ※ proposal 模式下，对低置信度需求会**在主会话内通过 AskUserQuestion 发起选择询问**
     详见 references/02-requirements-clarifier.md §4。

③ design-generator
   → docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/design.md

④ task-generator
   → docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/tasks.md

[⑤ design-reviewer (Gate 1)   ← 仅 --review 模式]
   循环审查，最大 REVIEW_MAX_ROUNDS 轮

[⑤.1 增量文档同步              ← 仅 --review 且经修订]
   同步影响到的 .claude/ARCHITECTURE.md / .claude/SECURITY.md 等

⑥ 写入 phase（经状态脚本，见 SKILL.md「迭代状态（phase）」）
   "$SDLC_STATUS" transition "$ITER_DIR" pending_review --by proposal
   随后用 jq 补 summary（进度字段）

⑦ 控制台输出: 需求拆解完成，等待人工审核

⏸ 停止
```

## status.json 写入规范

Proposal 完成后由状态脚本创建 `status.json`（`phase` / `proposal_at` / `mode` / `iter_dir` / `history`），
再由 agent 用 jq 补 `summary`。结果形如：

```json
{
  "phase": "pending_review",
  "proposal_at": "2026-04-13T14:00:00+08:00",
  "reviewed_at": null,
  "applied_at": null,
  "reviewer": null,
  "iter_dir": "docs/iterations/2026-04-13/001-user-login-feature",
  "mode": "proposal",
  "history": [
    { "at": "2026-04-13T14:00:00+08:00", "from": null, "to": "pending_review", "by": "proposal" }
  ],
  "summary": {
    "requirement_count": 3,
    "task_count": 7,
    "estimated_hours": 18
  }
}
```

### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| phase | string | 取值与迁移见 SKILL.md「迭代状态（phase）」；只能经 `"$SDLC_STATUS" transition` 写入 |
| mode | string | `proposal` / `doit` / `mini`，创建时写入 |
| flags | object | 仅 doit / mini：`review` / `qa` / `agents`，供中断后续跑 |
| history | array | 迁移记录 `{at, from, to, by, note?}`，只追加 |
| proposal_at | ISO8601 | proposal 完成时间 |
| reviewed_at | ISO8601 \| null | 人工审核时间 |
| applied_at | ISO8601 \| null | apply 执行时间 |
| reviewer | string \| null | 审核人（可选） |
| iter_dir | string | 迭代目录相对路径 |
| summary.requirement_count | number | 需求数量 |
| summary.task_count | number | 任务数量 |
| summary.estimated_hours | number | 预估总工时 |

### Summary 提取方式

```bash
# 从 requirements.md 提取需求数
REQ_COUNT=$(grep -c "^### " "$ITER_DIR/requirements.md" || echo 0)

# 从 tasks.md 提取任务数/总工时
TASK_COUNT=$(grep -c "^### \[" "$ITER_DIR/tasks.md" || echo 0)
TOTAL_HOURS=$(grep -oP '预估工时: \K[0-9]+' "$ITER_DIR/tasks.md" | awk '{s+=$1}END{print s}')
```

## 控制台输出

### Proposal 完成

```
📋 需求拆解完成，等待人工审核

📂 迭代目录: docs/iterations/<date>/<seq>-<slug>-<type>/
📝 需求数: <N> | 任务数: <N> | 预估工时: <N>h

📄 产物清单:
  ├── requirements.md  (需求文档)
  ├── design.md        (技术设计)
  ├── tasks.md         (任务分解)
  └── status.json      (状态: pending_review)

👉 审阅后请运行: /sdlc-workflow apply <迭代目录>
```

## 审核期间的修改（对话）

phase 为 `pending_review` 时，用户在对话里提出修改意见（如「去掉手机号登录；锁定改成 5 次」），不需要任何命令：

1. 定位迭代：本会话刚产出的迭代；新会话里用 `"$SDLC_STATUS" find-latest pending_review`，有多个候选时先问用户。
2. 在同一迭代目录原地修改，**三份文档联动**：
   - 改需求 → 同步 requirements.md 的 AC，以及 design.md / tasks.md 中引用这些 AC-ID 的设计与任务
   - 改设计 → 同步 tasks.md 的 Track、目标文件、依赖与「接口契约」引用
   - 不得只改其中一份；新增 / 删除的 AC-ID 在 tasks.md 中的引用必须随之增删
3. 涉及设计决策的新疑点，按 ② requirements-clarifier 的澄清 Gate 先问再改。
4. 带 `--review` 跑过 Gate 1 的迭代，修改后重跑 Gate 1（按「修复轮数（唯一定义）」）。
5. phase 保持 `pending_review`，重新输出产物摘要并再次停下，等用户确认或 apply。

`approved` 之后不再原地修改设计：需要改时，经用户同意 `transition … rejected --by user` 后重新 proposal。

## 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| 项目未初始化 | 自动执行 init-project.sh |
| 需求采集失败 | 中止，控制台输出错误 |
| Gate 1 超限（--review 时） | 中止，提示人工介入 |
| status.json 写入失败 | 中止并输出脚本报错（状态脚本是唯一写入方，失败即状态不可信） |

## 流程中的位置

```
proposal → apply → qa → accept → pr
  ①-⑤      ⑥-⑨    ⑩    ⑪⑫       ⑬

proposal = 步骤①-⑤ + 暂停（pending_review）
apply    = 步骤⑥-⑨（开发 + 单元测试 + lint）
qa       = 步骤⑩（浏览器功能验收）
accept   = 步骤⑪⑫（更新文档 + 本地 commit）
pr       = 步骤⑬（push + 创建 PR）
doit     = 上述五步全自动串联（不暂停；--qa 时含 qa）
```

## 相关文件

- 输入：用户提供的需求（文本/文件/URL）
- 输出：
  - docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/requirements.md
  - docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/design.md
  - docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/tasks.md
  - docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/status.json
- 参考：
  - references/flow-apply.md（下一步）
  - references/01-requirements-ingestion.md（步骤 ①）
  - references/05-design-reviewer.md（Gate 1）
