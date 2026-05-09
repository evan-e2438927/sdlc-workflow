# 通知规范: TG Notifier — Telegram 通知

## 概述

所有 Pipeline 通知统一通过 OpenClaw CLI 发送 Telegram 消息。

## 前置条件

用户需提前配置好 OpenClaw 并获取 Telegram 用户 ID：

```bash
# 1. 安装 OpenClaw CLI
npm install -g openclaw

# 2. 登录
openclaw auth login

# 3. 绑定 Telegram
openclaw channel connect telegram

# 4. 获取你的 Telegram 用户 ID（数字）
openclaw channel info telegram
# → 记下输出的数字 ID，填入 .env 的 TG_USERNAME 字段
```

## 发送命令

```bash
# TG_USERNAME 为 Telegram 账号数字 ID 或 chat_id
openclaw message send --channel telegram --target "$TG_USERNAME" --message "$MSG"
```

## 通知规则

| 规则 | 说明 |
|------|------|
| 失败不中断 | 发送失败只记录日志，不影响 Pipeline |
| 消息前缀 | 所有消息带 `[项目名]` 前缀以区分来源 |
| 敏感信息 | 禁止在通知中包含密钥/Token/密码 |
| 长度限制 | 每条消息 ≤ 4096 字符（Telegram 限制），超长截断 |

## 通知列表

### 1. 初始化完成

**fresh project：**
```
🚀 项目初始化完成（fresh project）
📂 .claude/CLAUDE.md ✅
📂 .claude/rules/workflow-rules.md ✅
📂 docs/ 基础文档 ✅
⚙️ .env 配置已就绪
```

**existing project：**
```
🚀 项目初始化完成（existing project）
📄 PROJECT_BASELINE.md ✅
📄 EXISTING_STRUCTURE.md ✅
📄 TEST_BASELINE.md ✅
🔒 结构保护规则已生效
```

### 2. 需求收录

```
📥 需求已收录: <需求摘要前50字>
📂 迭代目录: docs/iterations/<date>/<seq>-<slug>-<type>/
```

### 3. 需求澄清完成（状态摘要，非提问）

```
❓ 需求澄清完成
✅ 已确认（用户交互/无歧义）: <N>
⚠️ 已假设（流程继续）: <M>
📂 详见: <iter_dir>/requirements.md > 假设记录
```

> **TG 通道仅做单向通知，不承载交互提问**。低置信度需求的澄清已在主会话内通过
> AskUserQuestion 选择询问完成（见 `references/requirements-clarifier.md`）。
> 此处仅在澄清结束后发一条状态摘要，不要求用户回复。

### 4. 设计文档生成

```
🎨 设计文档已生成: docs/iterations/<date>/<seq>-<slug>-<type>/design.md
📋 包含: 技术方案、API 设计、数据模型、安全考量
```

### 5. 任务分解完成

```
📋 任务分解完成: <任务总数> 个任务
⏱ 预估工时: <总工时>
📂 详见: docs/iterations/<date>/<seq>-<slug>-<type>/tasks.md
```

### 6. 设计 Review 结果（Gate 1）

**通过：**
```
🔍 设计 Review: PASS ✅
📋 <通过轮数> 轮审查通过
📂 设计文档已确认
```

**失败（循环中）：**
```
🔍 设计 Review 第 {N} 轮: <问题摘要前100字>
📝 Claude 正在修订，请稍候...
```

**超限：**
```
⚠️ 设计 Review 超过 {N} 轮，需人工介入
📂 保留所有产物待人工修复
💡 修复后可从步骤③手动恢复
```

### 7. 开始实现

```
🔨 开始实现: <需求摘要前50字>
📋 任务数: <总任务数>
```

### 8. 实现完成

```
🔨 实现完成: <已完成任务数>/<总任务数>
📄 变更文件: <N> files
```

### 9. 测试用例生成

```
🧪 测试用例已生成:
📂 tests/unit/web|server|packages/...
📂 tests/e2e/<slug>/E2E-<nnn>-<scenario>.e2e.ts
📋 详见: tests/reports/<slug>-coverage.md
```

### 10. Code Review 结果（Gate 2）

**通过：**
```
🔍 Code Review: PASS ✅
📋 <通过轮数> 轮审查通过
🛡️ 代码安全检查通过
```

**失败（循环中）：**
```
🔍 Code Review 第 {N} 轮: <问题摘要前100字>
📝 Claude 正在修复，请稍候...
```

**超限：**
```
⚠️ Code Review 超过 {N} 轮，需人工介入
🛡️ 主要问题: <问题摘要>
📂 保留当前代码待人工修复
```

### 11. 测试完成

**全部通过：**
```
🧪 测试结果: 全部通过 ✅
📊 Lint: ✅ | Unit: <x>/<y> | E2E: <x>/<y>
📋 报告: tests/reports/<slug>-<timestamp>.md
```

**部分失败：**
```
🧪 测试结果: 部分失败
📋 失败用例: <列表>
📝 Claude 正在修复，请稍候...
```

**超限：**
```
⚠️ 测试修复超过 {N} 轮，需人工介入
📋 失败测试: <列表>
```

### 12. 文档更新完成

```
📝 文档已更新:
📄 README.md
📄 .claude/ARCHITECTURE.md
📄 .claude/SECURITY.md
📄 .claude/CODING_GUIDELINES.md
📄 .claude/CLAUDE.md (iterations 引用已更新)
```

### 13. 迭代完成（最终通知）

```
✅ 迭代完成!

🔗 PR: <PR URL>
🌿 分支: <branch-name>
📝 提交: <commit-message>
📊 变更: <N> files
🧪 测试: <结果>
📂 迭代目录: docs/iterations/<date>/<seq>-<slug>-<type>/
```

## 实现示例

### Bash 函数

```bash
#!/bin/bash

notify_tg() {
  local message="$1"
  local project_name="${PROJECT_NAME:-sdlc-workflow}"

  # 添加项目名前缀
  local prefixed_msg="[$project_name] $message"

  # 发送到 Telegram
  openclaw message send \
    --channel telegram \
    --target "$TG_USERNAME" \
    --message "$prefixed_msg" \
    2>/dev/null || {
      echo "⚠️ TG 通知发送失败: $prefixed_msg" >&2
      return 0  # 不中断 Pipeline
    }
}

# 使用示例
notify_tg "📥 需求已收录: 用户登录功能"
```

### 长消息截断

```bash
notify_tg() {
  local message="$1"
  local max_len=4096

  if [ ${#message} -gt $max_len ]; then
    message="${message:0:$((max_len - 20))}...（详见本地日志）"
  fi

  openclaw message send --channel telegram --target "$TG_USERNAME" --message "$message"
}
```

### 错误日志

```bash
log_notification() {
  local level="$1"  # INFO, WARN, ERROR
  local message="$2"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  echo "[$timestamp] [$level] $message" >> logs/notifications.log
}

# 使用
log_notification "INFO" "需求收录通知已发送: $SLUG"
log_notification "ERROR" "TG 通知发送失败: $MESSAGE"
```

## 安全注意事项

1. **禁止包含的信息**：
   - API 密钥/Token
   - 数据库密码
   - 用户敏感信息
   - 内部系统地址

2. **允许包含的信息**：
   - PR 链接（公开）
   - 文件路径（不含敏感信息）
   - 测试结果摘要
   - 功能描述

## 相关文件

- 参考：SKILL.md Part 4（Pipeline 编排中的通知调用）
