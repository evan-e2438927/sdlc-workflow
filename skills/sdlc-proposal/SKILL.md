---
name: sdlc-proposal
description: >-
  SDLC stage 1 — break a requirement into requirements / design / tasks (split
  by track) and pause for human review. Use when the user wants to proposal /
  拆解需求 / plan a feature before coding, from plain text, a file:/// path, or a
  URL. Produces a proposal that waits for approval before apply.
---

# SDLC · proposal（需求拆解）

主线第 1 步。产出 phase `pending_review` 后暂停，等人工审核。

接受输入：纯文本 / `file:///path` / URL（自动 Playwright MCP 提取）。

## 步骤（①-④，默认跳过 Gate 1，加 --review 则 ⑤）

1. **① requirements-ingestion** → `requirements.md`（按 5 维度生成 AC：happy-path / error / boundary / ui-state / security）
2. **② requirements-clarifier** → 标注置信度。**澄清 Gate**：交互模式下，凡会影响设计决策的低置信度项必须先发起提问（provenance=asked）才能进入 ③，不得静默假设后直接设计。
3. **③ design-generator** → `design.md`：先复核澄清 Gate，被假设驱动的决策登记到「设计假设」。
4. **④ task-generator** → `tasks.md`：按 track 拆分（frontend / backend / unit-test / qa），每个任务标注 `track:` 并引用 AC-ID。
5. **[⑤ Gate 1]** 仅 `--review`：Codex 设计审查。

写 `status.json`（phase: pending_review）后暂停，提示运行 `apply`。

> 完整规范见 `sdlc-workflow` skill 的 `references/flow-proposal.md` 及 `references/01-`~`05-*.md`。
