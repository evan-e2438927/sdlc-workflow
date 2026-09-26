---
name: sdlc-apply
description: >-
  SDLC stage 2 — after a proposal is approved, implement the code plus unit
  tests and lint, without committing or pushing. Use when the user wants to
  apply / 开发 / execute an approved proposal's tasks.md. Optional --review runs
  Codex Gate 2 on the code; --agents single|multi picks single- or
  multi-agent (backend/frontend/test roles) execution.
---

# SDLC · apply（开发）

主线第 2 步。前置 phase `pending_review`(视为审核通过)或 `approved`；产出 phase `applied`。**不提交、不推 PR**。

## 步骤（⑥-⑨，默认跳过 Gate 2，加 --review 则 ⑧）

执行模式：`AGENT_MODE`（auto / single / multi，默认 auto），运行时 `--agents single|multi` 覆盖。两种模式流程相同、产出等价，只是执行者不同。

1. **⑥.0 打包**：读 `tasks.md` 与 design.md「接口契约」，按 Track 生成工作包；解析执行模式写入 status.json。每个任务执行前对照其「适用规范」。
2. **⑥.1 打地基（主 agent）**：infra / shared 任务、契约落地、安装「新增依赖」。
3. **⑥.2 开发**：backend、frontend 角色各自实现并写自己的单测（multi → 两个子 agent 并行；single → 主 agent 依次扮演）。`track: qa` 留给 qa 命令。
4. **⑥.3 汇总（主 agent）**：读 `tracks/*.md` → 越界检测 → 公共文件请求 / blocked → 回写 tasks.md → ⑥.5 勾选属实自检。
5. **⑦ 查漏（test 角色）**：按 AC 清单补单测 + 覆盖率报告；`track: qa` 的 AC 标 `deferred to qa`。⑦.1 主 agent 汇总。
6. **[⑧ Gate 2]** 仅 `--review`：Codex 代码审查（含契约一致性、越界）+ tasks.md 状态漂移检查。
7. **⑨ test-pipeline**：`lint → unit`（不含浏览器）。失败修复，超 REVIEW_MAX_ROUNDS 中止。

完成更新 `status.json`(applied)，提示 `qa`（浏览器验收）/ `accept`。

> 完整规范见 `sdlc-workflow` skill 的 `references/flow-apply.md`、`references/roles/`、`07-test-generator.md`、`09-test-pipeline.md`。
