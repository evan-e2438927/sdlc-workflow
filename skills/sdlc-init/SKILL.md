---
name: sdlc-init
description: >-
  Initialize or onboard a project into the SDLC Workflow. Scaffolds .claude/
  context, configs, docs/ and tests/, and for existing projects runs baseline
  intake so the agent doesn't rebuild your structure. Use when the user wants to
  init / set up / 接入 / 初始化 a repo to the SDLC pipeline before requirements work.
---

# SDLC · init

把项目初始化或接入 SDLC 工作流。产出 phase 前置步骤 ⓪。

## 步骤

1. 判断项目类型：目录基本为空 → **fresh**；已有 `apps/`/`packages/`/`src/`/`package.json`/`.git/` → **existing**。
2. 检测 `.claude/CLAUDE.md` + `.claude/ARCHITECTURE.md`；不存在则运行初始化脚本
   `scripts/init-project.sh .`（相对 skill 目录；Claude Code 下为 `${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/scripts/init-project.sh`）。
   生成 `.claude/`（CLAUDE/ARCHITECTURE/SECURITY/CODING_GUIDELINES）、`docs/`、`tests/`、`.claude/.sdlc-config`（自动 gitignore）。
3. **existing project** → 必须先做基线采集（见 `references/00-existing-project-intake.md`）：
   生成 `PROJECT_BASELINE/EXISTING_STRUCTURE/TEST_BASELINE`，并**基于真实代码填实** ARCHITECTURE/SECURITY（覆盖模板占位）。基线完成前不得进入 requirements/design/tasks。

## 配置参数（key=value）

`review=<n>`→REVIEW_MAX_ROUNDS · `branch=<prefix>`→GIT_BRANCH_PREFIX · `test-framework=<fw>`→TEST_FRAMEWORK · `lint=<tool>`→LINT_TOOL，写入 `.claude/.sdlc-config`。

> 完整规范见 `sdlc-workflow` skill 的 `SKILL.md`「项目初始化」与 `references/00-existing-project-intake.md`。
