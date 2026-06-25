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

必须先生成以下基线文档，再进入步骤①：

1. `.claude/PROJECT_BASELINE.md`
2. `.claude/EXISTING_STRUCTURE.md`
3. `.claude/TEST_BASELINE.md`

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
- 当前是否已经具备 Playwright MCP / CDP（Chrome DevTools Protocol）最终交互验收能力
- 缺口列表

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
4. 设计模型已明确现有结构的保护边界
5. 不存在“先写需求，后补基线”的倒序行为

### 5. 完成输出

```bash
echo "✅ 项目初始化完成（existing project）"
echo "   PROJECT_BASELINE.md / EXISTING_STRUCTURE.md / TEST_BASELINE.md 已生成"
```
