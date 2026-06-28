---
name: sdlc-update
description: >-
  Two-phase upgrade sync for an already-initialized project — phase 1 safely
  syncs the latest scaffold (idempotent, never overwrites user content); phase 2
  reads real code and does a drift-aware incremental refresh (baselines
  auto-refresh, user docs per-item confirm). Use for update / 升级同步 after the
  plugin updates, or when baselines/architecture docs look stale.
---

# SDLC · update（两阶段升级同步）

前置：项目已 init（存在 `.claude/CLAUDE.md`）。不改业务代码、不触发开发流程。

## 阶段一 —— 机械同步（幂等，非交互）

运行 `scripts/update-project.sh .`（相对 skill 目录；Claude Code 下为 `${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/scripts/update-project.sh`）：补目录结构、迁移 `.claude/.sdlc-config`（保留用户值/补新键/删废弃键）、刷新 `workflow-rules.md`、缺失用户文档才补、`.gitignore` 兜底。汇报变更摘要。

## 阶段二 —— 增量 intake（读真实代码，漂移感知）

按 `references/00-existing-project-intake.md`「增量 update 模式」：

1. **漂移扫描**：读真实文件树 + 根配置，产出漂移报告（配置漂移 / 基线过时 / 文档占位过时）。先报告不改文件。
2. **基线文档**（PROJECT_BASELINE / EXISTING_STRUCTURE / TEST_BASELINE）：派生事实，**自动**刷新，旧版 `.bak`。
3. **用户文档**（ARCHITECTURE / SECURITY / CLAUDE / CODING_GUIDELINES）：**逐项征求确认**后才改，旧版 `.bak`；拒绝则不动。
4. **配置漂移**：逐项提议 + 确认（如 vitest vs `.sdlc-config` 的 jest）。

> 完整规范见 `sdlc-workflow` skill 的 `references/00-existing-project-intake.md`。
