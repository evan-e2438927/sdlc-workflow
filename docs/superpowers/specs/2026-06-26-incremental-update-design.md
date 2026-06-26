# 设计：让 `/update` 变成"增量 init"

日期：2026-06-26
状态：待评审

## 背景与问题

现状 `/sdlc-workflow:update`（`commands/update.md` → `scripts/update-project.sh`）是**纯机械同步**：

- 补齐缺失目录（`.claude/rules`、`docs/iterations`、`tests/**`）
- 迁移 `.claude/.sdlc-config`（保留用户值、补新键、删废弃键）
- 刷新插件托管的 `workflow-rules.md`
- 仅在**缺失时**补齐用户文档，已存在绝不覆盖
- `.gitignore` 兜底

它**从不读取项目真实代码**，因此无法发现"文档/配置已与代码脱节"这类漂移：

- `ARCHITECTURE.md` / `SECURITY.md` 仍停留在模板占位 `<!-- 请描述 -->`，或描述了项目早已演进掉的结构
- `PROJECT_BASELINE.md` / `EXISTING_STRUCTURE.md` / `TEST_BASELINE.md` 过时（新增了 workspace / 依赖 / 测试套件）
- `.sdlc-config` 的 `TEST_FRAMEWORK` / `LINT_TOOL` 与真实仓库不一致（如配置写 jest、实际用 vitest）

而 `init` 的 `references/00-existing-project-intake.md`（intake）**会**读真实代码填实这些文档——但 `update` 完全跳过了这套智能。

## 目标

给 `update` 增加一个**漂移感知的增量智能阶段**，把 intake"读代码 → 填文档"的能力以**安全、可确认**的方式带到升级流程里。

非目标：

- 不迁移历史 `docs/iterations` 产物 / 旧命令格式（本次不做）
- 不触发任何业务开发流程（proposal/apply 等）
- 不改动业务代码

## 方案（Approach A：两阶段 update，复用 intake 文档）

选定 A，理由：文档生成规则只保留**一处**（intake 文档），intake 与 update 不会各自漂移。
被否方案：B 新建独立 `12-incremental-update.md`（会复制 intake 的文档生成要求 → 双源漂移）；
C 把漂移检测塞进 bash 脚本（判断文档是否匹配真实代码是推理工作，非 `grep` 能做）。

### `commands/update.md` 改为两阶段编排器

#### 阶段一 —— 机械同步（保持不变）

照旧运行 `scripts/update-project.sh`，行为与今天完全一致（目录 / 配置键 / workflow-rules / 缺失文档 / .gitignore），非交互、安全幂等。汇报脚本输出的变更摘要。

#### 阶段二 —— 增量 intake（新增，LLM 驱动）

仅在阶段一之后执行，按下列顺序：

1. **漂移扫描** —— 读取真实文件树 + 根级配置（`package.json`、`pnpm-workspace.yaml`、`turbo.json`、`docker-compose.yml` 等），与已记录状态比对，产出一份**漂移报告**，至少覆盖：
   - **配置漂移**：`.sdlc-config` 的 `TEST_FRAMEWORK` / `LINT_TOOL` / 结构假设 vs 真实仓库
   - **基线过时**：三份 baseline 缺失，或与当前 workspace / 依赖 / 脚本不符
   - **文档过时**：`ARCHITECTURE.md` / `SECURITY.md` 仍含 `<!-- 请描述 -->` 占位，或描述的结构与真实代码不符

2. **基线文档 —— 自动刷新**（`PROJECT_BASELINE.md` / `EXISTING_STRUCTURE.md` / `TEST_BASELINE.md`）：
   这三份是从代码派生的**事实**，直接按真实代码重生成，旧版备份为 `.bak`。仅汇报，不逐项 gate。

3. **用户文档 —— 报告 + 逐项确认**（`ARCHITECTURE.md` / `SECURITY.md` / `CLAUDE.md` / `CODING_GUIDELINES.md`）：
   对每个存在漂移的文档，展示**哪里过时**及拟刷新的内容，**仅在用户确认后**才重写，旧版备份为 `.bak`。
   未确认的文档保持原样。这是 update"绝不盲目覆盖用户内容"原则的延续。

4. **配置漂移 —— 提议 + 确认**：例如"仓库用 vitest，但 `.sdlc-config` 写 jest——是否修正？"，确认后才改。

### `references/00-existing-project-intake.md` 增加"增量 update 模式"小节

复用同一套文档生成要求（输出文档清单、填实标准、结构保护规则），但说明在增量模式下：

- 以 **diff / 刷新**方式作用于已存在文件，而非首次从零生成
- 基线可直接重生成；用户文档需经 update 的逐项确认 gate
- 复用 intake 既有的"完成条件"作为刷新后的校验标准

## 安全与边界

- 阶段一与今天等价，零行为变化
- 阶段二对**基线**自动刷新（事实，低风险，带 `.bak`）
- 阶段二对**用户手改文档**一律报告 + 逐项确认后才动，带 `.bak`
- 全程不碰业务代码、不触发开发流程

## 受影响文件

- `commands/update.md` —— 重写为两阶段编排（保留阶段一描述，新增阶段二）
- `sdlc-workflow/references/00-existing-project-intake.md` —— 追加"增量 update 模式"小节
- `sdlc-workflow/scripts/update-project.sh` —— **不改**（继续作为阶段一）
- 可能：`sdlc-workflow/SKILL.md` / `README.md` 中 update 的描述同步更新

## 验收

- 在一个已 init、但代码已演进的项目上跑 `/update`：
  - 阶段一仍正常补结构 / 迁配置
  - 阶段二产出漂移报告，正确识别过时基线、占位文档、配置不符
  - 基线被自动刷新并留 `.bak`
  - 用户文档逐项征求确认，拒绝则不变、同意则刷新并留 `.bak`
- 在一个文档与代码完全一致的项目上跑 `/update`：阶段二报告"无漂移"，不产生多余 `.bak`
