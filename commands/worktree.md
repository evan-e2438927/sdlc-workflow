---
description: 并行工作区管理，通过 Git Worktree 隔离多需求并行开发
argument-hint: create <slug> <type> | list | status | remove <seq|slug> | gc
---

执行 `sdlc-workflow worktree`，参数：$ARGUMENTS

解析子命令：`worktree <create|list|status|remove|gc> [参数]`

## create — 创建并行工作区

```bash
worktree create <slug> <type>
# type: feature | fix | refactor | docs | test | chore
```

执行：
1. 从 `main` 创建分支 `{type-prefix}/{slug}-{date}-wt{seq}`
2. `git worktree add ../wt-<seq>-<slug>-<type> -b <branch>`
3. 在新 worktree 初始化迭代目录
4. 分配端口：`PORT=3000+seq`，`API_PORT=4000+seq`
5. 注册到 `.worktrees/worktree-registry.json`

输出：`✅ Worktree 创建成功: ../wt-<seq>-<slug>-<type> (PORT:<port>)`

## list — 列出所有工作区

读取 `.worktrees/worktree-registry.json`，展示所有工作区的分支、状态、端口。

## status — 全局状态总览

聚合所有 worktree 目录下的 `status.json`，展示每个工作区的 phase 和进度。

## remove — 移除工作区

```bash
worktree remove <seq|slug>
worktree remove --all-merged
```

执行 `git worktree remove`，从注册表中删除条目。

## gc — 清理已合并工作区

检查注册表中所有工作区，移除已合并到 main 的分支对应的 worktree。

详细规范见 `${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/references/parallel-dev.md`，脚本：`${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/scripts/sdlc-worktree.sh`。
