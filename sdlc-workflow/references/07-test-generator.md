# 步骤 ⑦: Test Generator — 单元测试生成

> 范围：apply 阶段只生成**单元测试**（处理 `track: unit-test` 的任务）。
> 浏览器自动化 / E2E 脚本（`track: qa`）由 `qa` 命令（步骤 ⑩）编写执行，不在此处生成。

## 输入

1. `docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/tasks.md`（track: unit-test）
2. `git diff`（代码变更）

## 输出

1. `tests/unit/web|server|packages/...`
2. `tests/reports/<slug>-coverage.md`

## 详细行为

### 1. 测试文件生成原则

```
测试生成原则：
1. 单元测试覆盖每个 unit-test 任务的验收标准（必须引用 AC-ID）
2. 测试文件直接写入 tests/unit/ 对应子目录
3. 单元测试路径必须镜像 workspace 源码路径
4. 使用 $TEST_FRAMEWORK 语法（jest/vitest）
5. 测试样例必须引用真实 workspace 路径，不沿用过时的 `src/*` 假设
6. 每个 test case 的描述必须引用对应的 AC-ID 和场景维度，如 `it('AC-002 (error): 密码错误返回 401')`
7. 标注为 qa / playwright-mcp 验证方式的 AC 不在此生成，只需在 coverage.md 中标记为 "deferred to qa"
```

### 2. 单元测试生成

```typescript
// tests/unit/web/logic/calculator.test.ts
// 使用 $TEST_FRAMEWORK 语法
// Covers: AC-001 (happy-path), AC-004 (boundary), AC-005 (error)

import { describe, it, expect, beforeEach } from '$TEST_FRAMEWORK';
import { calculate } from '../../../apps/web/src/logic/calculator';

describe('calculate', () => {
  // AC-001 (happy-path): 正常加法
  it('AC-001 (happy-path): adds two numbers correctly', () => {
    expect(calculate(1, 2, 'add')).toBe(3);
  });

  // AC-005 (error): 除零错误
  it('AC-005 (error): throws on division by zero', () => {
    expect(() => calculate(1, 0, 'divide')).toThrow('Division by zero');
  });

  // AC-004 (boundary): 边界值处理
  it('AC-004 (boundary): handles MAX_SAFE_INTEGER', () => {
    expect(calculate(Number.MAX_SAFE_INTEGER, 1, 'add')).toBe(Number.MAX_SAFE_INTEGER + 1);
  });

  // AC-004 (boundary): 空输入
  it('AC-004 (boundary): throws on NaN input', () => {
    expect(() => calculate(NaN, 1, 'add')).toThrow();
  });
});
```

### 3. E2E / 浏览器测试 —— 本步骤不生成（deferred to qa）

> ⚠️ apply 阶段**不**生成任何 E2E / Playwright 脚本。标注为 `track: qa`、验证方式为
> `qa` / `playwright-mcp` 的 AC，全部留给 `qa` 命令（步骤 ⑩）编写与执行。

本步骤对这些 AC 只做一件事：在 `tests/reports/<slug>-coverage.md` 中标记为 **`deferred to qa`**，
不写 `tests/e2e/**`，也不在覆盖率里计为"已覆盖"。E2E 脚本的生成规范见 `qa` 命令 / `flow-qa.md`。

### 4. 需求到测试映射

```markdown
## Requirement → Test Matrix

| Requirement ID | Task IDs | Test Type | Test File | Scenario ID | Status |
|----------------|----------|-----------|-----------|-------------|--------|
| R-001 | T-001 | unit | tests/unit/web/logic/calculator.test.ts | - | ✅ |
| R-002 | T-003 | unit | tests/unit/server/routes/calc.test.ts | - | ✅ |
| R-003 | T-005 | e2e | （由 qa 命令编写） | E2E-001 | ⏳ deferred to qa |
```

生成规则：

1. 每个 Requirement ID 至少映射一个测试（apply 阶段以单元测试为准）
2. `track: qa` / 验证方式为 qa·playwright-mcp 的 Requirement，本步骤只在矩阵中登记为 `⏳ deferred to qa`，不写测试文件
3. E2E Scenario ID 的唯一性与合并规则由 `qa` 命令负责

### 5. 测试覆盖度分析

生成测试覆盖度分析报告：

```markdown
# tests/reports/<slug>-coverage.md

# 测试覆盖度分析报告

## 基本信息

- **生成时间**: YYYY-MM-DD HH:mm:ss
- **迭代**: docs/iterations/<date>/<seq>-<slug>-<type>/
- **测试框架**: $TEST_FRAMEWORK
- **E2E 框架**: Playwright

## 单元测试覆盖

| 模块 | 覆盖率目标 | 覆盖的验收标准 |
|------|-----------|----------------|
| authService | 80%+ | 登录、登出、Token 验证 |
| userService | 70%+ | 用户 CRUD |
| sessionService | 75%+ | Session 管理 |

## E2E / 浏览器验收覆盖（apply 阶段 deferred）

> apply 阶段不生成 E2E 脚本，下表只登记"留给 qa 命令"的场景，状态恒为 `⏳ deferred to qa`。

| Scenario ID | Requirement IDs | AC-IDs | 场景维度 | 用户场景 | 状态 |
|-------------|-----------------|--------|----------|----------|------|
| E2E-001 | R-001,R-003 | AC-001,AC-002,AC-003,AC-006 | happy+error+boundary+ui | 登录流程 | ⏳ deferred to qa |

## AC 覆盖率汇总（apply 阶段）

> apply 只统计单元测试已覆盖的 AC；E2E / MCP 验证方式的 AC 计入 `deferred to qa`，不计为"未覆盖"。

| 总 AC 数 | 单元测试覆盖 | deferred to qa（E2E/MCP） | 未覆盖（应覆盖但缺测试） |
|----------|-------------|--------------------------|--------------------------|
| 12 | 8 | 4 | 0 |

### 按场景维度覆盖（仅统计单元测试可覆盖的维度）

| 维度 | 总数 | 单元已覆盖 | deferred to qa | 未覆盖 |
|------|------|-----------|----------------|--------|
| happy-path | 4 | 3 | 1 | 0 |
| error | 3 | 3 | 0 | 0 |
| boundary | 2 | 2 | 0 | 0 |
| ui-state | 2 | 0 | 2 | 0 |
| security | 1 | 0 | 1 | 0 |

## 待补充测试

### 边界条件
- [ ] 并发登录处理
- [ ] Token 竞争条件
- [ ] 数据库连接失败

### 异常场景
- [ ] 网络超时处理
- [ ] 服务不可用降级
- [ ] 恶意输入防护
```

### 5. 任务到测试的映射

```javascript
// 任务 → 测试用例映射
const requirementTestMapping = {
  'R-001': ['tests/unit/web/logic/calculator.test.ts'],
  'R-002': ['tests/unit/server/routes/calc.test.ts'],
  'R-003': ['deferred to qa'] // track: qa → 由 qa 命令编写 E2E
};
```

## 命令模板

```bash
#!/bin/bash
set -euo pipefail

SLUG="$1"
ITER_DIR="docs/iterations/$DATE/$SEQ-$SLUG-$TYPE"
TASKS_FILE="$ITER_DIR/tasks.md"

# 读取测试框架配置
TEST_FRAMEWORK=${TEST_FRAMEWORK:-jest}
# 1. 读取 tasks.md，提取验收标准
ACCEPTANCE_CRITERIA=$(cat "$TASKS_FILE" | grep -A 10 "验收标准")

# 2. 生成单元测试（镜像源码目录）
mkdir -p "tests/unit/web/logic"
cat > "tests/unit/web/logic/${SLUG}.test.ts" << 'EOF'
// 单元测试 - 使用 $TEST_FRAMEWORK
import { describe, it, expect, beforeEach } from '$TEST_FRAMEWORK';
...
EOF

# 3. 生成覆盖度报告（qa track 的 AC 标记为 deferred to qa）
cat > "tests/reports/${SLUG}-coverage.md" << 'EOF'
# 测试覆盖度分析报告
...
EOF

echo "✅ 单元测试已生成: tests/unit/ + tests/reports/${SLUG}-coverage.md"
ls -la "tests/unit/web/logic/${SLUG}.test.ts"
```

## 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| tasks.md 不存在 | 回退到步骤④ |
| tests/ 目录不存在 | 自动创建 unit/reports 子目录 |
| 代码与测试不匹配 | 生成 TODO 标记，待 Claude Code 实现后补充 |
| 覆盖率目标未达成 | 在报告中标注，待后续迭代补充 |

## 相关文件

- 输入：
  - docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/tasks.md（track: unit-test）
  - git diff（代码变更）
- 输出：
  - tests/unit/web|server|packages/...
  - tests/reports/<slug>-coverage.md
- 参考：
  - references/09-test-pipeline.md（下一步：lint + unit 执行）
  - references/08-code-reviewer.md（Gate 2）
  - 浏览器 E2E 脚本生成 → `qa` 命令（步骤 ⑩）
