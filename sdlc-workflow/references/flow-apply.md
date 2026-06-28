# Apply — 需求开发命令

## 概述

`/sdlc-workflow apply <迭代目录>` 在 proposal 产物经人工审核后，
继续执行**开发 + 单元测试 + 静态检查**（步骤 ⑥-⑨）。

**apply 不更新文档、不提交、不推 PR**——这些属于 `accept` 验收流程；
浏览器功能验收（Playwright）属于 `qa` 命令。apply 只负责把代码写出来并通过
lint + unit 自检，产物停在 `phase == "applied"`。

## 入口

```
/sdlc-workflow apply <迭代目录>
```

参数为 proposal 生成的迭代目录路径：

```bash
# 示例
/sdlc-workflow apply docs/iterations/2026-04-13/001-user-login-feature/
```

若不指定路径，自动查找最近一个 `phase == "pending_review"` 或 `phase == "approved"` 的迭代目录。

## 前置检查

### 1. status.json 校验

```bash
STATUS_FILE="$ITER_DIR/status.json"

if [ ! -f "$STATUS_FILE" ]; then
  echo "❌ 未找到 status.json，请先运行 /sdlc-workflow proposal"
  exit 1
fi

PHASE=$(jq -r '.phase' "$STATUS_FILE")

case "$PHASE" in
  "pending_review")
    # 交互确认：用户直接 apply 视为审核通过
    echo "📋 该 proposal 尚处于 pending_review 状态"
    echo "   运行 apply 将视为审核通过并开始开发"
    # 更新状态为 approved
    jq '.phase = "approved" | .reviewed_at = now | .reviewer = "cli-apply"' \
      "$STATUS_FILE" > tmp.json && mv tmp.json "$STATUS_FILE"
    ;;
  "approved")
    echo "✅ Proposal 已通过审核，开始开发"
    ;;
  "applied")
    echo "⚠️ 该 proposal 已执行过 apply"
    echo "   如需重新执行，请手动将 status.json 中 phase 改为 approved"
    exit 1
    ;;
  "rejected")
    echo "❌ 该 proposal 已被拒绝"
    echo "   请修改后重新运行 /sdlc-workflow proposal"
    exit 1
    ;;
  *)
    echo "❌ 未知状态: $PHASE"
    exit 1
    ;;
esac
```

### 2. 产物完整性检查

```bash
REQUIRED_FILES=("requirements.md" "design.md" "tasks.md")
for f in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "$ITER_DIR/$f" ]; then
    echo "❌ 缺少必需文件: $f"
    exit 1
  fi
done
```

### 3. 初始化检查

```bash
if [ ! -f ".claude/CLAUDE.md" ] || [ ! -f ".claude/ARCHITECTURE.md" ]; then
  echo "❌ 项目未初始化，请先运行 /sdlc-workflow init"
  exit 1
fi
```

## 执行步骤

```
读取 $ITER_DIR/status.json → 校验 phase
读取 $ITER_DIR/tasks.md → 获取任务列表

⑥ Claude Code 开发
   只实现 frontend / backend / unit-test 三类 track 的任务
   （track: qa 的任务不在此实现，留给 qa 命令）
   解析 tasks.md 依赖关系，构建拓扑分层
   若存在可并行层（层内 >1 任务且无目标文件交集）→ Agent Team 并行
   否则 → 顺序逐任务实现
   每完成一个任务同步回写 tasks.md

⑦ test-generator
   仅生成单元测试（tests/unit/），处理 track: unit-test 的任务
   不生成 E2E/浏览器测试（由 qa 命令负责）

[⑧ code-reviewer (Gate 2)   ← 仅 --review 模式]
   Codex CLI 审查代码

⑨ test-pipeline
   lint → unit（两阶段，不含浏览器 E2E）

更新 status.json:
  phase: "applied"
  applied_at: <当前时间>
```

> ⑩ 浏览器功能验收 → `qa` 命令；⑪ docs-updater + ⑫ git-committer → `accept` 命令。

## 自动查找最近 proposal

当用户不指定迭代目录时，自动定位：

```bash
find_latest_proposal() {
  find docs/iterations/ -name "status.json" -type f \
    | while read f; do
        phase=$(jq -r '.phase' "$f")
        if [ "$phase" = "pending_review" ] || [ "$phase" = "approved" ]; then
          echo "$f"
        fi
      done \
    | sort -r \
    | head -1 \
    | xargs dirname
}

if [ -z "$ITER_DIR" ]; then
  ITER_DIR=$(find_latest_proposal)
  if [ -z "$ITER_DIR" ]; then
    echo "❌ 未找到待处理的 proposal"
    echo "   请先运行 /sdlc-workflow proposal <需求>"
    exit 1
  fi
  echo "📂 自动定位到: $ITER_DIR"
fi
```

## 控制台输出

### Apply 启动

```
🚀 开始执行需求开发

📂 迭代目录: <iter_dir>
📝 任务数: <N> | 预估工时: <N>h
🔍 Proposal 审核通过 ✅
```

### Apply 完成

```
✅ 开发完成: N 个任务 | 测试: lint + unit 全部通过
📂 迭代目录: <iter_dir>
👉 浏览器验收请运行: /sdlc-workflow:qa
👉 确认无误后提交: /sdlc-workflow:accept
```

## 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| status.json 不存在 | 中止，提示先运行 proposal |
| phase 为 rejected | 中止，提示修改后重新 proposal |
| phase 为 applied | 中止，提示已执行过（需手动重置） |
| 产物文件缺失 | 中止，提示重新 proposal |
| Gate 2 超限（--review 时） | 中止，控制台输出错误，提示人工介入 |
| lint / unit 修复超限 | 中止，控制台输出错误，提示人工介入 |

## status.json 更新

### Apply 开始时

```json
{
  "phase": "approved",
  "reviewed_at": "2026-04-13T15:00:00+08:00",
  "reviewer": "cli-apply"
}
```

### Apply 完成时

```json
{
  "phase": "applied",
  "applied_at": "2026-04-13T16:30:00+08:00"
}
```

## 流程中的位置

```
proposal → 人工审核 → apply → qa → accept → pr
  ①-⑤              ⑥-⑨    ⑩    ⑪⑫       ⑬

proposal = 步骤①-⑤ + 暂停（pending_review）
apply    = 步骤⑥-⑨（开发 + 单元测试 + lint，phase: applied）
qa       = 步骤⑩（浏览器功能验收，phase: qa_passed）
accept   = 步骤⑪⑫（更新文档 + 本地 commit，phase: accepted）
pr       = 步骤⑬（push + 创建 PR，phase: pr_created）
doit     = proposal + apply (+ qa --qa) + accept + pr，不停顿
```

## 相关文件

- 输入：
  - docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/requirements.md
  - docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/design.md
  - docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/tasks.md
  - docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/status.json
- 输出：
  - 代码变更
  - tests/unit/ + tests/reports/
  - status.json（phase: applied）
- 参考：
  - references/flow-proposal.md（前置步骤）
  - references/08-code-reviewer.md（Gate 2）
  - references/09-test-pipeline.md（lint + unit）
  - references/flow-accept.md（后续：更新文档 + 提交）
