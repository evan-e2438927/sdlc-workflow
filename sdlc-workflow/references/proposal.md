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
     （而非通过 TG 回复）。详见 references/requirements-clarifier.md §4。

③ design-generator
   → docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/design.md

④ task-generator
   → docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/tasks.md

⑤ design-reviewer (Gate 1)
   循环审查，最大 REVIEW_MAX_ROUNDS 轮

⑤.1 增量文档同步（若 Gate 1 经 ≥1 轮修订）
   同步影响到的 .claude/ARCHITECTURE.md / .claude/SECURITY.md 等

⑥ 写入 status.json
   → phase: "pending_review"

⑦ 通知 TG: 📋 需求拆解完成，等待人工审核

⏸ 停止
```

## status.json 写入规范

Proposal 完成后在迭代目录下写入 `status.json`：

```json
{
  "phase": "pending_review",
  "proposal_at": "2026-04-13T14:00:00+08:00",
  "reviewed_at": null,
  "applied_at": null,
  "reviewer": null,
  "iter_dir": "docs/iterations/2026-04-13/001-user-login-feature/",
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
| phase | string | `pending_review` → `approved` → `applied`，另有 `rejected` |
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

## TG 通知文案

### Proposal 完成通知

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

## 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| 项目未初始化 | 自动执行 init-project.sh |
| 需求采集失败 | 中止，TG 通知 |
| Gate 1 超限 | 中止，TG 通知人工介入 |
| status.json 写入失败 | LOG warning，不阻塞（产物已生成） |

## 与 doit 的关系

```
proposal = 步骤①-⑤ + 暂停
doit     = 步骤①-⑪（不暂停，全自动）
apply    = 步骤⑥-⑪（从 proposal 产物继续）

doit 内部等价于 proposal + apply 不停顿
```

## 相关文件

- 输入：用户提供的需求（文本/文件/URL）
- 输出：
  - docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/requirements.md
  - docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/design.md
  - docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/tasks.md
  - docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/status.json
- 参考：
  - references/apply.md（下一步）
  - references/requirements-ingestion.md（步骤 ①）
  - references/design-reviewer.md（Gate 1）
