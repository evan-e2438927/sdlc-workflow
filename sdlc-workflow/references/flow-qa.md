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

若不指定路径，用 `bash "$SDLC_STATUS" find-latest applied` 自动定位（`SDLC_STATUS` 见 SKILL.md「迭代状态（phase）」）。

每次运行都**执行全部场景**（不只是上次失败的场景），兼作修复后的回归。

## 前置条件

- `status.json` 中 `phase == "applied"`
- Playwright MCP 可用
- 执行前经统一上下文加载（见 `references/context-loader.md`），使编写测试脚本时也消费 `CTX.skills` 与编码规范

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
  → 通过时：take_screenshot 截成功态 → **立即 move** 到
      tests/reports/<slug>/screenshots/<Scenario-ID>.png
  → 失败时：同样 move 诊断图到 tests/reports/<slug>/screenshots/（仅排障）
```

> ⚠️ **Playwright MCP 的 `take_screenshot` 默认落在工作目录根**（cwd），不听指定路径。
> 因此每次截图后必须**显式 `mv`** 到 `tests/reports/<slug>/screenshots/<Scenario-ID>.png`，
> 否则截图会散落在项目根。一个场景覆盖多 AC 时以场景为单位截一张。
>
> 截图**保存在项目内但不入库**：`tests/reports/**/screenshots/` 与 `tests/reports/**/*.png`
> 已被 `.gitignore` 忽略。pr 阶段会把它们推送到**隔离的 `pr-assets` 分支**再嵌入 PR 正文
> （见 references/12-pr-creator.md「验收截图」），主干与工作区始终不含二进制。

dev server 启动：读 package.json scripts（dev > start > serve），后台启动并等待 ready，
提取实际监听 URL。**收尾**：记录后台进程 PID，全部场景执行完（无论通过与否）后必须 teardown
该 dev server，避免遗留孤儿进程占用端口（worktree 模式下尤其注意释放注入的 PORT/API_PORT）。

## 步骤三：输出测试报告

生成 `tests/reports/<slug>-e2e-report.md`：
- 通过/失败场景列表
- AC 覆盖率统计
- 失败场景的错误信息和诊断截图路径
- 通过场景的证据截图路径（`tests/reports/<slug>/screenshots/<Scenario-ID>.png`，gitignore、仅本地）

## 结果

**全部通过** → `bash "$SDLC_STATUS" transition "$ITER_DIR" qa_passed --by qa`，输出：
```
✅ QA 通过: N/N 场景 | 覆盖 AC: N 个
👉 确认无误后提交: /sdlc-workflow:accept
```

**存在失败** → qa 不改业务代码，先按失败根因分流：

```
FOR EACH 失败场景，判定根因：

A) 脚本/选择器问题（选择器写错、等待时机、断言过严等，代码本身没错）
   → 在 qa 内就地修复脚本并重跑，按 SKILL.md「修复轮数（唯一定义）」计数
   → phase 保持 applied；修满 N 轮仍失败 → 停下，输出失败列表 + 截图路径，转人工

B) 确属代码缺陷（功能/行为不符合 AC）
   → 写 $ITER_DIR/qa-failures.md（格式见下）
   → bash "$SDLC_STATUS" transition "$ITER_DIR" qa_failed --by qa
   → teardown dev server，提示运行 sdlc-apply（自动进入修复模式，见 flow-apply.md「修复模式（phase = qa_failed）」）
   → doit --qa：自动执行修复模式后重跑 qa，按「修复轮数（唯一定义）」计数，超限停在 qa_failed
```

A、B 同时存在时先处理 A，仍有代码缺陷再走 B。

`qa-failures.md` 格式（qa 写入，apply 修复模式读取）：

```markdown
# QA 缺陷清单：<slug>

### E2E-003-login-lockout
- AC-ID: AC-007
- 步骤: 连续 5 次输入错误密码
- 期望: 第 5 次后提示「账户已锁定 15 分钟」
- 实际: 第 5 次仍可继续尝试
- 截图: tests/reports/<slug>/screenshots/E2E-003-login-lockout.png
- 归属 track: backend
```

每次进入 qa_failed 时重写整个文件（只列本轮失败场景），上一轮的内容与「已修复」标注随之清除；历次失败轮次可从 status.json 的 `history` 查到。
修复完成后由 apply 在文件首行插入 `> 已修复：<ISO 时间>`；qa 重跑全部通过后该文件保留作记录。

## 输入 / 输出

| | 路径 | 说明 |
|--|------|------|
| 输入 | `docs/iterations/.../tasks.md` | track: qa 的验收规格 |
| 输入 | `docs/iterations/.../status.json` | 确认 phase == applied |
| 输出 | `tests/e2e/<slug>/E2E-*.e2e.ts` | Playwright 脚本 |
| 输出 | `tests/reports/<slug>-e2e-report.md` | 验收报告 |
| 输出 | `tests/reports/<slug>/screenshots/<Scenario-ID>.png` | 通过场景证据截图（gitignore、仅本地，供 pr 推送 pr-assets 分支）|
| 输出 | `docs/iterations/.../qa-failures.md` | 代码缺陷清单（存在代码缺陷时）|
| 输出 | `docs/iterations/.../status.json` | 经状态脚本迁移到 qa_passed（全部 PASS）或 qa_failed（代码缺陷）|

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
