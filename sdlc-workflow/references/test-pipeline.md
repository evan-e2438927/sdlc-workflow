# 步骤 ⑨: Test Pipeline — 测试执行

## 输入

`tests/unit/` 和 `tests/e2e/` 内的测试文件

## 输出

`tests/reports/<slug>-<timestamp>.md` — 测试执行报告

## 详细行为

### 1. 三阶段执行

```mermaid
graph LR
    LINT["Stage 1: Lint<br/>$LINT_TOOL"]
    UNIT["Stage 2: Unit<br/>$TEST_FRAMEWORK"]
    E2E["Stage 3: E2E<br/>$E2E_FRAMEWORK"]

    LINT --> UNIT
    LINT --> E2E
    UNIT --> REPORT["测试报告"]
    E2E --> REPORT
```

### 2. Stage 1: Lint

快速失败，代码静态检查：

```bash
LINT_TOOL=${LINT_TOOL:-eslint}

case "$LINT_TOOL" in
  eslint)
    echo "🔍 运行 ESLint..."
    npx eslint . --max-warnings 0
    ;;
  biome)
    echo "🔍 运行 Biome..."
    npx biome check . --error-on-warnings
    ;;
  *)
    echo "⚠️ 未知的 LINT_TOOL: $LINT_TOOL"
    ;;
esac
```

### 3. Stage 2: Unit Tests

```bash
TEST_FRAMEWORK=${TEST_FRAMEWORK:-jest}

case "$TEST_FRAMEWORK" in
  jest)
    echo "🧪 运行 Jest 单元测试..."
    npx jest tests/unit/ --coverage --json --outputFile=tests/reports/jest-output.json
    ;;
  vitest)
    echo "🧪 运行 Vitest 单元测试..."
    npx vitest run tests/unit/ --coverage --reporter=json
    ;;
  mocha)
    echo "🧪 运行 Mocha 单元测试..."
    npx mocha tests/unit/ --reporter json > tests/reports/mocha-output.json
    ;;
  *)
    echo "⚠️ 未知的 TEST_FRAMEWORK: $TEST_FRAMEWORK"
    ;;
esac
```

### 4. Stage 3: Playwright E2E 测试

```bash
echo "🎭 运行 Playwright E2E 测试..."
npx playwright test tests/e2e/ --reporter=html,json

if [ -f "playwright-report/index.html" ]; then
  echo "📊 Playwright 测试报告已生成"
fi
```

### 5. 并行执行

Stage 2 和 Stage 3 可以并行执行（如果无依赖）：

```bash
PARALLEL_TESTS=${PARALLEL_TESTS:-false}

if [ "$PARALLEL_TESTS" = "true" ]; then
  echo "🚀 并行执行 Unit 和 E2E..."

  run_unit_tests &
  PID_UNIT=$!

  run_e2e_tests &
  PID_E2E=$!

  wait $PID_UNIT || UNIT_EXIT=$?
  wait $PID_E2E || E2E_EXIT=$?

  UNIT_EXIT=${UNIT_EXIT:-0}
  E2E_EXIT=${E2E_EXIT:-0}

  if [ "$UNIT_EXIT" -ne 0 ] || [ "$E2E_EXIT" -ne 0 ]; then
    echo "❌ 部分测试失败"
    exit 1
  fi
else
  run_unit_tests
  run_e2e_tests
fi
```

### 6. 测试报告生成

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="tests/reports/${SLUG}-${TIMESTAMP}.md"

cat > "$REPORT_FILE" << 'EOF'
# 测试执行报告

## 基本信息

- **执行时间**: YYYY-MM-DD HH:mm:ss
- **迭代**: <seq>-<slug>-<type>
- **测试框架**: $TEST_FRAMEWORK

## 测试结果

| 阶段 | 状态 | 通过/总数 | 覆盖率 |
|------|------|-----------|--------|
| Lint | ✅ | - | - |
| Unit | ✅ | 25/25 | 85% |
| E2E  | ✅ | 8/8 | - |

## Requirement → Test Matrix

| Requirement ID | Task IDs | Test File | Scenario ID |
|----------------|----------|-----------|-------------|
| R-001 | T-001 | tests/unit/... | - |
| R-003 | T-005 | tests/e2e/... | E2E-001 |

## 失败用例（如有）

<!-- 如有失败，在此列出 -->

## 后续步骤

如需功能验收，运行 `/sdlc-workflow accept <迭代目录>` 进行 Playwright MCP 人工验收（可选）。
EOF

echo "📋 测试报告: $REPORT_FILE"
```

### 7. 循环修复逻辑

```bash
round=1
max_rounds=${REVIEW_MAX_ROUNDS:-1}

while [ $round -le $max_rounds ]; do
  echo "🧪 测试执行第 $round 轮..."

  run_lint
  run_unit_tests
  run_e2e_tests

  if all_tests_pass; then
    echo "✅ 所有测试通过"
    exit 0
  fi

  if [ $round -eq $max_rounds ]; then
    echo "❌ 测试修复超过 $max_rounds 轮，需人工介入"
    exit 1
  fi

  echo "⚠️ 测试失败，Claude Code 修复中..."
  round=$((round + 1))
done
```

## 命令模板

```bash
#!/bin/bash
set -euo pipefail

SLUG="$1"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="tests/reports/${SLUG}-${TIMESTAMP}.md"

LINT_TOOL=${LINT_TOOL:-eslint}
TEST_FRAMEWORK=${TEST_FRAMEWORK:-jest}
REVIEW_MAX_ROUNDS=${REVIEW_MAX_ROUNDS:-1}

run_lint() {
  case "$LINT_TOOL" in
    eslint) npx eslint . --max-warnings 0 ;;
    biome) npx biome check . --error-on-warnings ;;
    *) echo "未知的 LINT_TOOL: $LINT_TOOL" >&2; return 1 ;;
  esac
}

run_unit_tests() {
  case "$TEST_FRAMEWORK" in
    jest) npx jest tests/unit/ --coverage --json --outputFile=tests/reports/jest-output.json ;;
    vitest) npx vitest run tests/unit/ --coverage --reporter=json ;;
    mocha) npx mocha tests/unit/ --reporter json > tests/reports/mocha-output.json ;;
    *) echo "未知的 TEST_FRAMEWORK: $TEST_FRAMEWORK" >&2; return 1 ;;
  esac
}

run_e2e_tests() {
  npx playwright test tests/e2e/ --reporter=html,json
}

round=1

while [ $round -le $REVIEW_MAX_ROUNDS ]; do
  echo "🧪 测试执行第 $round 轮..."
  LINT_FAILED=0
  UNIT_FAILED=0
  E2E_FAILED=0

  echo "🔍 Stage 1: Lint..."
  run_lint || LINT_FAILED=1

  echo "🧪 Stage 2: Unit Tests..."
  run_unit_tests || UNIT_FAILED=1

  echo "🎭 Stage 3: E2E Tests..."
  run_e2e_tests || E2E_FAILED=1

  if [ "$LINT_FAILED" -eq 0 ] && [ "$UNIT_FAILED" -eq 0 ] && [ "$E2E_FAILED" -eq 0 ]; then
    echo "✅ 所有测试通过"
    mkdir -p tests/reports
    cat > "$REPORT_FILE" << REPORT
# 测试执行报告
- 执行时间: $(date)
- 迭代: $SLUG
- 框架: $TEST_FRAMEWORK
REPORT
    echo "📋 测试报告: $REPORT_FILE"
    exit 0
  fi

  if [ $round -eq $REVIEW_MAX_ROUNDS ]; then
    echo "❌ 测试修复超过 $REVIEW_MAX_ROUNDS 轮"
    exit 1
  fi

  echo "⚠️ 测试失败，修复中..."
  round=$((round + 1))
done
```

## 上下文保护

- 进入 test-pipeline 前，若 `context_usage > 70%` 必须先执行 `/compact`
- 进入前必须将 `pipeline_stage="test-pipeline"` 写入 status.json

## 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| 测试框架未安装 | 提示安装，abort |
| 测试文件不存在 | 警告，跳过该阶段 |
| E2E 测试超时 | 增加 timeout 配置 |
| 并行执行失败 | 回退为串行执行 |
| 修复超限 | 打印失败详情，中止，需人工介入 |

## 相关文件

- 输入：
  - tests/unit/*.test.ts
  - tests/e2e/*.e2e.ts
- 输出：
  - tests/reports/<slug>-<timestamp>.md
- 参考：
  - references/accept.md（Playwright MCP 功能验收，可选，人工运行）
  - references/test-generator.md（测试生成）
  - references/docs-updater.md（下一步）
