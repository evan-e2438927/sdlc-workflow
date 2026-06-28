---
description: 从 proposal 产物执行开发和单元测试，不提交不推 PR
argument-hint: [--review] [<迭代目录>]
---

执行 `sdlc-workflow apply`，参数：$ARGUMENTS

读取并遵循 `${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/SKILL.md` 中的完整规范。当前执行 **apply** 模式（步骤 ⑥→⑦→[⑧]→⑨）。

## 前置检查

查找迭代目录（若未指定，取最近一个 `phase == "pending_review" | "approved"` 的目录）：
- `phase == pending_review` → 视为审核通过，更新 `phase = "approved"`
- `phase == applied` → 中止，拒绝重复执行
- `phase == rejected` → 中止，提示修改后重新 proposal

## 执行步骤

**⑥ 开发**：读取 tasks.md，分析依赖图，选择顺序或 Agent Team 并行模式实现代码。每完成一个任务回写 tasks.md（`[ ]` → `[x]`）。

**⑦ test-generator**：仅处理 `track: unit-test` 的任务，生成 `tests/unit/` 下的单元测试。**不生成 E2E/浏览器测试**（由 `qa` 命令负责）。测试用例名称引用 AC-ID 和场景维度。

**[⑧ Gate 2]**（仅 `--review`）：Codex CLI 审查代码 + tasks.md 完成度，失败则修复。

**⑨ test-pipeline**：`lint → unit`（两阶段，不含浏览器 E2E）。失败则修复，超过 REVIEW_MAX_ROUNDS 轮中止。浏览器/E2E 由 `qa` 命令负责。

完成后更新 `status.json`（phase: "applied"），输出：
```
✅ 开发完成: N 个任务 | 测试: lint + unit 全部通过（E2E/浏览器验收见 qa）
👉 浏览器验收请运行: /sdlc-workflow:qa
👉 确认无误后提交: /sdlc-workflow:accept
```
