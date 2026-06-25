# 步骤 ④: Task Generator — 任务分解

## 输入

`docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/design.md`

## 输出

`docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/tasks.md`

## 详细行为

### 1. 任务分解原则

将 design.md 中的设计方案拆解为可执行的任务：

```
分解原则：
1. 每个任务单一职责
2. 任务可独立测试
3. 任务有明确的验收标准，必须引用 requirements.md 的 AC-ID，保留 Given-When-Then 格式，覆盖 happy/error/boundary 维度
4. 任务有清晰的依赖关系
5. 复杂度评估准确
6. 任务必须明确落位到对应 workspace
7. 每个任务必须绑定 Requirement IDs，便于后续测试映射
8. 每个任务必须带显式完成状态，供执行阶段回写
9. 禁止验收标准退化为模糊 checkbox（如 "功能正常"、"数据正确"），必须含可验证的具体值或条件
10. 每个任务必须显式声明 Track（frontend / backend / shared / infra / test），且与目标文件路径自洽；跨端任务必须拆为多个任务，禁止一个任务跨 Track
11. test Track 仅出现在 Phase 3；Phase 1/2 的实现任务自带的单元测试不算 test Track
```

### 2. 任务结构

每个任务包含以下字段：

```markdown
### [ ] T-001: <任务名称>

**描述**: <详细的任务描述>

**目标文件**:
- apps/server/src/routes/auth/login.ts
- packages/auth/src/index.ts

**Track**: backend

**Requirement IDs**:
- R-001
- R-003

**验收标准**:

⚠️ 任务级验收标准**禁止退化**为模糊的 checkbox（如 "用户可以成功登录"）。
必须引用 requirements.md 中的 AC-ID，保留 Given-When-Then 格式和场景维度，并补充实现层面的具体判定条件。

- [ ] **AC-001** (happy-path): Given 用户提供有效凭据，When POST /api/auth/login，Then 返回 200 + JWT Token（exp ≤ 24h）
- [ ] **AC-002** (error): Given 密码错误，When POST /api/auth/login，Then 返回 401 + `{"error": "INVALID_CREDENTIALS"}`
- [ ] **AC-003** (error): Given 用户不存在，When POST /api/auth/login，Then 返回 401（同上错误码，不泄露用户是否存在）
- [ ] **AC-004** (boundary): Given 密码为空字符串，When POST /api/auth/login，Then 返回 400 + 参数校验错误
- [ ] **AC-005** (security): Given 恶意 SQL/XSS payload 作为 username，When POST /api/auth/login，Then 输入被清洗，返回 401，无注入执行

**依赖关系**:
- 前置任务: T-000（基础设施）

**复杂度**: M

**预估工时**: 2h
```

### 2.0 Track 取值与归属规则

| Track      | 含义                       | 典型目标文件路径                                                     |
|------------|----------------------------|----------------------------------------------------------------------|
| `frontend` | Web/Native 前端实现        | `apps/web/**`, `apps/native/**`, `packages/ui/**`                    |
| `backend`  | 后端 API / Worker / 数据层 | `apps/server/**`, `packages/api/**`, `packages/db/**`                |
| `shared`   | 跨端共享包                 | `packages/config/**`, `packages/env/**`, `packages/auth/**`          |
| `infra`    | 基础设施（迁移、配置、CI） | `db/migrations/**`, 根目录配置文件, `.github/workflows/**`           |
| `test`     | 独立测试任务（限 Phase 3） | `tests/unit/**`, `tests/e2e/**`                                      |

**Track 归属规则**：

1. 每个任务**只能**属于一个 Track；若需求横跨前后端，**必须在拆任务阶段**就拆为多个任务（如 T-003 后端登录 API + T-005 前端登录表单），不允许一个任务同时修改 `apps/web/*` 和 `apps/server/*`
2. Track 与 `目标文件` 路径必须自洽（Gate 1 校验）：所有 `目标文件` 必须落在对应 Track 的典型路径范围内
3. `test` Track 仅允许出现在 Phase 3；Phase 1/2 实现任务里随手写的单元测试**不计**为 test Track（仍计入该实现任务自身）
4. 如果某任务的目标文件确实跨多个候选 Track（罕见，如同时改 `packages/config` 和 `apps/server`），按"主要修改面"判定，并在任务描述里说明

### 2.1 验收标准编写规则

任务级 AC 与需求级 AC 的关系：

| 层级 | 来源 | 格式要求 | 作用 |
|------|------|----------|------|
| 需求级 AC | requirements.md | Given-When-Then + 场景维度 | 定义"做什么" |
| 任务级 AC | tasks.md | **引用需求级 AC-ID** + 补充实现细节 | 定义"怎么验证做对了" |

**规则**：
1. 每个任务的 AC **必须引用** requirements.md 中的 AC-ID（如 `AC-001`），不得凭空编写
2. 每个需求级 AC 必须在至少一个任务中被引用，不得遗漏
3. 任务级 AC 可以拆分一个需求级 AC 为多个子项（如 `AC-001a`, `AC-001b`），但不得合并丢失
4. 保留场景维度标注（happy-path / error / boundary / ui-state / security）
5. 补充实现层面的具体判定：HTTP 状态码、响应体结构、UI 元素选择器、错误文案、数值约束
6. 禁止模糊描述："正常工作"、"表现正确"、"数据正确"等不可验证的表述

### 2.1 执行状态回写规则

`tasks.md` 不只是任务输入，也是执行状态单据。开发阶段完成任务后必须同步回写：

```markdown
### [x] T-001: <任务名称>
```

并且对应任务下的验收标准必须按真实完成情况勾选。若代码已经实现，但 `tasks.md` 仍保持未完成状态，Gate 2 必须视为流程不完整。

### 3. 复杂度评估标准

| 复杂度 | 说明 | 编码行数参考 |
|--------|------|--------------|
| S | 简单，独立文件，无依赖 | < 50 行 |
| M | 中等，涉及少量文件 | 50-150 行 |
| L | 复杂，多文件，依赖较多 | 150-300 行 |
| XL | 非常复杂，系统级变更 | > 300 行 |

### 4. 任务分组

按实施阶段对任务分组：

```markdown
## 任务分组

### Phase 1: 基础设施
| 任务 ID | 名称 | 复杂度 | 预估工时 |
|---------|------|--------|----------|
| T-001 | 数据库迁移 | M | 2h |
| T-002 | Redis 配置 | S | 1h |

### Phase 2: 核心功能
| 任务 ID | 名称 | 复杂度 | 预估工时 |
|---------|------|--------|----------|
| T-003 | 用户登录 API | M | 3h |
| T-004 | Token 生成 | M | 2h |

### Phase 3: 完善
| 任务 ID | 名称 | 复杂度 | 预估工时 |
|---------|------|--------|----------|
| T-005 | 单元测试 | L | 4h |
| T-006 | E2E 测试 | L | 4h |
```

### 4.1 Track 汇总（按角色视图）

Phase 分组之外，`tasks.md` 必须再提供一个按 Track 聚合的视图，便于按角色阅读和分派：

```markdown
## 任务 Track 汇总（按角色视图）

| Track      | 任务数 | 总工时 | 任务 ID                          |
|------------|--------|--------|----------------------------------|
| frontend   | 2      | 5h     | T-007, T-008                     |
| backend    | 3      | 7h     | T-003, T-004, T-006              |
| shared     | 1      | 1h     | T-002                            |
| infra      | 1      | 2h     | T-001                            |
| test       | 2      | 8h     | T-009, T-010                     |
| **合计**   | **9**  | **23h**|                                  |
```

> 该表的"任务 ID"列必须覆盖 tasks.md 中所有任务 ID，且任务总数与 Phase 总览表一致——Gate 1 会交叉校验。

### 5. 依赖关系图

````markdown
## 依赖关系图

```
T-001 ──┬── T-003 ──┬── T-005
        │           │
T-002 ──┘           │
                    │
              T-004 ──┴── T-006
```
````

> **Agent Team 并行提示**：步骤⑥ 会根据依赖关系图构建拓扑分层，同层且目标文件无交集的任务将被分发给子 Agent 并行执行。因此，任务分解时应：
> - 在 **依赖关系** 字段中精确声明前置任务，避免遗漏隐式依赖
> - 在 **目标文件** 字段中完整列出该任务会修改的所有文件路径
> - 尽可能让同层任务的目标文件不重叠，以最大化并行度

### 6. 完整 tasks.md 模板

```markdown
# 任务分解文档

## 基本信息

- **迭代目录**: docs/iterations/<date>/<seq>-<slug>-<type>/
- **生成时间**: YYYY-MM-DD HH:mm:ss
- **基于设计**: design.md

## 任务总览

| Phase | 任务数 | 总工时 |
|-------|--------|--------|
| Phase 1: 基础设施 | 2 | 3h |
| Phase 2: 核心功能 | 3 | 7h |
| Phase 3: 完善 | 2 | 8h |
| **合计** | **7** | **18h** |

## 任务 Track 汇总（按角色视图）

| Track      | 任务数 | 总工时 | 任务 ID                          |
|------------|--------|--------|----------------------------------|
| frontend   | 0      | 0h     | —                                |
| backend    | 4      | 8h     | T-002, T-003, T-004, T-007       |
| shared     | 0      | 0h     | —                                |
| infra      | 1      | 2h     | T-001                            |
| test       | 2      | 8h     | T-005, T-006                     |
| **合计**   | **7**  | **18h**|                                  |

## Phase 1: 基础设施

### [ ] T-001: 数据库迁移

**描述**: 创建用户表和会话表，编写迁移脚本

**目标文件**:
- db/migrations/001_create_users.sql
- db/migrations/002_create_sessions.sql

**Track**: infra

**Requirement IDs**:
- R-001

**验收标准**:
- [ ] **AC-020** (happy-path): Given migration 脚本执行，When 检查数据库，Then users 表和 sessions 表存在且字段与 design.md 数据模型一致
- [ ] **AC-021** (happy-path): Given 表已创建，When 检查索引，Then users.email UNIQUE 索引和 sessions.user_id FK 索引已创建
- [ ] **AC-022** (boundary): Given 重复执行 migration，When 再次运行，Then 幂等处理，不报错

**依赖关系**: 无

**复杂度**: M

**预估工时**: 2h

---

### [ ] T-002: Redis 连接配置

**描述**: 配置 Redis 客户端，支持 Session 存储

**目标文件**:
- apps/server/src/lib/redis.ts
- packages/config/src/index.ts

**Track**: backend

**Requirement IDs**:
- R-001

**验收标准**:
- [ ] **AC-010** (happy-path): Given 正确的连接配置，When 启动应用，Then Redis 客户端连接成功（日志输出 "Redis connected"）
- [ ] **AC-011** (error): Given Redis 服务不可用，When 启动应用，Then 抛出连接错误并优雅降级，不导致进程崩溃
- [ ] **AC-012** (boundary): Given 连接池达到上限，When 新请求到达，Then 排队等待或返回 503

**依赖关系**: 无

**复杂度**: S

**预估工时**: 1h

---

## Phase 2: 核心功能

### [ ] T-003: 用户登录 API

**描述**: 实现用户登录接口，返回 JWT Token

**目标文件**:
- apps/server/src/routes/auth/login.ts
- apps/server/src/services/auth-service.ts
- packages/auth/src/session.ts

**Track**: backend

**Requirement IDs**:
- R-002
- R-003

**验收标准**:
- [ ] **AC-001** (happy-path): Given 有效凭据，When POST /api/auth/login，Then 返回 200 + `{"token": "<JWT>", "expires_at": "<ISO8601>"}`
- [ ] **AC-002** (error): Given 密码错误，When POST /api/auth/login，Then 返回 401 + `{"error": "INVALID_CREDENTIALS"}`
- [ ] **AC-003** (error): Given 用户不存在，When POST /api/auth/login，Then 返回 401（不泄露用户是否存在）
- [ ] **AC-004** (boundary): Given 空 username 或空 password，When POST /api/auth/login，Then 返回 400 参数校验错误

**依赖关系**: T-001, T-002

**复杂度**: M

**预估工时**: 3h

---

## Phase 3: 完善

### [ ] T-005: 单元测试

**描述**: 为核心模块编写单元测试

**目标文件**:
- tests/unit/auth.test.ts
- tests/unit/user.test.ts

**Track**: test

**验收标准**:
- [ ] **AC-030** (happy-path): Given 核心模块代码已实现，When 执行 `npx $TEST_FRAMEWORK tests/unit/`，Then 全部通过且覆盖率 ≥ 80%
- [ ] **AC-031** (boundary): Given 边界输入（空值、超长、特殊字符），When 调用被测函数，Then 按预期抛出异常或返回默认值

**依赖关系**: T-003

**复杂度**: L

**预估工时**: 4h

---

## 任务执行顺序

1. T-001 → T-002（并行）
2. T-003 → T-004（串行，T-004 依赖 T-003）
3. T-005 → T-006（可并行测试）
```

## 命令模板

```bash
# 1. 读取 design.md
DESIGN_FILE="docs/iterations/$DATE/$SEQ-$SLUG-$TYPE/design.md"

# 2. 分析设计文档，提取任务
# - API 接口 → 实现任务（Track: backend）
# - 数据模型 → 迁移任务（Track: infra）
# - 共享类型/配置 → 共享包任务（Track: shared）
# - UI 组件/页面 → 前端任务（Track: frontend）
# - 安全考量 → 安全实现任务（按目标文件归 Track）
# - 测试需求 → 测试任务（Track: test，仅 Phase 3）
# - 目录影响声明 → workspace 落位任务

# 3. 生成任务 ID（T-001, T-002, ...）并绑定 Requirement IDs（R-001, R-002, ...）
TASK_ID="T-$(printf '%03d' $TASK_NUM)"

# 4. 写入 tasks.md
cat > "docs/iterations/$DATE/$SEQ-$SLUG-$TYPE/tasks.md" << 'TEMPLATE'
# 任务分解文档
...
TEMPLATE

# 5. 验证任务完整性
TOTAL_TASKS=$(grep -c "^### \[ \] T-\|^### \[x\] T-" "$TASKS_FILE")
echo "生成了 $TOTAL_TASKS 个任务"

# 5.1 验证 Track 字段覆盖率（每个任务必须声明 Track）
TASKS_WITH_TRACK=$(grep -c "^\*\*Track\*\*:" "$TASKS_FILE")
if [ "$TASKS_WITH_TRACK" -ne "$TOTAL_TASKS" ]; then
  echo "❌ Track 字段缺失：$TOTAL_TASKS 个任务，仅 $TASKS_WITH_TRACK 个声明 Track"
  exit 1
fi

TOTAL_HOURS=$(grep -oP '预估工时: \K[0-9]+' "$TASKS_FILE" | awk '{s+=$1}END{print s}')
TRACK_BREAKDOWN=$(grep -oP '^\*\*Track\*\*: \K\w+' "$TASKS_FILE" | sort | uniq -c | awk '{print $2"="$1}' | paste -sd' ' -)
echo "✅ 任务分解完成: $TOTAL_TASKS 个任务 | 预估工时: ${TOTAL_HOURS}h | Track: $TRACK_BREAKDOWN"
```

## 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| design.md 不存在 | 回退到步骤③ |
| 设计过于笼统 | 提示用户补充设计细节 |
| 任务数超过 20 | 建议拆分为多个子需求 |
| 任务缺少 Track 字段 | 中止生成，要求补全后重试 |
| Track 与目标文件路径不自洽 | 由 Gate 1 报告，触发修订 |

## 相关文件

- 输入：docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/design.md
- 输出：docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/tasks.md
- 参考：
  - references/design-reviewer.md（下一步，Gate 1）
  - SKILL.md Part 4（任务执行阶段）
