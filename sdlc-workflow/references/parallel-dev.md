# 并行开发模式：Git Worktree + SDLC Pipeline

## 1. 问题分析

当前 SDLC 流程是**单管线串行**：一个工作目录同一时间只能运行一条 pipeline。这在以下场景下成为瓶颈：

| 场景 | 单管线的痛点 |
|------|-------------|
| 多需求并行研发 | proposal A 等待人工审核时，无法启动 proposal B |
| 紧急修复 + 功能开发 | hotfix 必须等当前 feature pipeline 走完 |
| 多 Agent 协作 | 多个 Claude Code 会话无法同时修改同一仓库 |
| A/B 方案对比 | 无法同时实现两种设计方案进行比较 |

## 2. 设计方案：Worktree 隔离的并行 Pipeline

### 2.1 核心思路

```
main-repo/                    ← 主工作树（bare 或正常均可），作为协调中枢
├── .git/                     ← 唯一的 Git 对象库
│   └── worktrees/            ← 自动管理的 worktree 元数据
├── .claude/                  ← 共享配置（通过 main 分支）
├── docs/iterations/          ← 所有迭代记录的汇总（合并后）
│
├── .worktrees/               ← worktree 注册表 (worktree-registry.json)
│
wt-001-user-login-feature/    ← Worktree A: 并行 Pipeline 1
├── docs/iterations/2026-04-16/001-user-login-feature/
├── tests/...
└── apps/...
│
wt-002-password-reset-fix/    ← Worktree B: 并行 Pipeline 2
├── docs/iterations/2026-04-16/002-password-reset-fix/
└── ...
```

### 2.2 Worktree 命名规范

```
wt-<seq>-<slug>-<type>/
```

- 与迭代目录的 `<seq>-<slug>-<type>` 保持一致
- 前缀 `wt-` 明确标识这是一个链接工作树
- 目录位于主工作树的**同级**（兄弟目录），不嵌套

### 2.3 分支命名

每个 worktree 对应一个独立分支：

```
{GIT_BRANCH_PREFIX}{slug}-{date}-wt{seq}
```

示例：
- `feat/user-login-2026-04-16-wt001`
- `fix/password-reset-2026-04-16-wt002`

## 3. 新增命令

### 3.1 `worktree create` — 创建并行工作区

```bash
/sdlc-workflow worktree create <需求简述>
```

行为：
1. 从 `main` 生成分支名和 slug
2. `git worktree add ../wt-<seq>-<slug>-<type> -b <branch>`
3. 在新 worktree 内初始化迭代目录
4. 复制主仓库 `.claude/.sdlc-config*` 到新 worktree（不受 git 追踪），并覆写其中的 `PORT`/`API_PORT` 实现端口隔离
5. 注册到 `.worktrees/worktree-registry.json`
6. 输出：worktree 路径 + 分支名

### 3.2 `worktree list` — 查看并行工作区状态

```bash
/sdlc-workflow worktree list
```

输出示例：
```
┌──────┬──────────────────────────┬────────────────────┬─────────────┬──────────┐
│ SEQ  │ WORKTREE                 │ BRANCH             │ PHASE       │ CREATED  │
├──────┼──────────────────────────┼────────────────────┼─────────────┼──────────┤
│ 001  │ wt-001-user-login-feat   │ feat/user-login-…  │ in-dev      │ 04-16    │
│ 002  │ wt-002-pwd-reset-fix     │ fix/pwd-reset-…    │ pending_rev │ 04-16    │
│ 003  │ wt-003-cache-refactor    │ refactor/cache-…   │ applied     │ 04-15    │
└──────┴──────────────────────────┴────────────────────┴─────────────┴──────────┘
```

### 3.3 `worktree remove` — 清理已完成的工作区

```bash
/sdlc-workflow worktree remove <seq|slug>
```

行为：
1. 检查 status.json phase == `applied`（PR 已创建）
2. `git worktree remove ../wt-<seq>-<slug>-<type>`
3. 从注册表移除
4. 可选：清理远程分支

### 3.4 `worktree status` — 全局状态总览

```bash
/sdlc-workflow worktree status
```

聚合所有 worktree 的 `status.json`，提供全局视图。

## 4. Worktree 注册表

位置：`<main-repo>/.worktrees/worktree-registry.json`

```json
{
  "version": 1,
  "worktrees": [
    {
      "seq": "001",
      "slug": "user-login",
      "type": "feature",
      "branch": "feat/user-login-2026-04-16-wt001",
      "path": "../wt-001-user-login-feature",
      "iter_dir": "docs/iterations/2026-04-16/001-user-login-feature",
      "phase": "in-dev",
      "created_at": "2026-04-16T10:00:00+08:00",
      "pipeline_stage": "test-pipeline",
      "pr_url": null
    }
  ]
}
```

**注意**：此文件提交到 `main` 分支，作为多 Agent 之间的协调总线。各 worktree 分支不修改此文件——只有 `worktree create/remove` 操作在 main 上更新。

## 5. Pipeline 适配

### 5.1 `proposal` in worktree

```
/sdlc-workflow worktree create "用户登录功能"
# → 创建 ../wt-001-user-login-feature, 切入该目录

cd ../wt-001-user-login-feature
/sdlc-workflow proposal "用户登录功能"
# → Pipeline ①-⑤ 在 worktree 内独立运行
# → status.json 写入 worktree 内的迭代目录
# → 同时更新主仓库注册表的 phase
```

### 5.2 `apply` in worktree

```
cd ../wt-001-user-login-feature
/sdlc-workflow apply docs/iterations/2026-04-16/001-user-login-feature   # ⑥-⑨
/sdlc-workflow qa docs/iterations/2026-04-16/001-user-login-feature      # ⑩（可选）
/sdlc-workflow accept docs/iterations/2026-04-16/001-user-login-feature  # ⑪⑫ 本地 commit
/sdlc-workflow pr docs/iterations/2026-04-16/001-user-login-feature      # ⑬ push + PR
# → 各命令均在 worktree 内独立运行
# → pr 直接 push worktree 自己的分支（已 checkout），创建 PR 后更新注册表
```

### 5.3 `git-committer`（⑫）与 `pr-creator`（⑬）改动

在 worktree 模式下，accept 的 git-committer（本地 commit）与 pr 的 pr-creator（push + PR）
行为变化：

```bash
# git-committer（⑫，accept）— 仅本地提交
# 传统模式：创建新分支
git checkout -b "$BRANCH_NAME"
# Worktree 模式：分支在 worktree create 时已创建，直接复用
CURRENT_BRANCH=$(git branch --show-current)   # 确认与注册表一致
git add -A
git commit -m "<type>(scope): <摘要>"

# pr-creator（⑬，pr）— push + 创建 PR
git push -u origin "$CURRENT_BRANCH"
gh pr create --base main --title "..." --body "..."
```

## 6. 并发冲突防护

### 6.1 文件级隔离

```
# 创建 worktree 时检查文件交集
worktree_create() {
  NEW_TARGET_FILES = extract_target_files(design.md)
  
  FOR wt IN active_worktrees:
    EXISTING_FILES = extract_target_files(wt.design.md)
    OVERLAP = intersection(NEW_TARGET_FILES, EXISTING_FILES)
    IF OVERLAP:
      WARN "⚠️ 与 worktree ${wt.slug} 存在文件冲突:"
      PRINT OVERLAP
      ASK "是否继续？可能需要手动解决合并冲突"
  
  PROCEED
}
```

### 6.2 合并顺序建议

当多个 worktree 的 PR 同时 ready 时：

1. **无冲突 PR** → 按完成时间顺序合并
2. **有文件交集的 PR** → 按依赖关系排序：
   - 基础设施/shared packages 先合
   - 依赖方后合
   - 后合的 PR 需要 rebase 到最新 main

### 6.3 Rebase 同步

```bash
# 当 main 上有其他 worktree 的 PR 已合并时，同步到当前 worktree
cd ../wt-002-password-reset-fix
git fetch origin main
git rebase origin/main
# 若有冲突 → 手动解决 → 继续 pipeline
```

## 7. 多 Agent 并行场景

### 7.1 每个 Agent 一个 worktree

```
Terminal 1 (Agent A):
  cd wt-001-user-login-feature
  /sdlc-workflow doit "用户登录功能"

Terminal 2 (Agent B):
  cd wt-002-password-reset-fix
  /sdlc-workflow doit "密码重置修复"

Terminal 3 (Agent C):
  cd wt-003-cache-refactor
  /sdlc-workflow doit "缓存层重构"
```

### 7.2 资源隔离

| 资源 | 隔离方式 |
|------|---------|
| Git 对象库 | 共享（worktree 机制自动处理） |
| Git 分支 | 每个 worktree 独占（Git 强制） |
| 代码文件 | 各 worktree 独立副本 |
| 迭代目录 | 各 worktree 独立（分支内） |
| Port（dev server） | 需手动分配不同端口 |
| `.claude/` 配置 | 各分支有自己的副本 |
| `node_modules/` | 各 worktree 独立安装 |

### 7.3 端口分配规则

为避免多个 worktree 同时运行 dev server 时端口冲突：

```
Worktree 001: PORT=3001, API_PORT=4001
Worktree 002: PORT=3002, API_PORT=4002
Worktree 003: PORT=3003, API_PORT=4003
...
公式: PORT = 3000 + seq, API_PORT = 4000 + seq
```

在 worktree 的 `.claude/.sdlc-config` 中自动设置：
```bash
PORT=$((3000 + seq))
API_PORT=$((4000 + seq))
```

## 8. 工作流示例

### 8.1 典型并行开发流程

```
# 1. 启动 Feature A 的 proposal
/sdlc-workflow worktree create "用户登录功能"
cd ../wt-001-user-login-feature
/sdlc-workflow proposal "用户登录功能"
# → proposal 完成，等待审核

# 2. 不等审核，立即启动 Feature B
cd ../main-repo
/sdlc-workflow worktree create "支付集成"
cd ../wt-002-payment-integration-feature
/sdlc-workflow proposal "支付集成"

# 3. Feature A 审核通过，开始开发
cd ../wt-001-user-login-feature
/sdlc-workflow apply docs/iterations/2026-04-16/001-user-login-feature

# 4. Feature B 也审核通过
cd ../wt-002-payment-integration-feature
/sdlc-workflow apply docs/iterations/2026-04-16/002-payment-integration-feature

# 5. Feature A PR 已创建，清理 worktree
cd ../main-repo
/sdlc-workflow worktree remove 001

# 6. 查看全局状态
/sdlc-workflow worktree status
```

### 8.2 紧急修复打断场景

```
# 正在 worktree 001 上开发 feature...
# 突然需要 hotfix

cd ../main-repo
/sdlc-workflow worktree create "登录崩溃紧急修复"
# → 自动识别为 fix 类型

cd ../wt-002-login-crash-fix
/sdlc-workflow mini "修复登录页面在 Safari 下崩溃"
# → mini pipeline 快速修复
# → PR 创建 → 合并

cd ../main-repo
/sdlc-workflow worktree remove 002

# 回到 feature 开发
cd ../wt-001-user-login-feature
git rebase origin/main  # 同步 hotfix
# 继续开发...
```

## 9. 清理策略

### 9.1 自动清理

```bash
# PR 合并后自动提示清理
/sdlc-workflow worktree gc

# 行为：
# 1. 检查所有注册的 worktree
# 2. 若 PR 已合并 → 提示 remove
# 3. 若 phase == applied 且 PR 已超过 7 天 → 提示 remove
# 4. 执行 git worktree prune 清理残留
```

### 9.2 手动批量清理

```bash
/sdlc-workflow worktree remove --all-merged
# → 移除所有 PR 已合并的 worktree
```

## 10. 注意事项

1. **同一分支不能在两个 worktree 中检出**——Git 强制限制
2. **`node_modules` 不共享**——每个 worktree 需独立 `pnpm install`
3. **Git hooks 共享**——`.git/hooks/` 只有一份，所有 worktree 共用
4. **lockfile 冲突**——多个 worktree 同时修改 `pnpm-lock.yaml` 时合并困难，建议各 PR 独立生成
5. **磁盘空间**——虽然 .git 共享，但每个 worktree 的工作文件 + node_modules 会占空间
6. **IDE 支持**——每个 worktree 可以用独立的 VS Code 窗口打开
