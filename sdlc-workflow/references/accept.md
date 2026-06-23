# Accept — Playwright MCP 功能验收流程

## 概述

`/sdlc-workflow accept <迭代目录>` 是一个**可选的、人工触发**的验收步骤，
在 apply 完成（代码已提交/PR 已创建）后，通过 Playwright MCP 对关键用户路径做功能验收。

此步骤**不在自动流程**（proposal/apply/doit）中执行，由开发者在本地按需运行。

## 入口

```bash
/sdlc-workflow accept <迭代目录>
# 示例
/sdlc-workflow accept docs/iterations/2026-04-16/001-user-login-feature/
```

若不指定路径，自动查找最近一个 `phase == "applied"` 的迭代目录。

## 前置条件

```bash
STATUS_FILE="$ITER_DIR/status.json"

if [ ! -f "$STATUS_FILE" ]; then
  echo "❌ 未找到 status.json，请先运行 apply 流程"
  exit 1
fi

PHASE=$(jq -r '.phase' "$STATUS_FILE")

if [ "$PHASE" != "applied" ] && [ "$PHASE" != "accepted" ]; then
  echo "❌ 当前 phase 为 $PHASE，请先完成 apply 流程"
  exit 1
fi
```

## 执行步骤

### 1. 读取验收标准

```
读取 $ITER_DIR/tasks.md 中每个任务的验收标准（AC 列表）
提取关键用户路径和 E2E 场景 ID
```

### 2. 启动 Dev Server

```
1. 检测启动命令
   → 读取 package.json 的 scripts 字段
   → 按优先级选择: dev > start > serve
   → monorepo 项目检查 apps/web 或根目录的启动命令
   → 无法确定时读取 README.md 或 ARCHITECTURE.md

2. 后台启动 dev server
   → 使用 run_command 后台执行（如 npm run dev）
   → 设置 WaitMsBeforeAsync >= 3000ms

3. 等待就绪
   → 从输出中确认 ready / listening / started 关键词
   → 提取实际监听的 URL 和端口

4. 验证可访问
   → browser_navigate(url) 打开首页确认加载正常
   → 如果首页加载失败，检查 dev server 日志排查原因
```

### 3. Playwright MCP 验收

对 tasks.md 中每个关键用户路径执行：

```
FOR EACH 关键用户路径 IN tasks.md 的验收标准:

  步骤 1: 导航到目标页面
    → browser_navigate(url)
    → 等待页面加载完成

  步骤 2: 获取页面快照，确认可见状态
    → browser_snapshot()
    → 验证关键 UI 元素存在且内容正确
    → 记录: "✅ 页面可见状态符合预期" 或 "❌ 期望看到 X，实际看到 Y"

  步骤 3: 执行关键交互操作
    → browser_click(element) / browser_type(element, text)
    → 模拟用户的核心操作路径（登录、提交表单、点击按钮等）
    → 每次操作后 browser_snapshot() 确认结果

  步骤 4: 检查控制台错误
    → browser_console_messages()
    → 确认无未处理的 error 级别消息
    → 记录: "✅ Console 无错误" 或 "❌ Console 存在错误: ..."

  步骤 5: 截图留证
    → browser_screenshot()
    → 保存截图到 tests/reports/playwright/<slug>-<scenario>.png
```

### 4. 生成验收记录

每个场景生成一份 `tests/reports/playwright/<slug>-<scenario>.md`：

```markdown
# Playwright MCP 验收记录

- **场景**: <scenario 描述>
- **URL**: <dev server 实际地址>
- **时间**: YYYY-MM-DD HH:mm:ss

## 验收项

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 页面可见状态 | ✅/❌ | 关键元素是否存在且内容正确 |
| 交互操作响应 | ✅/❌ | 点击/输入后页面是否正确响应 |
| Console 错误 | ✅/❌ | 是否存在未处理的 error |

## 截图证据

![验收截图](./screenshot-<scenario>.png)

## 结论

**PASS** / **FAIL**
```

### 5. 更新 status.json

```bash
# 所有场景 PASS
jq '.phase = "accepted" | .accepted_at = now | .acceptance_report = "tests/reports/playwright/"' \
  "$STATUS_FILE" > tmp.json && mv tmp.json "$STATUS_FILE"

echo "✅ 验收完成，status.json 已更新为 accepted"
```

若存在 FAIL 场景，记录失败原因，status.json 保持 `applied`（不更新为 accepted），
等开发者修复后重新运行 accept。

## 失败处理

- 验收是**可选步骤**，FAIL 不影响 apply 已产出的 PR
- FAIL 时记录具体失败原因到验收记录
- 修复后重新运行 `/sdlc-workflow accept <迭代目录>` 即可

## 自动查找最近 applied proposal

```bash
find_latest_applied() {
  find docs/iterations/ -name "status.json" -type f \
    | while read f; do
        phase=$(jq -r '.phase' "$f")
        if [ "$phase" = "applied" ]; then
          echo "$f"
        fi
      done \
    | sort -r \
    | head -1 \
    | xargs dirname
}

if [ -z "$ITER_DIR" ]; then
  ITER_DIR=$(find_latest_applied)
  if [ -z "$ITER_DIR" ]; then
    echo "❌ 未找到已完成 apply 的迭代目录"
    exit 1
  fi
  echo "📂 自动定位到: $ITER_DIR"
fi
```

## 输入 / 输出

| | 路径 | 说明 |
|--|------|------|
| 输入 | `docs/iterations/.../tasks.md` | 验收标准来源 |
| 输入 | `docs/iterations/.../status.json` | 确认 phase == applied |
| 输出 | `tests/reports/playwright/<slug>-<scenario>.md` | 验收记录 |
| 输出 | `tests/reports/playwright/<slug>-<scenario>.png` | 截图证据 |
| 输出 | `docs/iterations/.../status.json` | 更新 phase 为 accepted（全部 PASS 时）|

## 与自动流程的关系

```
proposal → apply → (自动流程结束，PR 已创建)
                          ↓
             /sdlc-workflow accept   ← 可选，人工触发
```

## 相关文件

- `references/apply.md` — 前置步骤（必须先完成 apply）
- `references/test-pipeline.md` — 自动化三阶段测试（Lint / Unit / E2E）
