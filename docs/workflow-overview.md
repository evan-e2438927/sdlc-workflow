# SDLC Workflow 全景：2 模型 · 4 阶段 · 5 命令主线

> 一句话：Claude Code 生成，Codex CLI 审查，四阶段流水线驱动需求→设计→开发→交付；主线 5 命令 **proposal → apply → qa → accept → pr**，外加 init / doit / mini / review / update / worktree 覆盖从初始化到并行开发的全场景。

---

## 一、2 模型 — 双模型对抗架构

整条流水线的核心设计原则是 **生成与审查分离**——同一个模型不同时扮演"写代码"和"审代码"两个角色。

| 角色 | 模型 | 职责 | 出现位置 |
|------|------|------|----------|
| **生成者** | Claude Code | 需求解析、设计文档、任务分解、代码实现、测试生成、浏览器验收、文档更新与提交 | 步骤 ①②③④⑥⑦ 及 qa / accept / pr |
| **审查者** | Codex CLI | 独立审查设计与代码，输出 PASS / FAIL + 问题列表 | Gate 1（步骤⑤）、Gate 2（步骤⑧） |

### 双 Gate 把关机制

```
Claude Code                              Codex CLI
━━━━━━━━━━                              ━━━━━━━━━

  design.md                       ┌──→  🔍 Gate 1: design-reviewer
  tasks.md    ────────────────────┤     (可行性 / 安全 / 架构 / AC 覆盖度)
                                  │        ├─ PASS → 继续
                                  │        └─ FAIL → Claude Code 修订 → 重审 (≤N轮)
                                  │
  git diff                        └──→  🔍 Gate 2: code-reviewer
  (代码变更)  ────────────────────┘     (质量 / OWASP Top 10 / 编码规范)
                                           ├─ PASS → 进入测试
                                           └─ FAIL → Claude Code 修复 → 重审 (≤N轮)
```

**为什么需要两个模型？**

- **消除自我验证盲区**：生成者对自身输出天然"过于自信"，独立审查者能发现生成者遗漏的安全漏洞、架构违规和逻辑缺陷。
- **审查维度固定化**：Codex CLI 的审查 prompt 固定嵌入 OWASP Top 10、CODING_GUIDELINES、SECURITY 等规范，不会因上下文膨胀而跳过检查项。
- **循环修订可控**：FAIL 后回退给 Claude Code 修订，再交 Codex CLI 重审，最多 N 轮（`REVIEW_MAX_ROUNDS`），超限自动上报人工。

---

## 二、4 阶段 — 流水线生命周期

完整 Pipeline 按职责划分为 4 个阶段：前三阶段是 proposal / apply 内部的 ⓪–⑧ 步骤，第四阶段是 qa / accept / pr 三条独立命令。

```mermaid
graph LR
    S1["🏗 阶段一<br/>初始化"] --> S2["📋 阶段二<br/>需求设计"] --> S3["⚙️ 阶段三<br/>开发审查"] --> S4["🚀 阶段四<br/>验收交付"]
```

### 阶段一：初始化（⓪）

> 一次性准备工作，确保项目具备 Pipeline 运行所需的基础设施。

| 动作 | 说明 |
|------|------|
| 项目模式检测 | 自动识别 `fresh project` 或 `existing project` |
| 脚手架生成 | 运行 `init-project.sh`，生成 `.claude/`、`docs/`、`tests/`、`.claude/.sdlc-config` 等基础结构 |
| 基线采集 | existing project 额外生成 `PROJECT_BASELINE.md`、`EXISTING_STRUCTURE.md`、`TEST_BASELINE.md` |

**产物**：`.claude/CLAUDE.md`、`.claude/ARCHITECTURE.md`、`.claude/SECURITY.md`、`.claude/CODING_GUIDELINES.md`、`.claude/.sdlc-config`

### 阶段二：需求设计（①②③④⑤）

> 从原始需求到可执行任务清单，经过 Gate 1 设计审查。

| 步骤 | 名称 | 执行者 | 产出 |
|------|------|--------|------|
| ① | requirements-ingestion | Claude Code | `requirements.md` — 支持文本 / file:// / URL 三种输入 |
| ② | requirements-clarifier | Claude Code | 标注版 `requirements.md`（置信度 + 假设 + 待澄清） |
| ③ | design-generator | Claude Code | `design.md` — 技术方案设计 |
| ④ | task-generator | Claude Code | `tasks.md` — 可执行任务分解（含 AC-ID 映射） |
| ⑤ | design-reviewer | **Codex CLI** | **Gate 1**: PASS / FAIL（可行性 / 安全 / 架构 / AC 覆盖度） |

**关键规则**：
- Gate 1 FAIL 时回退到步骤③重新生成设计，最多循环 N 轮
- `proposal` 命令在 Gate 1 通过后暂停，写入 `status.json (phase: pending_review)`，等待人工审核
- `doit` 命令在 Gate 1 通过后直接进入下一阶段

### 阶段三：开发审查（⑥⑦⑧）

> 按任务实现代码，生成测试，经过 Gate 2 代码审查。

| 步骤 | 名称 | 执行者 | 产出 |
|------|------|--------|------|
| ⑥ | Claude Code 开发 | Claude Code | 代码变更（支持 Agent Team 按拓扑层并行开发） |
| ⑦ | test-generator | Claude Code | `tests/unit/` + `tests/e2e/` 测试文件 |
| ⑧ | code-reviewer | **Codex CLI** | **Gate 2**: PASS / FAIL（质量 / OWASP / 规范 / 任务状态） |

**关键规则**：
- 步骤⑥ 先做依赖分析 + 拓扑分层，若并行层 > 1 且任务 ≥ 3，启用 Agent Team 并行开发
- Gate 2 审查维度：代码质量、安全漏洞（OWASP Top 10）、架构合规、编码规范、错误处理、目录结构、任务回写
- Gate 2 FAIL 时回退到步骤⑥修复，最多循环 N 轮

### 阶段四：验收交付（qa → accept → pr）

> 浏览器功能验收 → 文档更新 + 本地提交 → 推送建 PR。

| 命令 | 名称 | 执行者 | 产出 |
|------|------|--------|------|
| qa | 浏览器验收 | Claude Code | Playwright MCP 真实浏览器验收 + `tests/reports/<slug>-e2e-report.md` |
| accept | 文档更新 + 本地提交 | Claude Code | 更新项目文档 + CLAUDE.md iterations 引用 → 本地 commit |
| pr | 推送建 PR | Claude Code | push → `gh pr create` |

**测试分两处执行（无独立 CDP 阶段）**：

```
apply 内（test-pipeline，不含浏览器）：
  Stage 1: Lint    快速失败，代码静态检查
  Stage 2: Unit    单元测试 (jest/vitest/mocha)

qa 命令（真实浏览器验收）：
  Playwright 脚本预检（track: qa 脚本生成）
  Playwright MCP   页面 / 控制台 / 网络 + 交互验收 ← 唯一最终通过依据
```

> ⚠️ 最终通过必须有 Playwright MCP 的真实浏览器交互证据，而非模型自述。qa 通过截图存入迭代 `evidence/`，由 pr 嵌入 PR body。

---

## 三、命令 — 操作入口速查

### 总览

主线：**proposal → apply → qa → accept → pr**

```
sdlc-workflow
  ├── init           ← 初始化 / 接入项目
  ├── proposal       ← 需求拆解（到 Gate 1 后暂停）
  ├── apply          ← 人工审核后开发 + lint + unit
  ├── qa             ← 浏览器功能验收（Playwright MCP）
  ├── accept         ← 更新文档 + 本地提交
  ├── pr             ← 推送 + 建 PR（唯一远程动作）
  ├── doit           ← 全自动（proposal → pr 不停顿）
  ├── mini           ← 小任务轻量流程
  ├── review         ← 单独跑 Codex 审查（Gate 1 / Gate 2）
  ├── update         ← 已初始化项目的升级同步
  └── worktree       ← create / list / status / remove / gc
```

### ① `init` — 初始化项目

```bash
/sdlc-workflow init [review=1 branch=feat/ test-framework=vitest lint=eslint]
```

| 项 | 说明 |
|-----|------|
| **何时用** | 首次将项目接入 SDLC 工作流 |
| **做什么** | 检测项目类型 → 生成脚手架 → 采集基线 → 配置 `.claude/.sdlc-config` |
| **产物** | `.claude/` 目录、`docs/`、`tests/`、`.claude/.sdlc-config` |
| **阶段覆盖** | 阶段一 |

### ② `proposal` — 需求拆解

```bash
/sdlc-workflow proposal <需求文本 | file:///path | URL>
```

| 项 | 说明 |
|-----|------|
| **何时用** | 需要人工审核设计方案后再开发 |
| **做什么** | 需求解析 → 设计 → 任务分解 → Gate 1 审查 → 暂停 |
| **产物** | `docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/` 下的 requirements.md / design.md / tasks.md / status.json |
| **阶段覆盖** | 阶段一 + 阶段二 |
| **暂停点** | Gate 1 通过后写入 `status.json (phase: pending_review)`，等待人工审核 |

### ③ `apply` — 续跑开发（不含浏览器/提交）

```bash
/sdlc-workflow apply [迭代目录路径]
```

| 项 | 说明 |
|-----|------|
| **何时用** | `proposal` 产出审核通过后，实现代码 |
| **做什么** | 读取 status.json → 开发（frontend/backend/unit-test）→ 单元测试 → [Gate 2] → lint + unit |
| **产物** | 代码变更 + 单元测试（不提交、不 push） |
| **阶段覆盖** | 阶段三 |
| **前置条件** | status.json 中 `phase` 为 `pending_review` 或 `approved` |

### ④ `qa` — 浏览器功能验收

```bash
/sdlc-workflow qa [迭代目录路径]
```

| 项 | 说明 |
|-----|------|
| **何时用** | `apply` 完成后，做真实浏览器功能验收 |
| **做什么** | 生成 Playwright 脚本 → Playwright MCP 真实浏览器执行 → 通过态截图存入迭代 `evidence/` |
| **产物** | `tests/reports/<slug>-e2e-report.md` + 证据截图 |
| **前置条件** | `phase` 为 `applied` |

### ⑤ `accept` — 定稿本地提交

```bash
/sdlc-workflow accept [迭代目录路径]
```

| 项 | 说明 |
|-----|------|
| **何时用** | qa 通过（或跳过 qa）后定稿 |
| **做什么** | 总结变更 → 更新项目文档 + CLAUDE.md iterations 引用 → **本地 commit（不 push）** |
| **产物** | 本地 commit |
| **前置条件** | `phase` 为 `qa_passed` 或 `applied` |

### ⑥ `pr` — 推送建 PR

```bash
/sdlc-workflow pr [迭代目录路径]
```

| 项 | 说明 |
|-----|------|
| **何时用** | `accept` 完成本地提交后发布 |
| **做什么** | `git push` → `gh pr create`（唯一与远程交互；证据截图随迭代 `evidence/` 嵌入 PR 正文） |
| **产物** | 远程分支 + PR URL |
| **前置条件** | `phase` 为 `accepted` |

### ⑦ `doit` — 全自动模式

```bash
/sdlc-workflow doit <需求文本 | file:///path | URL>
```

| 项 | 说明 |
|-----|------|
| **何时用** | 完全信任 AI 处理，从需求直达 PR |
| **做什么** | 等价于 `proposal → apply → qa → accept → pr` 不停顿（`--qa` 含浏览器验收） |
| **产物** | 需求文档 + 设计文档 + 代码 + 测试 + PR |
| **阶段覆盖** | 阶段一 ~ 阶段四（全跑） |

### ⑧ `mini` — 小任务轻量流程

```bash
/sdlc-workflow mini <小任务描述>
```

| 项 | 说明 |
|-----|------|
| **何时用** | 样式微调、文案修改、小型 UI 修复等微变更 |
| **做什么** | 简化版 Pipeline，但仍保留 iteration 产物 + Gate 1 + Gate 2 + 浏览器验收 |
| **自动升级** | 若影响文件 > 3 个或涉及 API/数据模型/目录结构变更，自动升级到 `doit` |
| **阶段覆盖** | 精简版阶段二 ~ 阶段四 |

### ⑨ `worktree create` — 创建并行工作区

```bash
/sdlc-workflow worktree create <slug> <type>
# 示例
/sdlc-workflow worktree create user-login feature
```

| 项 | 说明 |
|-----|------|
| **何时用** | 需要同时开发多个需求，互相隔离 |
| **做什么** | 从 `main` 分支创建 Git Worktree → 初始化迭代目录 → 分配端口 → 注册到 registry |
| **产物** | `../wt-<seq>-<slug>-<type>/` 独立工作目录 |

### ⑩ `worktree manage` — 并行工作区管理

```bash
/sdlc-workflow worktree list          # 列出所有并行工作区
/sdlc-workflow worktree status        # 全局状态总览（聚合各 worktree 的 status.json）
/sdlc-workflow worktree remove <seq>  # 移除已完成的工作区
/sdlc-workflow worktree gc            # 清理已合并的工作区
```

| 项 | 说明 |
|-----|------|
| **何时用** | 查看并行任务进度 / 完成后清理资源 |
| **做什么** | 查询、清理 Git Worktree 及关联的分支和注册信息 |

---

## 四、命令 × 阶段 × 模型 — 全景矩阵

| 命令 | 阶段一<br/>初始化 | 阶段二<br/>需求设计 | 阶段三<br/>开发审查 | 阶段四<br/>验收交付 | 暂停点 |
|------|:---:|:---:|:---:|:---:|------|
| `init` | ✅ | — | — | — | — |
| `proposal` | ✅* | ✅ | — | — | Gate 1 后 |
| `apply` | — | — | ✅ | ✅ | — |
| `doit` | ✅* | ✅ | ✅ | ✅ | 无 |
| `mini` | — | ✅(精简) | ✅(精简) | ✅(精简) | — |
| `worktree create` | ✅ | — | — | — | — |
| `worktree manage` | — | — | — | — | — |

> *表示按需执行（项目未初始化时自动触发）

### 模型参与映射

```
阶段一 (初始化)     → Claude Code (脚手架生成 + 基线采集)
阶段二 (需求设计)    → Claude Code (生成) + Codex CLI (Gate 1 审查)
阶段三 (开发审查)    → Claude Code (编码 + 测试生成) + Codex CLI (Gate 2 审查)
阶段四 (验收交付)    → Claude Code (测试执行 + 文档 + Git)
```

---

## 五、典型工作流示例

### 场景 A：标准人工审核流程（proposal → apply）

```bash
# 1. 初始化项目
/sdlc-workflow init tg=123456789

# 2. 提交需求，AI 拆解设计后暂停等待审核
/sdlc-workflow proposal "实现用户登录功能，支持邮箱和手机号"

# 3. 审阅 iteration 目录中的 design.md / tasks.md
#    确认后继续执行
/sdlc-workflow apply docs/iterations/2026-04-16/001-user-login-feature/
```

### 场景 B：全自动模式（doit）

```bash
/sdlc-workflow doit "修复支付超时后重复扣款的 bug"
# → 从需求到 PR 一步到位
```

### 场景 C：小任务快速修复（mini）

```bash
/sdlc-workflow mini "将登录按钮颜色从蓝色改为绿色"
# → 轻量流程，仍有 Gate + 浏览器验收
```

### 场景 D：并行开发多需求（worktree）

```bash
# 创建两个独立工作区，互不干扰
/sdlc-workflow worktree create user-login feature
/sdlc-workflow worktree create payment-fix fix

# 各自独立跑 pipeline
cd ../wt-001-user-login-feature && /sdlc-workflow doit "用户登录"
cd ../wt-002-payment-fix-fix   && /sdlc-workflow doit "支付修复"

# 完成后清理
/sdlc-workflow worktree gc
```