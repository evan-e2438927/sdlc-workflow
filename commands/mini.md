---
description: 小任务轻量流程，保留完整 iteration 产物和验证
argument-hint: [--review] [--qa] <小任务描述>
---

执行 `sdlc-workflow mini`，参数：$ARGUMENTS

读取并遵循 `${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/SKILL.md` 中的 mini-pipeline 规范（`${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/references/flow-mini.md`）。当前执行 **mini** 轻量模式。

## 关键规则

- 轻量但不跳过：仍需创建 iteration 产物（requirements.md / design.md / tasks.md）
- 仍需执行 validation capability detection
- `--review` 时执行 mini Gate 1 + mini Gate 2
- `--qa` 时执行 Playwright 浏览器功能验收

## 执行步骤

1. 初始化迭代目录（`docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/`）
2. 简化需求拆解（精简版 ①②③④，重点提取核心 AC）
3. [mini Gate 1]（仅 `--review`）：Codex 轻量设计审查
4. 实现代码（单任务或小规模并行）
5. 生成单元测试（聚焦核心 AC）
6. [mini Gate 2]（仅 `--review`）：Codex 轻量代码审查
7. test-pipeline（lint + unit）
8. [qa]（仅 `--qa`）：Playwright 浏览器功能验收
9. docs-updater（仅更新受影响章节）
10. git-committer → branch → commit（本地）
11. pr-creator → push → gh pr create
