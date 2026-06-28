---
name: sdlc-apply
description: >-
  SDLC stage 2 — after a proposal is approved, implement the code plus unit
  tests and lint, without committing or pushing. Use when the user wants to
  apply / 开发 / execute an approved proposal's tasks.md. Optional --review runs
  Codex Gate 2 on the code.
---

# SDLC · apply（开发）

主线第 2 步。前置 phase `pending_review`(视为审核通过)或 `approved`；产出 phase `applied`。**不提交、不推 PR**。

## 步骤（⑥-⑨，默认跳过 Gate 2，加 --review 则 ⑧）

1. **⑥ 开发**：读 `tasks.md`，按依赖拓扑实现 frontend/backend/unit-test 三类 track（`track: qa` 留给 qa 命令）。可并行层（无目标文件交集且 Target Files 声明完整）→ Agent Team；否则顺序。每完成一任务回写 tasks.md。
2. **⑥.5 勾选属实自检（默认执行）**：逐个已勾选的任务/AC 确认有代码/测试/报告支撑，纠正状态漂移，带病项不得进 ⑨。
3. **⑦ test-generator**：仅生成单元测试 `tests/unit/`；`track: qa` / playwright-mcp 的 AC 标 `deferred to qa`，不在此写 E2E。
4. **[⑧ Gate 2]** 仅 `--review`：Codex 代码审查 + tasks.md 状态漂移检查。
5. **⑨ test-pipeline**：`lint → unit`（不含浏览器）。失败修复，超 REVIEW_MAX_ROUNDS 中止。

完成更新 `status.json`(applied)，提示 `qa`（浏览器验收）/ `accept`。

> 完整规范见 `sdlc-workflow` skill 的 `references/flow-apply.md`、`07-test-generator.md`、`09-test-pipeline.md`。
