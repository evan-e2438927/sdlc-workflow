# 步骤 ⑦: Test Generator — 测试用例生成

## 输入

1. `docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/tasks.md`
2. `git diff`（代码变更）

## 输出

1. `tests/unit/web|server|packages/...`
2. `tests/e2e/<slug>/E2E-<nnn>-<scenario>.e2e.ts`
3. `tests/reports/<slug>-coverage.md`

## 详细行为

### 1. 测试文件生成原则

```
测试生成原则：
1. 单元测试覆盖每个任务的验收标准（必须引用 AC-ID）
2. E2E 测试覆盖关键用户场景（必须覆盖 happy-path + error + boundary 维度）
3. 测试文件直接写入 tests/ 对应子目录
4. 单元测试路径必须镜像 workspace 源码路径
5. E2E 场景文件必须使用唯一 Scenario ID，避免重复
5. 使用 $TEST_FRAMEWORK 语法（jest/vitest）
6. E2E 执行固定使用 Playwright
7. 测试样例必须引用真实 workspace 路径，不沿用过时的 `src/*` 假设
8. 每个 E2E 场景必须绑定 Requirement IDs 和 Task IDs
9. 若已有 E2E 场景覆盖同一需求路径，应扩展原场景或记录替代关系，不得重复生成
10. 每个 test case 的描述必须引用对应的 AC-ID 和场景维度，如 `it('AC-002 (error): 密码错误返回 401')`
11. 验收标准中标注为 playwright-mcp 验证方式的 AC，必须在 Playwright MCP 验收步骤中有对应的验证计划，test-generator 只需在 coverage.md 中标记为 "deferred to MCP"
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

### 3. E2E 测试生成

```typescript
// tests/e2e/<slug>/E2E-001-basic-calculation.e2e.ts
// Scenario-ID: E2E-001
// Requirement-IDs: R-001,R-003
// Task-IDs: T-002,T-005
// AC-IDs: AC-001,AC-002,AC-003,AC-006
// 使用 Playwright 语法

import { test, expect } from '@playwright/test';

test.describe('User Authentication Flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  // AC-006 (ui-state): 登录表单初始状态
  test('AC-006 (ui-state): should show login form with all required fields', async ({ page }) => {
    await expect(page.locator('input[name="username"]')).toBeVisible();
    await expect(page.locator('input[name="password"]')).toBeVisible();
    const submitBtn = page.locator('button[type="submit"]');
    await expect(submitBtn).toBeVisible();
    await expect(submitBtn).toBeEnabled();
  });

  // AC-001 (happy-path): 有效凭据登录成功
  test('AC-001 (happy-path): should login and show profile with valid credentials', async ({ page }) => {
    await page.fill('input[name="username"]', 'testuser');
    await page.fill('input[name="password"]', 'password123');
    await page.click('button[type="submit"]');

    await expect(page.locator('.user-profile')).toBeVisible({ timeout: 5000 });
    await expect(page.locator('.user-profile')).toContainText('testuser');
  });

  // AC-002 (error): 密码错误时显示错误提示
  test('AC-002 (error): should show error message on invalid password', async ({ page }) => {
    await page.fill('input[name="username"]', 'testuser');
    await page.fill('input[name="password"]', 'wrongpassword');
    await page.click('button[type="submit"]');

    await expect(page.locator('.error-message')).toBeVisible();
    await expect(page.locator('.error-message')).toContainText('Invalid credentials');
  });

  // AC-003 (boundary): 空密码提交
  test('AC-003 (boundary): should show validation error on empty password', async ({ page }) => {
    await page.fill('input[name="username"]', 'testuser');
    await page.click('button[type="submit"]');

    // 表单验证应阻止提交或显示验证错误
    await expect(page.locator('.validation-error, input[name="password"]:invalid')).toBeVisible();
  });
});
```

### 4. 需求到测试映射

```markdown
## Requirement → Test Matrix

| Requirement ID | Task IDs | Test Type | Test File | Scenario ID | Status |
|----------------|----------|-----------|-----------|-------------|--------|
| R-001 | T-001 | unit | tests/unit/web/logic/calculator.test.ts | - | ✅ |
| R-002 | T-003 | unit | tests/unit/server/routes/calc.test.ts | - | ✅ |
| R-003 | T-005 | e2e | tests/e2e/calculator/E2E-001-basic-calculation.e2e.ts | E2E-001 | ✅ |
```

生成规则：

1. 每个 Requirement ID 至少映射一个测试
2. 每个 E2E Scenario ID 必须唯一
3. 若两个 E2E 场景覆盖同一 Requirement 集合和同一用户路径，应合并而不是重复生成

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

## E2E 测试覆盖

| Scenario ID | Requirement IDs | AC-IDs | 场景维度 | 用户场景 | 测试文件 | 状态 |
|-------------|-----------------|--------|----------|----------|----------|------|
| E2E-001 | R-001,R-003 | AC-001,AC-002,AC-003,AC-006 | happy+error+boundary+ui | 登录流程 | tests/e2e/calculator/E2E-001-basic-calculation.e2e.ts | ✅ |

## AC 覆盖率汇总

| 总 AC 数 | 单元测试覆盖 | E2E 覆盖 | MCP 验收覆盖 | 未覆盖 |
|----------|-------------|----------|-------------|--------|
| 12 | 8 | 6 | 3 | 0 |

### 按场景维度覆盖

| 维度 | 总数 | 已覆盖 | 覆盖率 |
|------|------|--------|--------|
| happy-path | 4 | 4 | 100% |
| error | 3 | 3 | 100% |
| boundary | 2 | 2 | 100% |
| ui-state | 2 | 1 | 50% (1 deferred to MCP) |
| security | 1 | 1 | 100% |

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
  'R-003': ['tests/e2e/calculator/E2E-001-basic-calculation.e2e.ts']
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
mkdir -p "tests/unit/web/logic" "tests/e2e/${SLUG}"
cat > "tests/unit/web/logic/${SLUG}.test.ts" << 'EOF'
// 单元测试 - 使用 $TEST_FRAMEWORK
import { describe, it, expect, beforeEach } from '$TEST_FRAMEWORK';
...
EOF

# 3. 生成 E2E 测试（唯一 Scenario ID）
cat > "tests/e2e/${SLUG}/E2E-001-${SLUG}.e2e.ts" << 'EOF'
// E2E 测试 - 使用 Playwright
import { test, expect } from '@playwright/test';
...
EOF

# 4. 生成覆盖度报告
cat > "tests/reports/${SLUG}-coverage.md" << 'EOF'
# 测试覆盖度分析报告
...
EOF

echo "✅ 测试用例生成完成"
ls -la "tests/unit/web/logic/${SLUG}.test.ts" "tests/e2e/${SLUG}/E2E-001-${SLUG}.e2e.ts"

echo "✅ 测试用例已生成: tests/unit/ + tests/e2e/${SLUG}/ + tests/reports/${SLUG}-coverage.md"
```

## 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| tasks.md 不存在 | 回退到步骤④ |
| tests/ 目录不存在 | 自动创建 unit/e2e/reports 子目录 |
| 代码与测试不匹配 | 生成 TODO 标记，待 Claude Code 实现后补充 |
| 覆盖率目标未达成 | 在报告中标注，待后续迭代补充 |

## 相关文件

- 输入：
  - docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/tasks.md
  - git diff（代码变更）
- 输出：
  - tests/unit/web|server|packages/...
  - tests/e2e/<slug>/E2E-<nnn>-<scenario>.e2e.ts
  - tests/reports/<slug>-coverage.md
- 参考：
  - references/test-pipeline.md（下一步：测试执行）
  - references/code-reviewer.md（Gate 2）
