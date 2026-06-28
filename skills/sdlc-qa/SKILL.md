---
name: sdlc-qa
description: >-
  SDLC stage 3 — write Playwright scripts and run browser functional acceptance
  via Playwright MCP. Use when the user wants qa / 浏览器验收 / E2E acceptance after
  apply. This is the final pass standard — real browser interaction evidence.
---

# SDLC · qa（浏览器功能验收）

主线第 3 步（⑩）。前置 phase `applied`，Playwright MCP 可用；全部通过 → phase `qa_passed`。

## 步骤

1. 读 `tasks.md` 中 **`track: qa`** 的任务，提取验收场景（Given-When-Then + 选择器约束 + 维度）。
   **deferred 闭环核对**：比对 apply 的 `tests/reports/<slug>-coverage.md` 里标 `deferred to qa` 的 AC，确保每个都有对应 qa 场景，缺失报警。
2. 为每个场景写 Playwright 脚本到 `tests/e2e/<slug>/E2E-<nnn>-<scenario>.e2e.ts`，名称引用 AC-ID。
3. 后台启 dev server（读 package.json scripts，等 ready，提取 URL），通过 Playwright MCP 执行：navigate → snapshot → click/type → 断言 + console error → 失败截图。**跑完 teardown dev server，释放端口。**
4. 产出 `tests/reports/<slug>-e2e-report.md`。

**失败按根因分流**（不要笼统重跑 apply，phase==applied 时 apply 会中止）：脚本/选择器问题 → qa 内就地修复重跑（≤REVIEW_MAX_ROUNDS）；代码缺陷 → phase 退回 `approved`，提示修复后重跑 apply；超限 → 中止 + 截图 + 人工介入。

> 完整规范见 `sdlc-workflow` skill 的 `references/flow-qa.md`。
