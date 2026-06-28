---
name: sdlc-review
description: >-
  Run Codex review standalone — Gate 1 (design) or Gate 2 (code) — without
  triggering other SDLC stages. Use for review proposal / review code / 单独审查 /
  跑一遍 Codex 审查. Requires Codex CLI; aborts (never silently skips) if unavailable.
---

# SDLC · review（独立 Codex 审查）

在 proposal / apply 之外单独触发 Codex CLI 审查，不影响其他步骤。参数：`review <proposal|code> <迭代目录>`。

## Gate 1 — 设计审查（`review proposal <迭代目录>`）

Codex 审 `design.md` + `tasks.md`：需求覆盖度（每个 AC-ID 是否被 tasks 引用）、AC 是否保留 Given-When-Then + 维度、是否有模糊不可验证 AC、每个 Requirement 是否至少覆盖 happy-path + error、**澄清完备性**（被假设驱动的决策是否登记、有无 never-asked 的设计影响项）。

## Gate 2 — 代码审查（`review code <迭代目录>`）

Codex 审代码变更 + tasks.md 完成状态：是否符合 design.md、勾选是否与实现一致、安全/性能/规范、E2E deferred-to-qa 是否成立。

```bash
codex exec --full-auto "审查 ..."
```

PASS → `✅ Review PASS`；FAIL → 输出具体问题，建议修订后重跑。**Codex 不可用时中止，不自动跳过。**

> 完整规范见 `sdlc-workflow` skill 的 `references/05-design-reviewer.md`、`08-code-reviewer.md`。
