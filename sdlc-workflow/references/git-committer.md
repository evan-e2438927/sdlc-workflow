# 步骤 ⑪: Git Committer — Git 工作流

## 输入

所有代码 + 文档变更

## 输出

PR URL

## 详细行为

### 1. 执行流程

```bash
# 1. 创建分支
# 2. 暂存变更
# 3. 提交（Conventional Commits）
# 4. 推送
# 5. 创建 PR
```

### 2. 分支创建

```bash
# 读取配置
GIT_BRANCH_PREFIX=${GIT_BRANCH_PREFIX:-feat/}
DATE=$(date +%Y-%m-%d)

# 生成分支名：{prefix}{slug}-{date}
BRANCH_NAME="${GIT_BRANCH_PREFIX}${SLUG}-${DATE}"

# 创建分支
git checkout -b "$BRANCH_NAME"

echo "🌿 创建分支: $BRANCH_NAME"
```

### 3. 变更暂存

```bash
# 暂存所有变更
git add -A

# 查看暂存状态
git status --short
```

### 4. 提交（Conventional Commits）

```bash
# 确定 commit type（与迭代目录 type 对应）
# feature → feat
# fix → fix
# refactor → refactor
# docs → docs
# test → test
# chore → chore

TYPE_MAP="feature:feat fix:fix refactor:refactor docs:docs test:test chore:chore"
COMMIT_TYPE=$(echo "$TYPE_MAP" | grep "^${TYPE}:*" | cut -d: -f2)

# 确定 scope（从变更文件路径推断）
COMMIT_SCOPE=${COMMIT_SCOPE:-}  # 可在 .env 中设置

if [ -z "$COMMIT_SCOPE" ]; then
  # 自动推断：取变更最多的目录
  COMMIT_SCOPE=$(git diff --name-only --staged | \
    cut -d/ -f1 | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
fi

# 生成 commit message
SUMMARY=$(head -c 72 "$ITER_DIR/requirements.md" | sed 's/[[:space:]]*$//')
git commit -m "${COMMIT_TYPE}(${COMMIT_SCOPE}): ${SUMMARY}"
```

### 5. 推送

```bash
# 推送到远程
git push origin "$BRANCH_NAME"

echo "📤 已推送: origin/$BRANCH_NAME"
```

### 6. 创建 PR

```bash
# 生成 PR body
PR_BODY=$(cat << 'EOF'
## 需求摘要

<!-- 从 requirements.md 提取 -->

## 设计要点

<!-- 从 design.md 提取 -->

## 测试结果

| 阶段 | 结果 |
|------|------|
| Lint | ✅ |
| Unit | ✅ |
| E2E | ✅ |

## 变更文件

<!-- 从 git diff --stat 提取 -->

## 迭代信息

- 迭代目录: `docs/iterations/<date>/<seq>-<slug>-<type>/`
- 设计文档: `docs/iterations/<date>/<seq>-<slug>-<type>/design.md`
- 任务分解: `docs/iterations/<date>/<seq>-<slug>-<type>/tasks.md`

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)

# 创建 PR
PR_TITLE="${COMMIT_TYPE}(${COMMIT_SCOPE}): ${SUMMARY}"
PR_URL=$(gh pr create \
  --title "$PR_TITLE" \
  --body "$PR_BODY" \
  --label "automated-sdlc" \
  --reviewer "" \
  2>/dev/null | tee /dev/stderr)

echo "🔗 PR: $PR_URL"
```

### 7. 完整脚本

```bash
#!/bin/bash
set -euo pipefail

# 配置
GIT_BRANCH_PREFIX=${GIT_BRANCH_PREFIX:-feat/}
COMMIT_SCOPE=${COMMIT_SCOPE:-}
ITER_DIR="docs/iterations/$DATE/${SEQ}-${SLUG}-${TYPE}/"
DATE=$(date +%Y-%m-%d)

# 1. 创建分支
BRANCH_NAME="${GIT_BRANCH_PREFIX}${SLUG}-${DATE}"
git checkout -b "$BRANCH_NAME"
echo "🌿 分支: $BRANCH_NAME"

# 2. 暂存变更
git add -A

# 3. 确定 commit type
TYPE_MAP="feature:feat fix:fix refactor:refactor docs:docs test:test chore:chore"
COMMIT_TYPE=$(echo "$TYPE_MAP" | grep "^${TYPE}:*" | cut -d: -f2)

# 4. 确定 scope
if [ -z "$COMMIT_SCOPE" ]; then
  COMMIT_SCOPE=$(git diff --name-only --staged | \
    cut -d/ -f1 | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
fi

# 5. 提交
SUMMARY=$(head -c 72 "$ITER_DIR/requirements.md" | sed 's/[[:space:]]*$//')
git commit -m "${COMMIT_TYPE}(${COMMIT_SCOPE}): ${SUMMARY}"
echo "📝 提交: ${COMMIT_TYPE}(${COMMIT_SCOPE}): ${SUMMARY}"

# 6. 推送
git push origin "$BRANCH_NAME"
echo "📤 推送完成"

# 7. 创建 PR
PR_BODY="## 需求摘要\n\n$SUMMARY\n\n## 变更文件\n\n$(git diff --stat --staged)\n"
PR_URL=$(gh pr create \
  --title "${COMMIT_TYPE}(${COMMIT_SCOPE}): ${SUMMARY}" \
  --body "$PR_BODY" \
  --label "automated-sdlc")

echo "🔗 PR: $PR_URL"
echo "$PR_URL" > /tmp/sdlc-pr-url.txt
```

## 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| 分支已存在 | 切换到已存在分支，或使用 force |
| 暂存为空 | 警告，跳过 commit |
| PR 创建失败 | 手动创建说明，输出分支名 |
| gh 未认证 | 提示运行 `gh auth login` |

## 安全规则

1. **禁止直推 main/master** — 所有变更通过 PR
2. **禁止强制推送已存在 PR 的分支** — 避免覆盖协作历史
3. **提交信息规范** — 必须符合 Conventional Commits

## 相关文件

- 输入：所有代码 + 文档变更
- 输出：PR URL
- 参考：
  - SKILL.md Part 4（Pipeline 完成）
