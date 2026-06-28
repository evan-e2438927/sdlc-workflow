---
description: 初始化或接入项目到 SDLC 工作流
argument-hint: 可选配置，如 review=1 branch=feat/ test-framework=jest
---

执行 `sdlc-workflow init`，参数：$ARGUMENTS

## 初始化流程

判断当前项目类型：
- **fresh project**：目录基本为空，首次接入
- **existing project**：已存在 `apps/`、`packages/`、`src/`、`package.json`、`.git/` 等结构

### 步骤

1. 检测 `.claude/CLAUDE.md` 和 `.claude/ARCHITECTURE.md` 是否存在
2. 若不存在 → 运行 `bash ${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/scripts/init-project.sh .`
   - 生成 `.claude/`（CLAUDE.md、ARCHITECTURE.md、SECURITY.md、CODING_GUIDELINES.md）
   - 生成 `docs/`、`tests/`，以及配置文件 `.claude/.sdlc-config`（自动加入 .gitignore）
   - 提醒用户：按需编辑 `.claude/.sdlc-config`
3. 若判定为 **existing project**，执行基线采集（`${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/references/00-existing-project-intake.md`）：
   - 生成 `.claude/PROJECT_BASELINE.md`、`.claude/EXISTING_STRUCTURE.md`、`.claude/TEST_BASELINE.md`
   - **基于真实代码填实** `.claude/ARCHITECTURE.md`、`.claude/SECURITY.md`（覆盖模板占位），对齐 `CODING_GUIDELINES.md` / `CLAUDE.md`——非 monorepo 项目不要保留模板的 monorepo 目录约定
   - 在基线完成前，不得直接进入 requirements/design/tasks

### 配置写入（若传入参数）

从 `$ARGUMENTS` 解析 key=value 格式写入 `.claude/.sdlc-config`：

| 参数 | 写入键 | 说明 |
|------|--------|------|
| `review=<n>` | REVIEW_MAX_ROUNDS | Codex 审查最大轮数 |
| `branch=<prefix>` | GIT_BRANCH_PREFIX | Git 分支前缀 |
| `test-framework=<fw>` | TEST_FRAMEWORK | 单元测试框架（jest/vitest/mocha） |
| `lint=<tool>` | LINT_TOOL | Lint 工具（eslint/biome） |

完成后输出：`✅ 项目初始化完成，迭代目录：docs/iterations/`
