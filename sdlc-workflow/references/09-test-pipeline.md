# 步骤 ⑨: Test Pipeline — 静态检查 + 单元测试

## 输入

`tests/unit/` 内的单元测试文件

## 输出

`tests/reports/<slug>-<timestamp>.md` — 测试执行报告

## 范围

**test-pipeline 只做 Stage 1（Lint）+ Stage 2（Unit）两阶段**，是 apply 的代码自检环节。

浏览器自动化 / E2E（编写 Playwright 脚本 + 真实浏览器执行）**不在此处**，已独立为
`qa` 命令（步骤 ⑩）。因此本流程不再有 `--e2e` 参数，也不启动浏览器。

```bash
/sdlc-workflow apply     # lint + unit
/sdlc-workflow qa        # 浏览器功能验收（独立命令）
```

## 详细行为

### 1. 执行阶段

```mermaid
graph LR
    LINT["Stage 1: Lint<br/>$LINT_TOOL"]
    UNIT["Stage 2: Unit<br/>$TEST_FRAMEWORK"]

    LINT --> UNIT
    UNIT --> REPORT["测试报告"]
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

> 浏览器 / E2E 测试已移至 `qa` 命令（步骤 ⑩），test-pipeline 到 Stage 2 为止。

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

## Requirement → Test Matrix

| Requirement ID | Task IDs | Test File |
|----------------|----------|-----------|
| R-001 | T-001 | tests/unit/... |
| R-003 | T-005 | tests/unit/... |

## 失败用例（如有）

<!-- 如有失败，在此列出 -->

## 后续步骤

lint + unit 通过后，运行 `/sdlc-workflow qa` 做浏览器功能验收，再运行 `/sdlc-workflow accept` 更新文档并提交。
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

round=1

while [ $round -le $REVIEW_MAX_ROUNDS ]; do
  echo "🧪 测试执行第 $round 轮..."
  LINT_FAILED=0
  UNIT_FAILED=0

  echo "🔍 Stage 1: Lint..."
  run_lint || LINT_FAILED=1

  echo "🧪 Stage 2: Unit Tests..."
  run_unit_tests || UNIT_FAILED=1

  if [ "$LINT_FAILED" -eq 0 ] && [ "$UNIT_FAILED" -eq 0 ]; then
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
| 并行执行失败 | 回退为串行执行 |
| 修复超限 | 打印失败详情，中止，需人工介入 |

## 相关文件

- 输入：
  - tests/unit/*.test.ts
- 输出：
  - tests/reports/<slug>-<timestamp>.md
- 参考：
  - references/07-test-generator.md（单元测试生成）
  - references/flow-qa.md（浏览器功能验收，步骤 ⑩）
  - references/flow-accept.md（验收提交：文档 + 本地 commit）
  - references/12-pr-creator.md（push + 创建 PR，步骤 ⑬）
