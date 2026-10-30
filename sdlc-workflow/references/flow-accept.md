# Accept — 验收提交流程（本地）

## 概述

`/sdlc-workflow accept <迭代目录>` 是验收通过后的**收尾命令**：总结本次迭代的全部
变更，更新受影响文档，然后在本地 **commit**（步骤 ⑪ docs-updater + ⑫ git-committer）。

它**不做浏览器功能测试**（那是 `qa` 命令），**不写业务代码**（那是 `apply`），
也**不 push、不建 PR**（那是 `pr` 命令）。accept 只负责「定稿到本地」：
变更总结 → 文档 → 本地 commit。push 与 PR 由 `pr` 命令单独执行。

## 入口

```bash
/sdlc-workflow accept <迭代目录>
# 示例
/sdlc-workflow accept docs/iterations/2026-04-16/001-user-login-feature/
```

若不指定路径，用 `bash "$SDLC_STATUS" find-latest qa_passed applied` 自动定位
（`SDLC_STATUS` 见 SKILL.md「迭代状态（phase）」）。

## 前置条件

```bash
STATUS_FILE="$ITER_DIR/status.json"

if [ ! -f "$STATUS_FILE" ]; then
  echo "❌ 未找到 status.json，请先运行 apply 流程"
  exit 1
fi

PHASE=$(jq -r '.phase' "$STATUS_FILE")

case "$PHASE" in
  "qa_passed") echo "✅ QA 已通过，开始定稿提交" ;;
  "applied")   echo "⚠️ 未运行 qa（浏览器验收），将直接定稿提交" ;;
  "accepted")  echo "⚠️ 该迭代已 accept 过，如需推送请运行 sdlc-pr"; exit 1 ;;
  "qa_failed") echo "❌ QA 发现代码缺陷尚未修复，请先运行 sdlc-apply（修复模式）"; exit 1 ;;
  *)
    echo "❌ 当前 phase 为 $PHASE，请先完成 apply"
    exit 1
    ;;
esac

# 跳过 qa 的确认：最近一次 qa_failed 之后没有 qa_passed → 先问用户
if [ "$PHASE" = "applied" ] && jq -e '
     (.history // []) as $h
     | ([$h | to_entries[] | select(.value.to == "qa_failed") | .key] | max) as $f
     | $f != null and ([$h | to_entries[] | select(.value.to == "qa_passed" and .key > $f)] | length) == 0
   ' "$STATUS_FILE" >/dev/null; then
  ASK "上次 QA 失败、修复后尚未重新验收，确定跳过 qa 提交吗？"   # 用户确认才继续；否则提示运行 sdlc-qa 并中止
fi
```

## 执行步骤

### 1. 总结本次变更

```
基于 git diff（自迭代分支创建以来）+ tasks.md 完成状态，归纳：
  - 变更涉及的 track（frontend / backend / unit-test）
  - 新增/修改的关键文件与模块
  - 实现了 requirements.md 中的哪些 AC-ID
  - 若已运行 qa：附上 tests/reports/<slug>-e2e-report.md 的结论
输出一段「变更摘要」，作为 docs-updater 与 commit message 的输入。
```

### 2. ⑪ docs-updater — 更新受影响文档

按变更摘要，仅更新真正受影响的文档章节：

| 文档 | 何时更新 |
|------|----------|
| `README.md` | 新增对用户可见的功能 |
| `.agents/ARCHITECTURE.md` | 架构层面的新增/调整 |
| `.agents/SECURITY.md` | 安全相关变更 |
| `.agents/CODING_GUIDELINES.md` | 引入新模式/约定 |
| `.agents/AGENTS.md` | 在 iterations 引用列表追加本次迭代 |

详见 references/10-docs-updater.md。

文档更新后检查各级 `AGENTS.md` 引用的仓库内路径是否仍然存在（`SDLC_CORE` 见核心 SKILL.md「核心目录（SDLC_CORE）」）：

```bash
bash "$SDLC_CORE/scripts/sdlc-sync-agents.sh" --check-paths .
```

列出的失效路径（本次改名、删除导致的 Markdown 链接或反引号路径失效）作为**提示**写进 accept 输出，建议顺手修正；**不阻断** accept，也不影响 commit。

### 3. ⑫ git-committer — 本地提交（不 push、不建 PR）

```
检测是否在 worktree 中：
  - Worktree 模式：复用已 checkout 的分支 → git add -A → commit
  - 传统模式：git checkout -b <prefix><slug>-<date> → add → commit
Commit message 采用 Conventional Commits：<type>(scope): <摘要>，正文引用变更摘要。
```

详见 references/11-git-committer.md。

### 4. 更新 status.json

```bash
# 本地提交成功
bash "$SDLC_STATUS" transition "$ITER_DIR" accepted --by accept

echo "✅ 已本地提交 | 变更: N files"
echo "👉 推送并创建 PR: /sdlc-workflow:pr"
```

## 失败处理

| 错误场景 | 处理方式 |
|----------|----------|
| status.json 不存在 / phase 非法 | 中止，提示先 apply |
| 无变更可提交 | 提示无 diff，中止 |
| commit 失败（hook 拦截等） | 输出错误，phase 保持不变，待修复后重跑 |

## 自动查找最近可验收迭代

```bash
if [ -z "$ITER_DIR" ]; then
  ITER_DIR=$(bash "$SDLC_STATUS" find-latest qa_passed applied)
  if [ -z "$ITER_DIR" ]; then
    echo "❌ 未找到已完成 apply 的迭代目录"
    exit 1
  fi
  echo "📂 自动定位到: $ITER_DIR"
fi
```

## 输入 / 输出

| | 路径 | 说明 |
|--|------|------|
| 输入 | `docs/iterations/.../tasks.md` | 完成状态 + AC 来源 |
| 输入 | `docs/iterations/.../status.json` | 确认 phase == qa_passed / applied |
| 输入 | git diff | 变更总结来源 |
| 输出 | 受影响文档 | README / ARCHITECTURE / SECURITY / CLAUDE 等 |
| 输出 | 本地 commit | git-committer 产出（未推送）|
| 输出 | `docs/iterations/.../status.json` | 经状态脚本迁移到 accepted |

## 流程中的位置

```
proposal → apply → qa → accept → pr
                          ↑ 你在这里（更新文档 + 本地 commit）
                                   └─ 下一步：push + 创建 PR
```

## 相关文件

- `references/flow-apply.md` — 前置步骤（开发 + 单元测试）
- `references/09-test-pipeline.md` — lint + unit 自检
- `references/10-docs-updater.md` — 文档更新（⑪）
- `references/11-git-committer.md` — 本地提交（⑫）
- `references/12-pr-creator.md` — 下一步：push + 创建 PR（⑬）
