---
name: sdlc-qa
description: >-
  SDLC stage 3 — write Playwright scripts and run browser functional acceptance
  via Playwright MCP. Use when the user wants qa / 浏览器验收 / E2E acceptance after
  apply. This is the final pass standard — real browser interaction evidence.
---

# SDLC · qa（浏览器功能验收）

> 核心目录 `SDLC_CORE`：按核心 skill 的 SKILL.md「核心目录（SDLC_CORE）」解析——核心 SKILL.md 在本 skill 同级的 `../sdlc-workflow/SKILL.md`，其次 `${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/SKILL.md`；两处都不存在 → 报错「缺少核心 skill sdlc-workflow，请执行 `npx skills add evan-e2438927/sdlc-workflow --skill sdlc-workflow`」并停止。

主线第 3 步（⑩）。前置 phase `applied`，Playwright MCP 可用；全部通过 → phase `qa_passed`。

## 步骤

1. 读 `tasks.md` 中 **`track: qa`** 的任务，提取验收场景（Given-When-Then + 选择器约束 + 维度）。
   **deferred 闭环核对**：比对 apply 的 `tests/reports/<slug>-coverage.md` 里标 `deferred to qa` 的 AC，确保每个都有对应 qa 场景，缺失报警。
2. 为每个场景写 Playwright 脚本到 `tests/e2e/<slug>/E2E-<nnn>-<scenario>.e2e.ts`，名称引用 AC-ID。
3. 后台启 dev server（读 package.json scripts，等 ready，提取 URL），通过 Playwright MCP 执行：navigate → snapshot → click/type → 断言 + console error → 失败截图。**跑完 teardown dev server，释放端口。**
4. 产出 `tests/reports/<slug>-e2e-report.md`。

**失败按根因分流**（qa 不改业务代码）：脚本/选择器问题 → qa 内就地修复重跑（按「修复轮数（唯一定义）」，超限停下转人工）；代码缺陷 → 写 `$ITER_DIR/qa-failures.md`，phase 迁移到 `qa_failed`，提示运行 `sdlc-apply`（自动进入修复模式）。每次运行都执行全部场景。

> 完整规范见 `sdlc-workflow` skill 的 `references/flow-qa.md`。
