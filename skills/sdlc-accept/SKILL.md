---
name: sdlc-accept
description: >-
  SDLC stage 4 — summarize the change, update docs, and make a LOCAL commit
  (no push, no PR). Use when the user wants accept / 定稿 / 本地提交 after qa passes
  (or after apply when skipping qa). Produces phase accepted.
---

# SDLC · accept（验收定稿，本地提交）

> 核心目录 `SDLC_CORE`：按核心 skill 的 SKILL.md「核心目录（SDLC_CORE）」解析——核心 SKILL.md 在本 skill 同级的 `../sdlc-workflow/SKILL.md`，其次 `${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/SKILL.md`；两处都不存在 → 报错「缺少核心 skill sdlc-workflow，请执行 `npx skills add evan-e2438927/sdlc-workflow --skill sdlc-workflow`」并停止。

主线第 4 步（⑪⑫）。前置 phase `qa_passed`（或 `applied` 跳过 qa）；产出 phase `accepted`。**不 push、不建 PR。**

## 步骤

1. **变更总结**：基于 git diff + tasks.md 完成状态，归纳涉及的 track、关键文件、实现的 AC-ID（若已 qa，附 e2e 报告结论），作为文档更新与 commit message 输入。
2. **⑪ docs-updater**：按变更更新受影响文档 —— `README.md`、`.claude/ARCHITECTURE.md`、`.claude/SECURITY.md`、`.claude/CODING_GUIDELINES.md`、`.claude/CLAUDE.md`（更新 iterations 引用列表）。
3. **⑫ git-committer（本地）**：检测是否在 worktree（是 → 复用已 checkout 分支；否 → `git checkout -b <prefix><slug>-date`）→ `git add -A` → `commit`。Commit 格式遵循 Conventional Commits `<type>(scope): <摘要>`。

完成后经状态脚本迁移到 `accepted`，提示运行 `pr`。若 QA 曾失败、修复后还没重新通过 qa，提交前先问用户是否跳过 qa；phase 为 `qa_failed` 时拒绝，提示先 `apply` 修复。

> 完整规范见 `sdlc-workflow` skill 的 `references/flow-accept.md`、`10-docs-updater.md`、`11-git-committer.md`。
