# 步骤 ③: Design Generator — 技术设计文档生成

## 输入

1. `docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/requirements.md`
2. `.claude/ARCHITECTURE.md`
3. `.claude/SECURITY.md`
4. `docs/iterations/`（历史迭代，用于上下文）

## 输出

`docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/design.md`

## 详细行为

### 0. 前置门禁：澄清状态复核（置信度感知，必须最先执行）

design-generator 不得在"低置信度项尚未澄清"的前提下凭假设直接做设计决策。进入设计前，先复核
requirements.md 的"假设记录"，复核 02-requirements-clarifier.md §4.7 的澄清 Gate：

```
INTERACTIVE = (mode in ["proposal", "mini"])

# 1) 读取假设记录，找出"必须问过"的项
MUST_ASK = 低置信度项 ∪ designImpact=true 的中置信度项

IF INTERACTIVE AND any(x.provenance == "never-asked" for x in MUST_ASK):
  → ⛔ 停止生成设计：存在从未澄清、却会影响设计决策的需求项
  → 回到 02 §4.2，对这些项发起 AskUserQuestion 澄清后再继续
  → 严禁"先把设计决策做了，再事后补假设"
```

> 这是 02 §4.7 的下游双保险：即使澄清步骤被跳过或假设记录不完整，设计期仍会在此拦截。
> doit 无人值守模式（never-asked 合法）下此门禁直接放行，但仍须执行下面的"设计假设显式化"。

**设计假设显式化（所有模式都要做）**：凡 design.md 中**解决了某个 [❓待确认] / [⚠️ 假设] 项**的
技术决策，都必须：

1. 在 design.md 新增 **「## 设计假设」** 小节集中登记：`决策点 / 关联需求或 ASM-ID / 所做假设 / 理由 / 若假设错误的影响`
2. 不得把假设当成既定事实静默写进正文——任何被假设驱动的选型都要可追溯到假设记录
3. 交互模式下若该假设有设计影响且 provenance=never-asked，按上面的门禁先澄清，不在此处静默决定

### 1. 读取历史上下文

在生成新设计前，读取最近 N 个迭代的 design.md，了解已有设计：

```bash
# 读取最近 3 个迭代的设计文档
HISTORY_DIR="docs/iterations/"
LATEST_DESIGNS=$(find "$HISTORY_DIR" -name "design.md" -type f \
  | sort -r | head -3 | xargs -I{} cat {})

# 分析历史设计要点
# - 已有模块和组件
# - 设计模式和约定
# - 已有的技术决策
```

### 2. 设计文档结构

生成的 design.md 包含以下章节：

```markdown
# 技术设计文档

## 基本信息

- **迭代目录**: docs/iterations/<date>/<seq>-<slug>-<type>/
- **生成时间**: YYYY-MM-DD HH:mm:ss
- **基于需求**: requirements.md

## 0. 目录影响声明

### 0.1 目标目录
- `apps/web/src`: <是否修改 / 新增内容>
- `apps/server/src`: <是否修改 / 新增内容>
- `packages/<name>`: <是否新增共享模块>

### 0.2 新增目录
- <目录路径> - <新增原因>

### 0.3 偏离说明
- 若未采用 Better-T-Stack 默认结构，说明为什么不能复用 `apps/web` / `apps/server` / `packages/*`
- 若需要新增根目录级 workspace，说明必要性、影响范围、后续治理计划

## 1. 技术方案概要

### 1.1 概述
<技术方案的简要描述，2-3 句话>

### 1.2 目标
- <目标 1>
- <目标 2>

### 1.3 非目标（Scope 外）
- <不包含的目标 1>
- <不包含的目标 2>

## 2. 数据模型设计

### 2.1 实体关系图
```
<Entity Relationship Diagram>
```

### 2.2 主要数据模型

#### User（用户）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| username | VARCHAR(50) | 用户名 |
| email | VARCHAR(255) | 邮箱 |
| created_at | TIMESTAMP | 创建时间 |

#### Session（会话）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| user_id | UUID | 外键 |
| token | VARCHAR(255) | 会话 token |
| expires_at | TIMESTAMP | 过期时间 |

## 3. API 接口设计

### 3.1 接口列表

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| POST | /api/auth/login | 用户登录 | 否 |
| POST | /api/auth/logout | 用户登出 | 是 |
| GET | /api/user/profile | 获取用户信息 | 是 |

### 3.2 详细接口规范

#### POST /api/auth/login

**请求**:
```json
{
  "username": "string",
  "password": "string"
}
```

**响应 (200)**:
```json
{
  "token": "string",
  "expires_at": "ISO8601"
}
```

**错误响应**:
```json
{
  "error": "INVALID_CREDENTIALS",
  "message": "用户名或密码错误"
}
```

## 4. 安全考量

### 4.1 认证
- Token 认证，JWT RS256 签名
- Token 有效期: 24 小时
- Refresh Token: 7 天

### 4.2 授权
- RBAC 角色模型
- 权限检查中间件

### 4.3 数据保护
- 敏感字段加密存储
- HTTPS 强制
- 输入验证和清洗

## 5. 依赖关系

### 5.1 内部依赖
- auth module → user module
- session module → auth module

### 5.2 外部依赖
- PostgreSQL 14+
- Redis 6+
- External SMS Gateway

### 5.3 依赖管理
```bash
# 所需 npm 包
npm install bcryptjs jsonwebtoken pg redis
npm install -D @types/bcryptjs @types/jsonwebtoken
```

## 6. 风险评估

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| 并发登录处理 | 中 | 中 | Redis Session 统一管理 |
| Token 泄露 | 低 | 高 | HTTPS + 安全存储 |
| SQL 注入 | 低 | 高 | 参数化查询 + ORM |

## 7. 实施计划

### Phase 1: 基础设施
- [ ] 数据库迁移脚本
- [ ] Redis 连接配置
- [ ] 基础认证中间件

### Phase 2: 核心功能
- [ ] 用户注册/登录 API
- [ ] Session 管理
- [ ] 权限控制

### Phase 3: 完善
- [ ] 错误处理
- [ ] 日志记录
- [ ] 测试

## 8. 设计决策记录

| 日期 | 决策 | 理由 |
|------|------|------|
| YYYY-MM-DD | 选择 JWT 而非 Session | 无状态，易于水平扩展 |
```

## 3. 设计生成提示

Claude Code 在生成设计时应参考：

```
在生成设计时，请考虑：
1. 与现有架构的一致性
2. 安全性优先
3. 可扩展性
4. 简单性（避免过度设计）
5. 已有历史迭代中的设计模式
6. 默认遵循 Better-T-Stack 风格目录：`apps/web`、`apps/server`、`packages/*`
7. `packages/config` 为基础包；`packages/env`、`packages/api`、`packages/auth`、`packages/db`、`packages/infra`、`packages/ui` 按所选能力启用
8. 共享逻辑优先下沉到 `packages/*`，不要在前后端复制
9. 不要无理由新增根目录级 `web/`、`server/`、`api/`
```

## 命令模板

```bash
# 1. 读取输入
REQ_FILE="docs/iterations/$DATE/$SEQ-$SLUG-$TYPE/requirements.md"
ARCH_FILE=".claude/ARCHITECTURE.md"
SEC_FILE=".claude/SECURITY.md"

# 2. 读取历史上下文（最近 3 个迭代）
HISTORY=$(find docs/iterations/ -name "design.md" -type f \
  | sort -r | head -3 | xargs -I{} cat {})

# 3. 生成设计文档
cat > "docs/iterations/$DATE/$SEQ-$SLUG-$TYPE/design.md" << 'TEMPLATE'
# 技术设计文档
...
TEMPLATE

# 4. 验证设计文档完整性
if ! grep -q "## 0. 目录影响声明" "$DESIGN_FILE"; then
  echo "ERROR: design.md 缺少目录影响声明"
  exit 1
fi

if ! grep -q "## 1. 技术方案概要" "$DESIGN_FILE"; then
  echo "ERROR: design.md 缺少必需章节"
  exit 1
fi

echo "✅ 设计文档已生成: docs/iterations/$DATE/$SEQ-$SLUG-$TYPE/design.md"
```

## 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| requirements.md 不存在 | 回退到步骤① |
| ARCHITECTURE.md 不存在 | 跳过，生成简化版设计 |
| 历史迭代读取失败 | 记录日志，使用空上下文继续 |
| 设计文档生成失败 | 保留部分内容，提示用户补充 |

## 相关文件

- 输入：
  - requirements.md
  - .claude/ARCHITECTURE.md
  - .claude/SECURITY.md
  - docs/iterations/*/design.md（历史）
- 输出：docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/design.md
- 参考：
  - references/04-task-generator.md（下一步）
  - references/05-design-reviewer.md（Gate 1）
