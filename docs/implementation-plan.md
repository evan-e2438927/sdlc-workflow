# 新增 `proposal` / `apply` 命令 + 文档目录迁移

> 注：状态机的现行定义见 `sdlc-workflow/SKILL.md`「迭代状态（phase）」。本文是 proposal / apply 拆分时的历史计划，正文保留原貌。

## 背景

两个改动：
1. **参考 OpenSpec 模式**，将当前 `doit` 的一体化流程拆分为 `proposal`（需求拆解）和 `apply`（需求开发）两个独立命令，中间插入**人工审核环节**
2. **将 `ARCHITECTURE.md`、`CODING_GUIDELINES.md`、`SECURITY.md` 迁移到 `.claude/` 目录**，与 `CLAUDE.md` 放在一起

---

## User Review Required

> [!IMPORTANT]
> **`proposal` 产出状态标记**：plan 设计了一个 `status.json` 文件来标记 proposal 的审核状态（`pending_review` → `approved` → `applied`）。`apply` 命令会检查此状态。是否需要更复杂的状态管理？

> [!IMPORTANT]
> **`doit` 命令保留行为**：当前设计保留 `doit` 作为"全自动模式"（自动跑完 proposal + apply，不停下来等人工审核）。这与你的预期一致吗？还是希望 `doit` 改为先 `proposal` 再等审核？

> [!IMPORTANT]
> **文件迁移路径确认**：将三个文件从 `docs/` 迁移到 `.claude/`，新路径为：
> - `.claude/ARCHITECTURE.md`
> - `.claude/CODING_GUIDELINES.md`
> - `.claude/SECURITY.md`
>
> `docs/` 目录将只保留 `iterations/`、`PROJECT_BASELINE.md`、`EXISTING_STRUCTURE.md`、`TEST_BASELINE.md`。

---

## Proposed Changes

### 1. 命令分工重新设计

当前命令：`init` / `doit` / `mini`

改为五入口：

| 命令 | 说明 | 对应步骤 |
|------|------|----------|
| `init` | 初始化或接入项目 | ⓪ |
| `proposal` | 需求拆解（到 Gate 1 通过为止）→ 等待人工审核 | ①②③④⑤ |
| `apply` | 人工审核通过后执行开发到 PR | ⑥⑦⑧⑨⑩⑪ |
| `doit` | 全自动模式（proposal + apply 不停顿） | ①-⑪ |
| `mini` | 小任务轻量流程 | 不变 |

#### `proposal` 流程

```
⓪ 初始化检查（若未初始化则先 init）
① requirements-ingestion → requirements.md
② requirements-clarifier → 标注版 requirements.md
③ design-generator → design.md
④ task-generator → tasks.md
⑤ design-reviewer (Gate 1)
⑤.1 增量文档同步（若 Gate 1 经修订）

写入 status.json { "phase": "pending_review", ... }
通知 TG: 📋 需求拆解完成，等待人工审核
        → 附带 proposal 摘要（需求数 / 任务数 / 预估工时）
        → 附带迭代目录路径

⏸ 停止，等待人工审核
```

#### `apply` 流程

```
读取指定迭代目录的 status.json
IF status != "approved":
  提示: "该 proposal 尚未通过审核，请先审核"
  EXIT

⑥ Claude Code 开发
⑦ test-generator
⑧ code-reviewer (Gate 2)
⑨ test-pipeline
⑩ docs-updater
⑪ git-committer

更新 status.json { "phase": "applied", ... }
通知 TG: ✅ PR 已创建
```

#### `status.json` 设计

```json
{
  "phase": "pending_review | approved | rejected | applied",
  "proposal_at": "2026-04-13T14:00:00+08:00",
  "reviewed_at": null,
  "applied_at": null,
  "reviewer": null,
  "iter_dir": "docs/iterations/2026-04-13/001-user-login-feature/",
  "summary": {
    "requirement_count": 3,
    "task_count": 7,
    "estimated_hours": 18
  }
}
```

> 人工审核方式：用户审阅 `requirements.md` / `design.md` / `tasks.md` 后，修改 `status.json` 中 `phase` 为 `approved`，或通过 `/sdlc-workflow apply <iter_dir>` 时由命令自动确认。

---

### 2. 文档迁移：`docs/` → `.claude/`

| 原路径 | 新路径 |
|--------|--------|
| `docs/ARCHITECTURE.md` | `.claude/ARCHITECTURE.md` |
| `docs/CODING_GUIDELINES.md` | `.claude/CODING_GUIDELINES.md` |
| `docs/SECURITY.md` | `.claude/SECURITY.md` |

`docs/` 目录保留内容：
- `docs/iterations/` — 迭代产物
- `docs/PROJECT_BASELINE.md` — existing project baseline
- `docs/EXISTING_STRUCTURE.md` — existing project 结构
- `docs/TEST_BASELINE.md` — existing project 测试基线

---

## 详细文件变更

### Component 1: SKILL.md（主编排）

#### [MODIFY] [SKILL.md](file:///Volumes/HS-SSD-1TB/works/work-piple-1/sdlc-workflow/SKILL.md)

1. **命令分工章节**（L35-53）：新增 `proposal` 和 `apply` 入口说明
2. **argument-hint**（L10）：更新为 `"init | proposal <需求> | apply <迭代目录> | doit <需求> | mini <小任务>"`
3. **项目初始化章节**（L62）：`docs/ARCHITECTURE.md` → `.claude/ARCHITECTURE.md`
4. **Pipeline 编排章节**（L125-355）：
   - 在步骤概览表中标注 `proposal` 和 `apply` 的分界点
   - 在 ⑤ 之后新增 `proposal` 暂停逻辑 + `status.json` 写入
   - 新增 `apply` 入口逻辑（读取 status.json → 验证 → 从⑥继续）
5. **所有 `docs/ARCHITECTURE.md` 引用**：改为 `.claude/ARCHITECTURE.md`
6. **所有 `docs/SECURITY.md` 引用**：改为 `.claude/SECURITY.md`
7. **所有 `docs/CODING_GUIDELINES.md` 引用**：改为 `.claude/CODING_GUIDELINES.md`
8. **TG 通知列表**：新增 proposal 完成通知 + apply 启动通知

---

### Component 2: 初始化脚本 + 模板

#### [MODIFY] [init-project.sh](file:///Volumes/HS-SSD-1TB/works/work-piple-1/sdlc-workflow/scripts/init-project.sh)

1. L8：初始化检查条件从 `docs/ARCHITECTURE.md` 改为 `.claude/ARCHITECTURE.md`
2. L33：`ARCHITECTURE.md.tpl` 复制目标从 `docs/ARCHITECTURE.md` 改为 `.claude/ARCHITECTURE.md`
3. L34：`SECURITY.md.tpl` 复制目标从 `docs/SECURITY.md` 改为 `.claude/SECURITY.md`
4. L35：`CODING_GUIDELINES.md.tpl` 复制目标从 `docs/CODING_GUIDELINES.md` 改为 `.claude/CODING_GUIDELINES.md`
5. 删除 `mkdir -p "$PROJECT_ROOT/docs/iterations"` 中的多余 docs 子目录（iterations 保留）

#### [MODIFY] [CLAUDE.md.tpl](file:///Volumes/HS-SSD-1TB/works/work-piple-1/sdlc-workflow/templates/CLAUDE.md.tpl)

1. L13-15：引用路径从 `docs/ARCHITECTURE.md` 等改为 `.claude/ARCHITECTURE.md` 等
2. L46-49：更新命令示例，新增 `proposal` / `apply`

#### [MODIFY] [workflow-rules.md.tpl](file:///Volumes/HS-SSD-1TB/works/work-piple-1/sdlc-workflow/templates/workflow-rules.md.tpl)

1. 所有 `docs/ARCHITECTURE.md` → `.claude/ARCHITECTURE.md`
2. 所有 `docs/SECURITY.md` → `.claude/SECURITY.md`
3. 所有 `docs/CODING_GUIDELINES.md` → `.claude/CODING_GUIDELINES.md`
4. 新增 proposal/apply 相关规则

---

### Component 3: Reference 文档

#### [MODIFY] [pipeline-overview.md](file:///Volumes/HS-SSD-1TB/works/work-piple-1/sdlc-workflow/references/pipeline-overview.md)

1. 流程图：在 Gate 1 之后新增 `proposal 暂停点` / `apply 入口`
2. 步骤详解表：反映 proposal/apply 分界
3. 两层架构图（L115-164）：`.claude/` 目录内容更新
4. 所有 `docs/ARCHITECTURE.md` 等引用改为 `.claude/`

#### [MODIFY] [design-generator.md](file:///Volumes/HS-SSD-1TB/works/work-piple-1/sdlc-workflow/references/design-generator.md)

1. 输入列表（L6-8）：`docs/ARCHITECTURE.md` → `.claude/ARCHITECTURE.md`，`docs/SECURITY.md` → `.claude/SECURITY.md`
2. 命令模板（L223-224）：同上

#### [MODIFY] [design-reviewer.md](file:///Volumes/HS-SSD-1TB/works/work-piple-1/sdlc-workflow/references/design-reviewer.md)

1. 输入列表（L7-8）：路径更新
2. Codex 审查 prompt（L39-43）：路径更新
3. 命令模板（L138-139）：路径更新
4. Gate 1 后同步范围表（L245-248）：路径更新

#### [MODIFY] [code-reviewer.md](file:///Volumes/HS-SSD-1TB/works/work-piple-1/sdlc-workflow/references/code-reviewer.md)

1. 输入中的 `CODING_GUIDELINES.md` 和 `SECURITY.md` 路径更新

#### [MODIFY] [docs-updater.md](file:///Volumes/HS-SSD-1TB/works/work-piple-1/sdlc-workflow/references/docs-updater.md)

1. 更新目标文件路径：`.claude/ARCHITECTURE.md` 等

#### [NEW] [proposal.md](file:///Volumes/HS-SSD-1TB/works/work-piple-1/sdlc-workflow/references/proposal.md)

新建 reference，描述 `proposal` 命令的详细行为：
- 触发条件与入口
- 执行步骤 ①-⑤ 的编排
- `status.json` 写入规范
- TG 通知文案
- 错误处理

#### [NEW] [apply.md](file:///Volumes/HS-SSD-1TB/works/work-piple-1/sdlc-workflow/references/apply.md)

新建 reference，描述 `apply` 命令的详细行为：
- 入口参数（迭代目录路径）
- `status.json` 读取与校验
- 执行步骤 ⑥-⑪ 的编排
- 状态更新
- TG 通知文案
- 错误处理

---

### Component 4: README

#### [MODIFY] [README.md](file:///Volumes/HS-SSD-1TB/works/work-piple-1/sdlc-workflow/README.md)

1. 命令入口：新增 `proposal` 和 `apply`
2. 快速开始示例：新增 proposal → 审核 → apply 的使用流程
3. 项目结构图：新增 `proposal.md` 和 `apply.md`
4. Pipeline 流程图：反映 proposal/apply 分界
5. 文件路径从 `docs/` 更新为 `.claude/`

---

## 新增文件总览

| 文件 | 说明 |
|------|------|
| `references/proposal.md` | proposal 命令详细规范 |
| `references/apply.md` | apply 命令详细规范 |

## 修改文件总览

| 文件 | 改动摘要 |
|------|----------|
| `SKILL.md` | 新增命令入口 + 路径迁移 + proposal/apply 编排 |
| `scripts/init-project.sh` | 文件复制目标路径迁移 |
| `templates/CLAUDE.md.tpl` | 引用路径 + 命令示例 |
| `templates/workflow-rules.md.tpl` | 引用路径 + proposal/apply 规则 |
| `references/pipeline-overview.md` | 流程图 + 目录结构 + 路径 |
| `references/design-generator.md` | 输入路径 |
| `references/design-reviewer.md` | 输入路径 + 同步范围 |
| `references/code-reviewer.md` | 输入路径 |
| `references/docs-updater.md` | 目标文件路径 |
| `README.md` | 命令说明 + 示例 + 结构图 + 路径 |

---

## Open Questions

> [!IMPORTANT]
> **人工审核的触发方式**：当前设计中，用户需要手动编辑 `status.json` 的 `phase` 字段为 `approved`，或者直接运行 `/sdlc-workflow apply <dir>` 时通过交互确认。是否需要更便捷的审批方式（如 TG 回复 `approve`）？

> [!WARNING]
> **`doit` 与 `proposal` + `apply` 的关系**：如果保留 `doit` 为全自动模式，那么实际上有两条路径可以完成同一个需求。这是刻意的设计（给用户选择权）还是你希望统一为只走 `proposal` → `apply`？

---

## Verification Plan

### Automated Tests

```bash
# 1. 验证 init-project.sh 生成的文件路径正确
bash scripts/init-project.sh /tmp/test-project
ls /tmp/test-project/.claude/ARCHITECTURE.md
ls /tmp/test-project/.claude/CODING_GUIDELINES.md
ls /tmp/test-project/.claude/SECURITY.md

# 2. 验证不再生成 docs/ 下的旧路径文件
test ! -f /tmp/test-project/docs/ARCHITECTURE.md
test ! -f /tmp/test-project/docs/SECURITY.md
test ! -f /tmp/test-project/docs/CODING_GUIDELINES.md

# 3. grep 检查：确认所有文件中不再有 docs/ARCHITECTURE.md 等旧路径引用
grep -r "docs/ARCHITECTURE.md" . --include="*.md" --include="*.sh" --include="*.tpl"
grep -r "docs/SECURITY.md" . --include="*.md" --include="*.sh" --include="*.tpl"
grep -r "docs/CODING_GUIDELINES.md" . --include="*.md" --include="*.sh" --include="*.tpl"
# 以上应无输出
```

### Manual Verification

1. 通读修改后的 `SKILL.md`，确认 proposal → apply 流程连贯
2. 确认 `references/proposal.md` 和 `references/apply.md` 的步骤与 SKILL.md 一致
3. 确认所有 reference 文件中的文件路径引用已统一更新
