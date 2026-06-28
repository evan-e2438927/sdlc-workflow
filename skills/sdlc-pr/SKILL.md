---
name: sdlc-pr
description: >-
  SDLC stage 5 — push the current branch and create a PR. This is the ONLY
  command that touches the remote / GitHub. Use when the user wants pr / 推送 /
  创建 PR after accept made the local commit. Produces phase pr_created.
---

# SDLC · pr（推送 + 创建 PR）

主线第 5 步（⑬），**唯一与远程 / GitHub 交互**的命令。前置 phase `accepted`；产出 phase `pr_created`。

## 前置检查

- `phase == accepted`（accept 已本地 commit）才可执行；`pr_created` → 已建过；其他 → 先 `accept`。
- 当前分支不能是 `main`/`master`（禁止直推）。

## 步骤

1. **push**：`git push -u origin <current-branch>`（无上游自动建立）。
2. **⑬ pr-creator**：`gh pr create --base main`，PR body 由迭代产物 + 变更摘要生成（需求摘要 / 设计要点 / 测试结果 / 变更文件 / 迭代信息）。

完成更新 `status.json`(pr_created, pr_url)，worktree 模式同步注册表 pr_url。`gh` 未认证 → 提示 `gh auth login` 后重试。

> 完整规范见 `sdlc-workflow` skill 的 `references/12-pr-creator.md`。
