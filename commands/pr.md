---
description: 推送当前分支并创建 PR（accept 本地提交后执行）
argument-hint: [<迭代目录>]
---

执行 `sdlc-workflow pr`，参数：$ARGUMENTS（步骤 ⑬，详细规范见 `${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/references/12-pr-creator.md`）

查找迭代目录（若未指定，取最近一个 `phase == "accepted"` 的目录）。

## 前置检查

- `status.json` 中 `phase == "accepted"`（accept 已完成本地 commit）才可执行
- `phase == "pr_created"` → 提示已创建过 PR
- 其他 phase → 提示先运行 `accept`
- 当前分支不能是 `main` / `master`（禁止直推）

## 执行步骤

**push**：`git push -u origin <current-branch>`（远程无上游时自动建立）。

**⑬ pr-creator**：`gh pr create --base main`，PR body 从迭代产物 + 变更摘要生成
（需求摘要 / 设计要点 / 测试结果 / 变更文件 / 迭代信息）。

完成后更新 `status.json`（phase: "pr_created", pr_url），worktree 模式同步注册表 pr_url，输出：
```
✅ PR: <url> | 分支: <current-branch>
```

> 这是唯一与远程 / GitHub 交互的命令。`gh` 未认证时提示 `gh auth login` 后重试。
