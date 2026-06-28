# 步骤 ⑬: PR Creator — 推送并创建 PR

> 范围：**push → gh pr create**。前置是 accept 已在本地完成 commit（步骤 ⑫）。
> 本步是与远程/GitHub 交互的唯一环节，独立成 `pr` 命令，便于在确认本地提交无误后再发布。

## 入口

```bash
/sdlc-workflow pr [<迭代目录>]
```

若不指定路径，自动查找最近一个 `phase == "accepted"`（即已本地提交）的迭代目录。

## 前置条件

```bash
STATUS_FILE="$ITER_DIR/status.json"
PHASE=$(jq -r '.phase' "$STATUS_FILE")

case "$PHASE" in
  "accepted")   echo "✅ 已本地提交，开始 push + 创建 PR" ;;
  "pr_created") echo "⚠️ 该迭代已创建过 PR" ;;
  *)
    echo "❌ 当前 phase 为 $PHASE，请先运行 /sdlc-workflow:accept 完成本地提交"
    exit 1
    ;;
esac

# 必须存在本地未推送的 commit
git log --oneline @{upstream}..HEAD 2>/dev/null | head -1 \
  || echo "ℹ️ 当前分支无上游，将在 push 时建立"
```

## 详细行为

### 1. 推送

```bash
CURRENT_BRANCH=$(git branch --show-current)

# 禁止在 main/master 上操作
case "$CURRENT_BRANCH" in
  main|master)
    echo "❌ 当前在 $CURRENT_BRANCH，禁止直推。请先在 feature 分支提交"
    exit 1
    ;;
esac

git push -u origin "$CURRENT_BRANCH"
echo "📤 已推送: origin/$CURRENT_BRANCH"
```

### 2. 创建 PR

```bash
# 从迭代产物 + 变更摘要生成 PR body
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
| QA（浏览器） | ✅ / 跳过 |

## 变更文件

<!-- git diff --stat origin/main...HEAD -->

## 迭代信息

- 迭代目录: `docs/iterations/<date>/<seq>-<slug>-<type>/`

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)

PR_URL=$(gh pr create \
  --base main \
  --title "${COMMIT_TYPE}(${COMMIT_SCOPE}): ${SUMMARY}" \
  --body "$PR_BODY" \
  --label "automated-sdlc")

echo "🔗 PR: $PR_URL"
```

### 3. 更新 status.json

```bash
jq '.phase = "pr_created" | .pr_created_at = now | .pr_url = "<url>"' \
  "$STATUS_FILE" > tmp.json && mv tmp.json "$STATUS_FILE"

# worktree 模式：同步注册表中的 pr_url（若注册表可达）
echo "✅ PR: <url> | 分支: $CURRENT_BRANCH"
```

## 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| phase != accepted | 中止，提示先运行 accept |
| 当前在 main/master | 中止，禁止直推 |
| 无本地 commit | 提示先 accept 提交 |
| `gh` 未认证 | 提示运行 `gh auth login` |
| push / gh pr 失败 | 输出错误，phase 保持 accepted，待修复后重跑 |

## 安全规则

1. **禁止直推 main/master** — 只对 feature branch 操作
2. **禁止强制推送已有 PR 的分支** — 避免覆盖协作历史
3. push 与 PR 是唯一的远程/外发动作，需在本地提交确认后执行

## 相关文件

- 输入：本地 commit（accept 产出）+ 迭代产物
- 输出：远程分支 + PR URL
- 参考：
  - references/11-git-committer.md（前一步：本地提交）
  - references/parallel-dev.md（worktree 模式分支管理）
