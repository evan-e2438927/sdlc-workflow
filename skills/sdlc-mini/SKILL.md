---
name: sdlc-mini
description: >-
  Lightweight SDLC for tiny changes — keeps full iteration artifacts and
  verification but trims the pipeline; auto-upgrades to doit if scope grows
  (>3 files, API/data-model change). Use for mini / 小改动 / CSS / 文案 / 小 UI 修改.
---

# SDLC · mini（小任务轻量流程）

轻量但不跳过：仍生成 iteration 产物（requirements/design/tasks）、仍做验证。`--review` 启用 mini Gate 1/2；`--qa` 含浏览器验收。

## 步骤

1. 初始化迭代目录 `docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/`。
2. 精简需求拆解（精简版 ①②③④，提取核心 AC）。
3. [mini Gate 1] 仅 `--review`：Codex 轻量设计审查。
4. 实现代码（单任务或小规模并行）。
5. 生成单元测试（聚焦核心 AC）。
6. [mini Gate 2] 仅 `--review`：Codex 轻量代码审查。
7. test-pipeline（lint + unit）。
8. [qa] 仅 `--qa`：Playwright 浏览器功能验收。
9. docs-updater（仅更新受影响章节）→ git-committer（本地 commit）→ pr-creator（push + PR）。

**自动升级**：过程中发现影响 > 3 文件 / 改 API / 改数据模型 → 自动切换到 doit。**浏览器验收不精简**（最终通过标准）。

> 完整规范见 `sdlc-workflow` skill 的 `references/flow-mini.md`、`micro-change-mode.md`。
