# Mini Pipeline — 小任务强制执行顺序

## 目的

定义 `/sdlc-workflow mini` 的强制执行顺序，避免模型直接改代码而跳过：

- iteration 产物
- Gate 1（加 `--review` 时）
- validation capability detection
- Gate 2（加 `--review` 时）
- 浏览器功能验收（加 `--qa` 时）

## 强制顺序

### Step 0. Preconditions

1. 项目必须已完成 `/sdlc-workflow init`
2. 若缺少 baseline 文档且项目为 existing project，先回退执行 `init`
3. 判断是否满足 mini 条件；不满足立即升级到 `/sdlc-workflow doit`

### Step 1. Create Iteration

必须先创建 iteration 目录，再做任何业务代码修改：

```text
docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/
```

### Step 2. Write requirements.md

要求：

1. 写明需求摘要
2. 写明影响范围
3. 写明验收条件
4. 标注 `Change Size: Micro`

### Step 3. Write design.md

要求：

1. 写明影响文件
2. 写明 `无架构变更`
3. 写明是否沿用 existing structure
4. 写明最终验收方式

### Step 4. Write tasks.md

要求：

1. 任务标题必须使用 `[ ]` / `[x]`
2. 至少包含：
   - 修改目标文件
   - 验证能力检测
   - 回写任务状态

### Step 5. Gate 1（仅 `--review`）

在修改业务代码前，若指定 `--review`，执行 mini Gate 1：

检查：

1. 是否真的属于 mini change
2. 是否无架构变更
3. 是否无目录结构调整
4. 是否目标文件范围足够小

若失败：立即中止或升级到 `/sdlc-workflow doit`

### Step 6. Implement

Gate 1 通过（或跳过）后，开始修改业务代码。

### Step 7. Validation Capability Detection

在 Gate 2 前必须检测：

1. lint 能力
2. unit test 能力
3. Playwright E2E 能力

并输出到 mini 报告。

### Step 8. Gate 2（仅 `--review`）

实现后若指定 `--review`，执行 mini Gate 2：

检查：

1. 修改是否越界
2. 是否误伤现有结构
3. `tasks.md` 是否已同步回写
4. 是否存在不必要的测试或基础设施改动

### Step 9. Automated Tests

执行自动化测试：

1. Lint
2. Unit Tests

（浏览器 E2E 不在此处；加 `--qa` 时见 Step 9.5）

### Step 9.5. QA（仅 `--qa`）

读取 qa track 场景，编写并通过 Playwright MCP 执行浏览器功能验收。

### Step 10. Final Report

必须生成 mini 报告，至少包含：

1. Scope
2. Changed Files
3. Gate 1 result（若执行）
4. Validation Capability Detection
5. Gate 2 result（若执行）
6. Test results (Lint / Unit；`--qa` 时含 E2E)
7. Tasks status
8. Residual risks

随后由 docs-updater 更新文档、git-committer 本地提交，再由 pr-creator push 并创建 PR。

## Hard Rules

1. 不得在 Step 1-4 之前直接编辑业务代码
2. `--review` 时不得跳过 Gate 1 / Gate 2
3. 不得跳过 validation capability detection
4. **Token 耗尽保护**：context_usage > 70% 时先 /compact 再继续；token 不足时写入 `status.json: pipeline_stage="mini-incomplete"` + ABORT，禁止静默标记完成
