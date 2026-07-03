# 步骤 ⓪B: Existing Project Intake — 旧项目基线接入

## 目的

当项目已经存在业务代码和技术架构，但尚未接入 SDLC Workflow 时，必须先执行 intake，而不是把旧项目当 fresh project 重新初始化。

intake 的目标不是生成新架构，而是确认：

1. 现有技术栈和工作区边界是什么
2. 现有脚本、测试、环境依赖是否可用
3. 哪些目录和约束属于既有事实，不得被模型自由改写
4. 后续 `requirements.md` / `design.md` / `tasks.md` 应基于哪些真相源

## 输入

1. 项目根目录现有文件树
2. 根级配置文件（如 `package.json`、`pnpm-workspace.yaml`、`turbo.json`、`docker-compose.yml` 等）
3. 现有文档（如 `README.md`、架构文档、部署文档）
4. 现有测试与脚本入口

## 输出

必须先生成 / 填实以下文档，再进入步骤①：

1. `.claude/PROJECT_BASELINE.md`
2. `.claude/EXISTING_STRUCTURE.md`
3. `.claude/TEST_BASELINE.md`
4. `.claude/ARCHITECTURE.md` — **必须基于真实代码填实，覆盖 init 拷贝的模板占位**
5. `.claude/SECURITY.md` — **必须基于真实代码填实，覆盖模板占位**
6. `.claude/CODING_GUIDELINES.md` / `.claude/CLAUDE.md` — **必须与真实结构对齐**

> ⚠️ init-project.sh 只会把模板原样拷过去（含 `<!-- 请描述 -->` 占位与默认的
> Better-T-Stack monorepo 假设）。intake 的职责之一就是把这些**模板内容替换为项目实际情况**——
> 否则 ARCHITECTURE.md / SECURITY.md 会停留在模板态，且对非 monorepo 项目给出错误的目录约定。

## 详细行为

### 1. 模式识别

满足以下任一条件时，视为 existing project mode：

1. 项目根目录已存在业务代码目录，如 `apps/`、`packages/`、`src/`
2. 项目根目录已存在构建或包管理配置，如 `package.json`、`pnpm-workspace.yaml`、`turbo.json`
3. 项目根目录已存在 `.git/` 且已有业务文件

若仅缺少 `.claude/` 或 `.claude/ARCHITECTURE.md`，但业务代码已经存在，也仍然属于 existing project mode。

### 2. 基线分析范围

intake 至少要分析以下 6 类内容：

1. **工作区结构**
2. **脚本入口**
3. **技术栈**
4. **环境依赖**
5. **测试基线**
6. **真相源**

### 3. 输出文档要求

#### 3.1 PROJECT_BASELINE.md

至少包含：

- 项目根路径
- 包管理器 / workspace / 构建系统
- 核心技术栈
- 当前可识别的运行脚本
- 外部依赖
- Verified Facts
- Claimed but Unverified

#### 3.2 EXISTING_STRUCTURE.md

至少包含：

- 目录树概览
- 每个 workspace 的职责
- 现有目录偏离 Better-T-Stack 默认约定的地方
- 哪些目录属于历史事实
- 哪些目录禁止本轮需求随意变更

#### 3.3 TEST_BASELINE.md

至少包含：

- 现有测试目录和测试工具
- 现有 lint / typecheck / unit / e2e / browser 验收入口
- 当前是否已经具备 Playwright MCP 最终交互验收能力
- 缺口列表

#### 3.4 ARCHITECTURE.md（填实，不留模板）

读取真实代码后**重写** `.claude/ARCHITECTURE.md`，删除所有 `<!-- 请描述 -->` 占位，至少包含：

- **系统概要**：项目类型与定位（如「单包 Next.js 15 App Router 应用」），不要套用 monorepo 模板
- **技术栈**：从 `package.json` / 配置文件读取的真实框架与版本
- **目录约定**：以实际结构为准（引用 EXISTING_STRUCTURE.md），**用真实落位规则替换模板里的
  `apps/web`、`apps/server`、`packages/*` 默认约定**——单包项目就写单包结构（如 `src/app`、`src/components`）
- **模块结构 / 数据流 / 外部依赖 / 部署架构**：基于实际代码归纳
- **目录偏离记录**：若不符合 Better-T-Stack，在此说明这是既有事实、本轮不重排

#### 3.5 SECURITY.md（填实，不留模板）

基于真实代码重写 `.claude/SECURITY.md`：认证/授权机制、敏感数据处理、密钥/Token 管理方式、
已知安全约束。无法确认的项标注为「待确认」，不要留空模板占位。

#### 3.6 CODING_GUIDELINES.md / CLAUDE.md 对齐

- `CODING_GUIDELINES.md`：把「Monorepo 落位规则」替换/补充为项目真实的落位约定
  （例如 Next.js 单包项目：页面进 `src/app/**`，组件进 `src/components/**`），不能保留与实际不符的 monorepo 规则
- `CLAUDE.md`：项目概述、技术栈、目录结构填实，并链接三份 baseline

### 4. 结构保护规则

进入 existing project mode 后，后续所有步骤都必须遵守：

1. 不得把旧项目当作 fresh project 重建目录
2. 不得为了“更像模板”而重排现有 workspace
3. 不得在没有 `design.md` 明确批准的前提下改动既有技术架构
4. `design.md` 必须引用 intake 结论，说明本次需求是“沿用现有结构”还是“批准的结构调整”
5. Gate 1 必须检查设计是否尊重 baseline
6. Gate 2 必须检查实现是否越过 baseline 边界

### 5. 完成条件

只有当以下条件全部满足时，才能进入步骤①：

1. `.claude/PROJECT_BASELINE.md` 存在
2. `.claude/EXISTING_STRUCTURE.md` 存在
3. `.claude/TEST_BASELINE.md` 存在
4. `.claude/ARCHITECTURE.md` 与 `.claude/SECURITY.md` **已填实**——不含 `<!-- 请描述 -->` 等模板占位，
   且 ARCHITECTURE.md 的目录约定与真实结构一致（非 monorepo 项目不得保留 monorepo 默认约定）
5. `.claude/CODING_GUIDELINES.md` 的落位规则与真实结构一致
6. 设计模型已明确现有结构的保护边界
7. 不存在“先写需求，后补基线”的倒序行为

### 6. 完成输出

```bash
echo "✅ 项目初始化完成（existing project）"
echo "   baseline: PROJECT_BASELINE / EXISTING_STRUCTURE / TEST_BASELINE 已生成"
echo "   context:  ARCHITECTURE / SECURITY / CODING_GUIDELINES / CLAUDE 已按真实代码填实"
```

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
