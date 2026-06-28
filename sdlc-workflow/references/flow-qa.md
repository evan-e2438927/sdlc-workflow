# QA — 浏览器功能验收流程

## 概述

`/sdlc-workflow qa <迭代目录>` 是步骤 ⑩：把 tasks.md 中 `track: qa` 的验收规格落成
Playwright 脚本，并通过 Playwright MCP 在真实浏览器中执行功能验收。

它处于 apply 与 accept 之间：apply 写完代码并通过 lint + unit 后，qa 验证关键用户路径，
通过后再由 accept 更新文档并提交。

## 入口

```bash
/sdlc-workflow qa <迭代目录>
# 示例
/sdlc-workflow qa docs/iterations/2026-04-16/001-user-login-feature/
```

若不指定路径，自动查找最近一个 `phase == "applied"` 的迭代目录。

## 前置条件

- `status.json` 中 `phase == "applied"`
- Playwright MCP 可用

## 步骤一：编写自动化测试脚本

读取 `<迭代目录>/tasks.md` 中 `track: qa` 的任务，提取每个验收场景（Given-When-Then +
选择器约束 + 场景维度 ui-state / happy-path / error）。

### deferred to qa 闭环核对（必做）

apply 阶段（步骤 ⑦）会把 qa / playwright-mcp 验证方式的 AC 在 `tests/reports/<slug>-coverage.md`
里标记为 `deferred to qa`。qa 必须确保这些 AC 一个不漏：

```
DEFERRED = 从 tests/reports/<slug>-coverage.md 提取所有标注 "deferred to qa" 的 AC-ID
COVERED  = 本次将生成的 qa 场景所覆盖的 AC-ID
MISSING  = DEFERRED − COVERED

IF MISSING 非空:
  → ⚠️ 报警：这些 deferred 的 AC 在 tasks.md 中没有对应的 track: qa 场景
  → 不得静默跳过：要么补出对应 qa 场景，要么回到 task-generator（④）补 track: qa 任务
```

为每个场景生成 Playwright 脚本，写入 `tests/e2e/<slug>/`：
- 文件命名：`E2E-<nnn>-<scenario>.e2e.ts`
- 测试名称引用 AC-ID，如 `test('AC-005 (ui-state): 登录成功跳转首页', ...)`
- 覆盖：页面导航、用户操作、断言（UI 元素、URL、响应内容）
- 每个场景使用唯一 Scenario ID，绑定 Requirement IDs 和 Task IDs，不重复覆盖同一路径

## 步骤二：执行功能测试

通过 Playwright MCP 启动浏览器，逐一执行：

```
FOR EACH E2E 场景:
  navigate → snapshot（确认可见状态）
  → click / type（核心操作序列）
  → 断言结果 + 检查 console error
  → 失败时截图保存到 tests/reports/<slug>/screenshots/
```

dev server 启动：读 package.json scripts（dev > start > serve），后台启动并等待 ready，
提取实际监听 URL。**收尾**：记录后台进程 PID，全部场景执行完（无论通过与否）后必须 teardown
该 dev server，避免遗留孤儿进程占用端口（worktree 模式下尤其注意释放注入的 PORT/API_PORT）。

## 步骤三：输出测试报告

生成 `tests/reports/<slug>-e2e-report.md`：
- 通过/失败场景列表
- AC 覆盖率统计
- 失败场景的错误信息和截图路径

## 结果

**全部通过** → 更新 `status.json`（phase: "qa_passed"），输出：
```
✅ QA 通过: N/N 场景 | 覆盖 AC: N 个
👉 确认无误后提交: /sdlc-workflow:accept
```

**存在失败** → 先按失败根因分流处理，**不要笼统地"重跑 apply"**（apply 遇到 `phase==applied`
会直接中止）：

```
FOR EACH 失败场景，判定根因：

A) 脚本/选择器问题（选择器写错、等待时机、断言过严等，代码本身没错）
   → 在 qa 内就地修复脚本并重跑，最多 REVIEW_MAX_ROUNDS 轮
   → phase 保持 applied，无需回 apply

B) 确属代码缺陷（功能/行为不符合 AC）
   → 把 phase 退回 approved：
     jq '.phase="approved" | .qa_failed_at=now' status.json
   → 提示用户：修复代码后重新运行 /sdlc-workflow:apply（此时 apply 可正常执行）

C) 超过 REVIEW_MAX_ROUNDS 仍失败 → 中止，输出失败列表 + 截图路径，提示人工介入
```

> 关键：旧文案"修复后重跑 apply"在 phase 仍是 applied 时会被 apply 的前置守卫拒绝。
> 因此代码缺陷必须先把 phase 退回 approved，apply 才能重入。

## 输入 / 输出

| | 路径 | 说明 |
|--|------|------|
| 输入 | `docs/iterations/.../tasks.md` | track: qa 的验收规格 |
| 输入 | `docs/iterations/.../status.json` | 确认 phase == applied |
| 输出 | `tests/e2e/<slug>/E2E-*.e2e.ts` | Playwright 脚本 |
| 输出 | `tests/reports/<slug>-e2e-report.md` | 验收报告 |
| 输出 | `docs/iterations/.../status.json` | 更新 phase 为 qa_passed（全部 PASS 时）|

## 流程中的位置

```
proposal → apply → qa → accept → pr
                    ↑ 你在这里（浏览器功能验收）
```

## 相关文件

- `references/flow-apply.md` — 前置步骤（开发 + 单元测试）
- `references/07-test-generator.md` — 单元测试生成（区别于此处的 E2E）
- `references/flow-accept.md` — 后续步骤（文档 + 本地 commit）
- `references/12-pr-creator.md` — push + 创建 PR
