---
name: sdlc-pr
description: >-
  SDLC stage 5 — push the current branch and create a PR. This is the ONLY
  command that touches the remote / GitHub. Use when the user wants pr / 推送 /
  创建 PR after accept made the local commit. Produces phase pr_created.
---

# SDLC · pr（推送 + 创建 PR）

> 核心目录 `SDLC_CORE`：按核心 skill 的 SKILL.md「核心目录（SDLC_CORE）」解析——核心 SKILL.md 在本 skill 同级的 `../sdlc-workflow/SKILL.md`，其次 `${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/SKILL.md`；两处都不存在 → 报错「缺少核心 skill sdlc-workflow，请执行 `npx skills add evan-e2438927/sdlc-workflow --skill sdlc-workflow`」并停止。

主线第 5 步（⑬），**唯一与远程 / GitHub 交互**的命令。前置 phase `accepted`；产出 phase `pr_created`。

## 前置检查

- `phase == accepted`（accept 已本地 commit）才可执行；`pr_created` → 已建过；其他 → 先 `accept`。
- 当前分支不能是 `main`/`master`（禁止直推）。

## 步骤

1. **push**：`git push -u origin <current-branch>`（无上游自动建立）。
2. **⑬ pr-creator**：`gh pr create --base main`，PR body 由迭代产物 + 变更摘要生成（需求摘要 / 设计要点 / 测试结果 / 变更文件 / 迭代信息）。

完成后经状态脚本迁移到 `pr_created` 并写入 `pr_url`，worktree 模式同步注册表 pr_url。`gh` 未认证 → 提示 `gh auth login` 后重试。

> 完整规范见 `sdlc-workflow` skill 的 `references/12-pr-creator.md`。
