# Incremental Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `/sdlc-workflow:update` into a two-phase command — keep today's mechanical file-sync as phase 1, add an LLM-driven drift-aware "incremental intake" as phase 2 that refreshes stale baselines automatically and proposes user-doc refreshes with per-item confirmation.

**Architecture:** No bash logic changes. `scripts/update-project.sh` stays exactly as-is and remains phase 1. All new intelligence is instructions, authored in `commands/update.md` (the orchestrator) and `sdlc-workflow/references/00-existing-project-intake.md` (a new "增量 update 模式" section that the command points to, reusing intake's single source of truth for doc-generation rules). SKILL.md / README descriptions are updated to match.

**Tech Stack:** Markdown skill/command/reference files for Claude Code plugin; existing `update-project.sh` (bash) unchanged.

## Global Constraints

- Phase 1 (`scripts/update-project.sh`) behavior MUST NOT change — zero behavior delta.
- Phase 2 MUST NOT touch business code or trigger any development flow (proposal/apply/qa/accept/pr).
- Baselines (`PROJECT_BASELINE.md`, `EXISTING_STRUCTURE.md`, `TEST_BASELINE.md`) auto-refresh with `.bak` backup; reported, not gated.
- User-prose docs (`ARCHITECTURE.md`, `SECURITY.md`, `CLAUDE.md`, `CODING_GUIDELINES.md`) are NEVER overwritten without explicit per-item user confirmation; backed up to `.bak` when changed.
- Doc-generation requirements live in ONE place: `00-existing-project-intake.md`. The command references it, never duplicates it.
- All file paths below are relative to repo root `/Users/panda/Documents/work-spaces/sdlc-workflow`. Plugin-internal paths referenced at runtime use `${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/...`.
- Language: all user-facing instruction text in Simplified Chinese, matching existing files.

---

### Task 1: Add "增量 update 模式" section to the intake reference

**Files:**
- Modify: `sdlc-workflow/references/00-existing-project-intake.md` (append a new top-level section after the existing "### 6. 完成输出")
- Verify: read-back of the modified file

**Interfaces:**
- Produces: a section anchored by the heading `## 增量 update 模式（drift-aware refresh）` that `commands/update.md` phase 2 will reference by name. It reuses the existing output-doc list (PROJECT_BASELINE / EXISTING_STRUCTURE / TEST_BASELINE / ARCHITECTURE / SECURITY / CODING_GUIDELINES / CLAUDE) and the existing "完成条件" as the post-refresh validation bar.

- [ ] **Step 1: Write the new section**

Append to `sdlc-workflow/references/00-existing-project-intake.md`:

```markdown

## 增量 update 模式（drift-aware refresh）

本小节供 `/sdlc-workflow:update` 的阶段二复用。与首次 intake 的区别：作用对象是**已存在**的文档，
按 **diff / 刷新**而非从零生成，并区分两类所有权。

### 触发与前提

- 仅在项目已 init（存在 `.claude/CLAUDE.md`）且阶段一机械同步已完成后运行。
- 复用本文件「2. 基线分析范围」「3. 输出文档要求」「5. 完成条件」作为生成标准与刷新后的校验标准。

### 漂移扫描（产出报告，先不改文件）

读取真实文件树 + 根级配置（`package.json`、`pnpm-workspace.yaml`、`turbo.json`、`docker-compose.yml` 等），
与已记录状态比对，产出**漂移报告**，至少覆盖三类：

1. **配置漂移**：`.claude/.sdlc-config` 的 `TEST_FRAMEWORK` / `LINT_TOOL` / 结构假设 vs 真实仓库。
2. **基线过时**：三份 baseline 缺失，或与当前 workspace / 依赖 / 脚本 / 测试套件不符。
3. **文档过时**：`ARCHITECTURE.md` / `SECURITY.md` 仍含 `<!-- 请描述 -->` 占位，或所述结构与真实代码不符；
   `CLAUDE.md` / `CODING_GUIDELINES.md` 的落位约定与真实结构不符。

报告对每一项给出：文档名 / 漂移点 / 拟刷新的要点。无漂移的项明确标注「无漂移」。

### 两类所有权的处理

- **基线文档**（`PROJECT_BASELINE.md` / `EXISTING_STRUCTURE.md` / `TEST_BASELINE.md`）——派生事实，
  **自动**按真实代码重生成；重写前把旧版备份为同名 `.bak`；仅在报告中汇报，不逐项征求确认。
- **用户文档**（`ARCHITECTURE.md` / `SECURITY.md` / `CLAUDE.md` / `CODING_GUIDELINES.md`）——含用户手写内容，
  **逐项征求确认**：展示该文档的漂移点与拟刷新内容，用户明确同意后才重写，重写前备份 `.bak`；
  未确认的文档保持原样。这是 update「绝不盲目覆盖用户内容」原则的延续。

### 配置漂移修正

对扫描出的配置漂移逐项**提议 + 确认**（如「仓库用 vitest，但 `.sdlc-config` 写 jest——是否修正？」），
确认后才改写 `.claude/.sdlc-config` 对应键。

### 完成条件

- 刷新后的基线 / 用户文档满足本文件「5. 完成条件」（无模板占位、目录约定与真实结构一致）。
- 未获确认的用户文档保持原样，不产生多余 `.bak`。
- 全程不触碰业务代码、不触发开发流程。
```

- [ ] **Step 2: Verify the section reads correctly and references resolve**

Run: `grep -n "增量 update 模式" sdlc-workflow/references/00-existing-project-intake.md`
Expected: one match for the new heading.

Run: `grep -n "完成条件\|输出文档要求\|基线分析范围" sdlc-workflow/references/00-existing-project-intake.md`
Expected: the referenced section names ("完成条件", "输出文档要求"/"输出", "基线分析范围") exist in the file so the new section's back-references are valid. If a referenced heading's wording differs, fix the new section's wording to match the actual headings.

- [ ] **Step 3: Commit**

```bash
git add sdlc-workflow/references/00-existing-project-intake.md
git commit -m "feat(update): add incremental drift-aware mode to intake reference

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Rewrite `commands/update.md` as a two-phase orchestrator

**Files:**
- Modify: `commands/update.md` (replace the body; keep the frontmatter `description` / `argument-hint`, update `description` wording to mention drift refresh)
- Verify: read-back

**Interfaces:**
- Consumes: Task 1's `## 增量 update 模式（drift-aware refresh）` section in `00-existing-project-intake.md`, by reference path `${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/references/00-existing-project-intake.md`.
- Produces: the two-phase user-facing contract that SKILL.md / README (Task 3) describe.

- [ ] **Step 1: Replace the command body**

Overwrite `commands/update.md` with:

```markdown
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
```

- [ ] **Step 2: Verify structure and the cross-reference path**

Run: `grep -n "阶段一\|阶段二\|增量 update 模式\|update-project.sh" commands/update.md`
Expected: both phase headings present, the reference to "增量 update 模式" present, and the phase-1 script path present.

Run: `test -f sdlc-workflow/references/00-existing-project-intake.md && echo OK`
Expected: `OK` (the referenced reference file exists).

- [ ] **Step 3: Commit**

```bash
git add commands/update.md
git commit -m "feat(update): rewrite update command as two-phase orchestrator

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Sync the `update` description in SKILL.md and README

**Files:**
- Modify: `sdlc-workflow/SKILL.md:37` (the `/sdlc-workflow update` bullet)
- Modify: `sdlc-workflow/README.md` (any line describing `update`; locate first)
- Modify: `README.md` (repo root, if it describes `update`; locate first)

**Interfaces:**
- Consumes: the two-phase contract defined in Task 2.

- [ ] **Step 1: Locate every place `update` is described**

Run: `grep -rn "update" sdlc-workflow/SKILL.md README.md sdlc-workflow/README.md`
Expected: at least `sdlc-workflow/SKILL.md:37`. Note each line that describes the update command's behavior (ignore unrelated word matches).

- [ ] **Step 2: Update the SKILL.md bullet**

In `sdlc-workflow/SKILL.md`, replace the line:

```
- `/sdlc-workflow update [项目目录]`：插件升级后，把最新脚手架（结构/配置/规则模板）安全同步到已初始化项目（不覆盖用户内容）
```

with:

```
- `/sdlc-workflow update [项目目录]`：两阶段升级同步——阶段一安全同步最新脚手架（结构/配置/规则模板，不覆盖用户内容）；阶段二读真实代码做漂移感知增量刷新（基线自动刷新、用户文档逐项确认）
```

- [ ] **Step 3: Update README descriptions to match**

For each `update`-describing line found in Step 1 within `README.md` and `sdlc-workflow/README.md`, edit it to reflect the two-phase behavior (mechanical sync + drift-aware incremental refresh with per-item confirmation). Match the surrounding wording/format of each README. If a README has no such line, make no change to it.

- [ ] **Step 4: Verify**

Run: `grep -rn "两阶段\|漂移" sdlc-workflow/SKILL.md README.md sdlc-workflow/README.md`
Expected: the SKILL.md bullet (and any README lines you edited) now mention the two-phase / drift behavior.

- [ ] **Step 5: Commit**

```bash
git add sdlc-workflow/SKILL.md README.md sdlc-workflow/README.md
git commit -m "docs(update): describe two-phase drift-aware update in SKILL/README

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: End-to-end dry-run validation

**Files:**
- No file changes (validation only). Use scratchpad for a throwaway test project.

**Interfaces:**
- Consumes: Tasks 1-3 (the full command + reference + descriptions).

- [ ] **Step 1: Build a stale fixture project**

Create a throwaway project under the scratchpad that is "already init'd but drifted": copy the templates into a `.claude/` dir, then introduce drift (e.g. a `package.json` declaring `vitest` while `.sdlc-config` says `TEST_FRAMEWORK=jest`, and an `ARCHITECTURE.md` left at template placeholders).

```bash
FIX=/private/tmp/claude-501/-Users-panda-Documents-work-spaces-sdlc-workflow/ae28afe1-c639-43a3-a047-a33f3cec7ca6/scratchpad/upd-fixture
rm -rf "$FIX" && mkdir -p "$FIX/.claude/rules" "$FIX/src"
cp sdlc-workflow/templates/CLAUDE.md.tpl "$FIX/.claude/CLAUDE.md"
cp sdlc-workflow/templates/ARCHITECTURE.md.tpl "$FIX/.claude/ARCHITECTURE.md"
cp sdlc-workflow/templates/SECURITY.md.tpl "$FIX/.claude/SECURITY.md"
cp sdlc-workflow/templates/CODING_GUIDELINES.md.tpl "$FIX/.claude/CODING_GUIDELINES.md"
cp sdlc-workflow/templates/sdlc-config.tpl "$FIX/.claude/.sdlc-config"
cp sdlc-workflow/templates/workflow-rules.md.tpl "$FIX/.claude/rules/workflow-rules.md"
printf '{\n  "name": "upd-fixture",\n  "devDependencies": { "vitest": "^2.0.0" }\n}\n' > "$FIX/package.json"
echo "TEST_FRAMEWORK=jest" >> "$FIX/.claude/.sdlc-config"
echo "$FIX"
```

Expected: prints the fixture path; the fixture has a vitest `package.json` but `.sdlc-config` claiming jest.

- [ ] **Step 2: Run phase 1 (the unchanged script) against the fixture**

Run: `bash sdlc-workflow/scripts/update-project.sh "$FIX"`
Expected: script reports directory alignment + config migration and exits 0, with no error. (This confirms Task 2 did not break the phase-1 invocation contract.)

- [ ] **Step 3: Walk phase 2 manually against the fixture**

Following `commands/update.md` phase 2 + the intake "增量 update 模式" section, manually perform the drift scan on `$FIX`: confirm you can produce a drift report that (a) flags the jest-vs-vitest config drift, (b) flags `ARCHITECTURE.md`/`SECURITY.md` template placeholders as doc drift, and (c) classifies baselines as "missing" (they don't exist in the fixture). Confirm the instructions tell you to auto-generate baselines but to ask before rewriting `ARCHITECTURE.md`.

Expected: the report is producible purely from the written instructions — if any step is ambiguous or missing, fix the relevant file (Task 1 or 2) and re-commit.

- [ ] **Step 4: Clean up fixture**

Run: `rm -rf "$FIX"`
Expected: no output, fixture removed.

- [ ] **Step 5: Final verification of the whole change**

Run: `git log --oneline -5 && git status --short`
Expected: commits from Tasks 1-3 present; working tree clean (fixture was in scratchpad, not the repo).
```
