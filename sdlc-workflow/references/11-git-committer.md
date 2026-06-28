# 步骤 ⑫: Git Committer — 本地提交

> 范围：只做 **branch → add → commit（本地）**，**不 push、不建 PR**。
> push 与 PR 创建已独立为 `pr` 命令（步骤 ⑬，见 references/12-pr-creator.md）。

## 输入

所有代码 + 文档变更 + 变更摘要（由 accept 的「变更总结」步骤提供）

## 输出

本地 commit（未推送）

## Conventional Commits 规范（统一）

全仓库提交统一遵循 [Conventional Commits 1.0.0](https://www.conventionalcommits.org/zh-hans/v1.0.0/)。
这是 commit message 的**唯一权威定义**，其他文档引用此处即可。

### 格式

```
<type>[optional scope][!]: <description>

[optional body]

[optional footer(s)]
```

- **description**：祈使句、简洁、首字母小写、结尾不加句号，建议 ≤ 72 字符
- **body**：解释「为什么」与「做了什么」，与标题空一行
- **footer**：`BREAKING CHANGE: <说明>`、`Refs: #123`、`Reviewed-by:` 等

### type 取值

| type | 含义 | 影响版本 |
|------|------|----------|
| `feat` | 新功能 | MINOR |
| `fix` | 缺陷修复 | PATCH |
| `docs` | 仅文档 | — |
| `style` | 不影响语义的格式（空白/分号等） | — |
| `refactor` | 既不修 bug 也不加功能的重构 | — |
| `perf` | 性能优化 | PATCH |
| `test` | 新增/修正测试 | — |
| `build` | 构建系统或依赖变更 | — |
| `ci` | CI 配置/脚本变更 | — |
| `chore` | 杂项（不影响 src/test） | — |
| `revert` | 回滚某次提交 | — |

### scope 与破坏性变更

- **scope**：括号内的模块名，可选，如 `feat(auth):`
- **破坏性变更**：type/scope 后加 `!`（如 `feat(api)!:`），或在 footer 写
  `BREAKING CHANGE: <说明>`；任一形式都触发 MAJOR

### 取值来源

- type：`.claude/.sdlc-config` 的 `COMMIT_TYPE`；留空则按迭代目录 `<type>` 映射
  （feature→feat, fix→fix, refactor→refactor, docs→docs, test→test, chore→chore）
- scope：`.claude/.sdlc-config` 的 `COMMIT_SCOPE`；留空则取本次变更最多的顶层目录

### 示例

```
feat(auth): add email + phone login
fix(api): handle upstream timeout as 504
refactor(db)!: drop deprecated users.legacy_id column

BREAKING CHANGE: 依赖 legacy_id 的调用方需迁移到 uuid
```

## 详细行为

### 1. 执行流程

```bash
# 1. 创建/复用分支
# 2. 暂存变更
# 3. 提交（Conventional Commits）
```

### 2. 分支创建

```bash
# worktree 模式：分支已在 worktree create 时创建，直接复用
IS_WORKTREE=$(git rev-parse --git-common-dir 2>/dev/null | grep -q '/worktrees/' && echo 1 || echo 0)

if [ "$IS_WORKTREE" = "1" ]; then
  BRANCH_NAME=$(git branch --show-current)
else
  # 传统模式：从配置生成分支名 {prefix}{slug}-{date}
  GIT_BRANCH_PREFIX=${GIT_BRANCH_PREFIX:-feat/}
  DATE=$(date +%Y-%m-%d)
  BRANCH_NAME="${GIT_BRANCH_PREFIX}${SLUG}-${DATE}"
  git checkout -b "$BRANCH_NAME"
fi

echo "🌿 分支: $BRANCH_NAME"
```

### 3. 变更暂存

```bash
git add -A
git status --short
```

### 4. 提交（Conventional Commits）

```bash
# 确定 commit type（与迭代目录 type 对应）
TYPE_MAP="feature:feat fix:fix refactor:refactor docs:docs test:test chore:chore"
COMMIT_TYPE=$(echo "$TYPE_MAP" | grep "^${TYPE}:*" | cut -d: -f2)

# 确定 scope（.claude/.sdlc-config 中 COMMIT_SCOPE 优先，否则取变更最多的目录）
COMMIT_SCOPE=${COMMIT_SCOPE:-}
if [ -z "$COMMIT_SCOPE" ]; then
  COMMIT_SCOPE=$(git diff --name-only --staged | \
    cut -d/ -f1 | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
fi

# commit message：标题取变更摘要，正文引用迭代摘要
git commit -m "${COMMIT_TYPE}(${COMMIT_SCOPE}): ${SUMMARY}"
echo "📝 已本地提交: ${COMMIT_TYPE}(${COMMIT_SCOPE}): ${SUMMARY}"
```

### 5. 完整脚本

```bash
#!/bin/bash
set -euo pipefail

GIT_BRANCH_PREFIX=${GIT_BRANCH_PREFIX:-feat/}
COMMIT_SCOPE=${COMMIT_SCOPE:-}
DATE=$(date +%Y-%m-%d)
ITER_DIR="docs/iterations/$DATE/${SEQ}-${SLUG}-${TYPE}/"

# 1. 分支（worktree 复用 / 传统新建）
IS_WORKTREE=$(git rev-parse --git-common-dir 2>/dev/null | grep -q '/worktrees/' && echo 1 || echo 0)
if [ "$IS_WORKTREE" = "1" ]; then
  BRANCH_NAME=$(git branch --show-current)
else
  BRANCH_NAME="${GIT_BRANCH_PREFIX}${SLUG}-${DATE}"
  git checkout -b "$BRANCH_NAME"
fi
echo "🌿 分支: $BRANCH_NAME"

# 2. 暂存
git add -A

# 3. commit type / scope
TYPE_MAP="feature:feat fix:fix refactor:refactor docs:docs test:test chore:chore"
COMMIT_TYPE=$(echo "$TYPE_MAP" | grep "^${TYPE}:*" | cut -d: -f2)
if [ -z "$COMMIT_SCOPE" ]; then
  COMMIT_SCOPE=$(git diff --name-only --staged | \
    cut -d/ -f1 | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
fi

# 4. 提交（本地，不 push）
git commit -m "${COMMIT_TYPE}(${COMMIT_SCOPE}): ${SUMMARY}"
echo "📝 已本地提交: ${COMMIT_TYPE}(${COMMIT_SCOPE}): ${SUMMARY}"
echo "👉 推送并创建 PR: /sdlc-workflow:pr"
```

## 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| 分支已存在（传统模式） | 切换到已存在分支，继续提交 |
| 暂存为空 | 警告，跳过 commit，提示无变更 |
| commit 失败（hook 拦截等） | 输出错误，中止，待修复后重跑 |

## 安全规则

1. **禁止直接在 main/master 上提交** — 必须在 feature branch
2. **提交信息规范** — 必须符合 Conventional Commits
3. **不在此步 push** — push 与 PR 由 `pr` 命令负责

## 相关文件

- 输入：所有代码 + 文档变更
- 输出：本地 commit
- 参考：
  - references/10-docs-updater.md（前一步：文档更新）
  - references/12-pr-creator.md（下一步：push + PR）
