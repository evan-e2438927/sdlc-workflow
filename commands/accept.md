---
description: 验收通过后总结变更、更新文档并在本地提交（不 push、不建 PR）
argument-hint: [<迭代目录>]
---

执行 `sdlc-workflow accept`，参数：$ARGUMENTS（详细规范见 `${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/references/flow-accept.md`）

查找迭代目录（若未指定，取最近一个 `phase == "qa_passed"`，否则 `phase == "applied"` 的目录）。

## 前置检查

- `phase == "qa_passed"`（已过 qa 验收）或 `phase == "applied"`（跳过 qa）才可执行
- 其他 phase → 提示先运行 `apply`

## 执行步骤

**变更总结**：基于 git diff + tasks.md 完成状态，归纳本次迭代涉及的 track、关键文件、
实现的 AC-ID（若已运行 qa，附上 e2e 报告结论），作为下面文档更新与 commit message 的输入。

**⑪ docs-updater**：按本次变更更新受影响文档：
- `README.md` — 新增功能说明
- `.claude/ARCHITECTURE.md` — 架构层面变更
- `.claude/SECURITY.md` — 安全相关变更
- `.claude/CODING_GUIDELINES.md` — 新模式/约定
- `.claude/CLAUDE.md` — 更新 iterations 引用列表

**⑫ git-committer**（本地提交，不 push、不建 PR）：
- 检测是否在 worktree 中
- Worktree 模式：复用已 checkout 的分支 → `git add -A → commit`
- 传统模式：`git checkout -b <prefix><slug>-date → add → commit`
- Commit 格式：`<type>(scope): <摘要>`（Conventional Commits）

完成后更新 `status.json`（phase: "accepted"），输出：
```
✅ 已本地提交 | 变更: N files
👉 推送并创建 PR: /sdlc-workflow:pr
```
