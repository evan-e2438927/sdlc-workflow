---
name: sdlc-worktree
description: >-
  Parallel development via git worktree — create / list / status / remove / gc
  isolated workspaces with auto branch and port allocation and a shared
  registry. Use for worktree / 并行开发 / 多需求同时跑 / 多 Agent 协作 / hotfix 隔离.
  It isolates the workspace; the pipeline still runs proposal→apply→qa→accept→pr.
---

# SDLC · worktree（并行工作区）

用 `git worktree` 让一个仓库同时存在多个隔离工作区，各跑独立 pipeline。子命令：`create | list | status | remove | gc`。

## create `<slug> <type>`（type: feature|fix|refactor|docs|test|chore）

1. 从 `main` 建分支 `{type-prefix}/{slug}-{date}-wt{seq}`。
2. `git worktree add ../wt-<seq>-<slug>-<type> -b <branch>`。
3. 新 worktree 初始化迭代目录。
4. 分配端口 `PORT=3000+seq`、`API_PORT=4000+seq`（写入该 worktree 的 `.claude/.sdlc-config`）。
5. 注册到 `.worktrees/worktree-registry.json`。

## 其他

- **list**：读注册表，列出各工作区分支/状态/端口。
- **status**：聚合各 worktree 的 `status.json`，展示 phase 与进度。
- **remove `<seq|slug>`** / `--all-merged`：`git worktree remove` + 删注册表条目。
- **gc**：清理已合并到 main 的工作区。

执行脚本：`scripts/sdlc-worktree.sh`（相对 skill 目录）。

> 完整规范见 `sdlc-workflow` skill 的 `references/parallel-dev.md`。
