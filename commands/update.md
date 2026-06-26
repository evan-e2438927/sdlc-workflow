---
description: 插件升级后把最新脚手架安全同步到已初始化项目，并增量检测代码漂移、刷新过时基线/文档（逐项确认，绝不盲目覆盖）
argument-hint: "[项目目录，默认当前目录]"
---

执行 `sdlc-workflow update`，参数：$ARGUMENTS

插件持续迭代、且项目代码自身也在演进。本命令分两个阶段：先把最新脚手架**安全幂等**地同步进来，
再**读真实代码**做漂移感知的增量刷新——绝不覆盖用户编辑过的内容。

## 前置检查

- 项目必须已初始化（存在 `.claude/CLAUDE.md`）；否则提示先运行 `/sdlc-workflow:init`

## 阶段一 —— 机械同步（幂等，非交互）

运行同步脚本（`${CLAUDE_PLUGIN_ROOT}` 为插件根目录，由 Claude Code 注入）：

```bash
bash ${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/scripts/update-project.sh .
```

脚本行为（全部幂等、可重复运行）：

1. **目录结构**：补齐缺失的 `.claude/rules`、`docs/iterations`、`tests/{unit,e2e,reports}` 等
2. **配置迁移** `.claude/.sdlc-config`：备份旧文件到 `.sdlc-config.bak`；以最新模板为骨架（带最新注释 +
   新增键的默认值）；**保留**用户已设置的值及自定义非废弃键（如 worktree 注入的 `PORT`/`API_PORT`）；
   **移除**已废弃的键（如 `TG_USERNAME`、`PARALLEL_TESTS`）；报告新增 / 保留 / 移除的键
3. **刷新插件托管文件** `.claude/rules/workflow-rules.md`：与最新模板不一致时备份旧版（`.bak`）后刷新
4. **用户文档**：`CLAUDE.md` / `ARCHITECTURE.md` / `SECURITY.md` / `CODING_GUIDELINES.md` 仅在**缺失时**
   从模板补齐，**已存在则绝不覆盖**
5. `.gitignore` 兜底加入 `.claude/.sdlc-config*`

向用户汇报脚本输出的变更摘要。

## 阶段二 —— 增量 intake（读真实代码，漂移感知）

阶段一完成后，按 `${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/references/00-existing-project-intake.md`
的「## 增量 update 模式（drift-aware refresh）」执行：

1. **漂移扫描**：读取真实文件树 + 根级配置，与已记录状态比对，产出**漂移报告**（配置漂移 / 基线过时 /
   文档过时三类，逐项给出漂移点与拟刷新要点；无漂移项标注「无漂移」）。先展示报告，不改任何文件。
2. **基线文档**（`PROJECT_BASELINE.md` / `EXISTING_STRUCTURE.md` / `TEST_BASELINE.md`）：派生事实，
   **自动**按真实代码重生成，旧版备份为 `.bak`，仅汇报不逐项 gate。
3. **用户文档**（`ARCHITECTURE.md` / `SECURITY.md` / `CLAUDE.md` / `CODING_GUIDELINES.md`）：
   **逐项征求确认**——展示漂移点与拟刷新内容，用户同意才重写并备份 `.bak`；拒绝则保持原样。
4. **配置漂移**：逐项提议 + 确认（如 vitest vs `.sdlc-config` 的 jest），确认后才改写对应键。

若阶段二扫描结果为「无漂移」，明确告知用户无需刷新，不产生多余 `.bak`。

## 收尾

- 汇总两个阶段的全部变更（机械同步摘要 + 漂移报告结论 + 已刷新 / 用户拒绝的文档清单）
- 若生成了 `.bak` 备份（workflow-rules.md / .sdlc-config / 基线 / 已确认刷新的用户文档），
  提醒用户对照备份回并自定义内容
- 不修改任何业务代码，不触发 proposal/apply 等开发流程

> 何时运行：升级插件版本后（`/plugin update` 或 `claude plugins update` 之后），或项目代码有较大演进、
> 怀疑基线/架构文档过时时，在每个已接入的项目里跑一次。
