---
description: 编写浏览器自动化测试脚本并执行功能验收测试
argument-hint: [<迭代目录>]
---

执行 `sdlc-workflow qa`，参数：$ARGUMENTS（步骤 ⑩，详细规范见 `${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/references/flow-qa.md`）

查找迭代目录（若未指定，取最近一个 `phase == "applied"` 的目录）。

## 前置检查

- `status.json` 中 `phase == "applied"` 才可执行
- Playwright MCP 可用

## 步骤一：编写自动化测试脚本

读取 `<迭代目录>/tasks.md` 中 **`track: qa`** 的任务，提取每个验收场景（Given-When-Then + 选择器约束 + 场景维度 ui-state / happy-path / error）。

**deferred to qa 闭环核对**：比对 apply 生成的 `tests/reports/<slug>-coverage.md` 中标注 `deferred to qa` 的 AC，确认每个都有对应 qa 场景；缺失则报警（详见 flow-qa.md「deferred to qa 闭环核对」）。

为每个场景生成 Playwright 测试脚本，写入 `tests/e2e/<slug>/`：
- 文件命名：`E2E-<nnn>-<scenario>.e2e.ts`
- 测试名称引用 AC-ID，如 `test('AC-005 (ui-state): 登录成功跳转首页', ...)`
- 覆盖：页面导航、用户操作、断言（UI 元素、URL、响应内容）

## 步骤二：执行功能测试

通过 Playwright MCP 启动浏览器，逐一执行测试场景：

```
for each E2E scenario:
  - 启动页面
  - 执行操作序列
  - 验证断言
  - 截图（失败时保存到 tests/reports/<slug>/screenshots/）
```

## 步骤三：输出测试报告

生成 `tests/reports/<slug>-e2e-report.md`，包含：
- 通过/失败场景列表
- AC 覆盖率统计
- 失败场景的错误信息和截图路径

**全部通过** → 更新 `status.json`（phase: "qa_passed"），输出：
```
✅ QA 通过: N/N 场景 | 覆盖 AC: N 个
👉 确认无误后提交: /sdlc-workflow:accept
```

**存在失败** → 按根因分流（不要笼统重跑 `apply`，phase==applied 时 apply 会中止）：
- **脚本/选择器问题** → 在 qa 内就地修脚本并重跑（≤ REVIEW_MAX_ROUNDS 轮），phase 保持 applied
- **确属代码缺陷** → 把 phase 退回 `approved`（`.qa_failed_at=now`），提示修复代码后重新运行 `apply`
- **超限仍失败** → 中止，输出失败列表 + 截图路径，提示人工介入

（详见 flow-qa.md「结果」）
