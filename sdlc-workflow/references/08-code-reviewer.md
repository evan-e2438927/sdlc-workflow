# 步骤 ⑧: Code Reviewer — Gate 2 代码审查

## 输入

1. `git diff`（代码变更）
2. `.claude/CODING_GUIDELINES.md`
3. `.claude/SECURITY.md`
4. 当前 iteration 的 `tasks.md`

## 输出

PASS 或 FAIL + 问题列表

## 详细行为

### 1. Codex CLI 调用

使用 Codex CLI 非交互执行代码审查：

```bash
codex exec --full-auto "审查以下代码变更。

检查:
1) 代码质量与可读性
2) 安全漏洞 (OWASP Top 10)
3) 架构合规性
4) 编码规范符合度
5) 错误处理完备性
6) 文件是否落在正确 workspace
7) 已完成任务是否在 tasks.md 中同步勾选

给出 PASS/FAIL 及具体问题列表。

=== git diff ===
$(git diff --no-color)

=== CODING_GUIDELINES.md ===
$(cat .claude/CODING_GUIDELINES.md)

=== SECURITY.md ===
$(cat .claude/SECURITY.md)"
```

### 2. 审查维度

| 维度 | 检查项 | 通过标准 |
|------|--------|----------|
| 代码质量 | 命名、注释、结构 | 符合 CODING_GUIDELINES |
| 安全漏洞 | OWASP Top 10 | 无安全漏洞 |
| 架构合规 | 模块职责、依赖关系 | 无架构违规 |
| 编码规范 | 格式化、导入顺序 | 符合项目规范 |
| 错误处理 | 异常捕获、日志记录 | 关键路径有错误处理 |
| 目录结构 | 文件放置位置 | Web 在 `apps/web`，Server 在 `apps/server`，共享逻辑在 `packages/*` |
| 任务状态 | tasks.md 勾选与事实一致 | 已完成任务与验收标准已同步回写 |

### 3. OWASP Top 10 检查清单

```
A01: Broken Access Control
  - [ ] 接口权限检查
  - [ ] 越权访问防护
  - [ ] 敏感数据暴露

A02: Cryptographic Failures
  - [ ] 敏感数据加密
  - [ ] 密钥管理
  - [ ] 密码 hashing

A03: Injection
  - [ ] SQL 注入防护
  - [ ] XSS 防护
  - [ ] 命令注入防护

A04: Insecure Design
  - [ ] 业务逻辑安全
  - [ ] 错误信息泄露

A05: Security Misconfiguration
  - [ ] 默认配置检查
  - [ ] 安全 headers

A06: Vulnerable Components
  - [ ] 依赖版本检查
  - [ ] 已知漏洞组件

A07: Auth Failures
  - [ ] 会话管理
  - [ ] 认证绕过

A08: Data Integrity Failures
  - [ ] 数据验证
  - [ ] 文件上传安全

A09: Logging Failures
  - [ ] 安全事件日志
  - [ ] 审计跟踪

A10: SSRF
  - [ ] URL 验证
  - [ ] 资源访问限制
```

### 4. 循环逻辑

```bash
round=1
max_rounds=${REVIEW_MAX_ROUNDS:-1}
ITER_DIR="docs/iterations/$DATE/$SEQ-$SLUG-$TYPE"
TASKS_FILE="$ITER_DIR/tasks.md"

while [ $round -le $max_rounds ]; do
  echo "🔍 Code Review 第 $round 轮..."

  # 获取代码变更
  DIFF=$(git diff --no-color)

  PROMPT="$(cat <<EOF
审查以下代码变更。

检查:
1) 代码质量与可读性
2) 安全漏洞 (OWASP Top 10)
3) 架构合规性
4) 编码规范符合度
5) 错误处理完备性
6) 文件是否落在正确 workspace
7) 测试是否错误写入源码目录
8) 已完成任务是否在 tasks.md 中同步勾选

给出 PASS/FAIL 及具体问题列表。

=== git diff ===
$DIFF

=== tasks.md ===
$(cat "$TASKS_FILE")
EOF
)"
  if ! result=$(codex exec --full-auto "$PROMPT" 2> /tmp/code-review-codex.stderr); then
    echo "❌ Codex 代码审查调用失败"
    cat /tmp/code-review-codex.stderr
    echo "⚠️ Code Review 调用失败，已中止 Pipeline"
    exit 1
  fi

  if echo "$result" | grep -qiE "^PASS$|^\*\*结论\*\*: PASS$|^结论: PASS$"; then
    echo "✅ Code Review 通过"
    exit 0
  else
    # 提取问题列表
    issues=$(echo "$result" | grep -A 100 "问题列表" || echo "$result")

    if [ $round -lt $max_rounds ]; then
      echo "⚠️ Code Review 失败，第 $round 轮问题："
      echo "$issues"

      # Claude Code 根据反馈修复代码
      echo "📝 Claude Code 修复代码..."
      # ... 修复逻辑 ...

      # 重新生成 diff
      DIFF=$(git diff --no-color)

    else
      echo "❌ Code Review 超过 $max_rounds 轮，需人工介入"
      exit 1
    fi
  fi

  round=$((round + 1))
done
```

### 5. 审查报告格式

Codex 返回格式：

```
## 审查结果

**结论**: PASS | FAIL

## 问题列表

### 问题 1: [安全] SQL 注入风险
- **严重性**: 高
- **位置**: apps/server/src/db/user-repository.ts:42
- **描述**: 用户输入直接拼接到 SQL 查询
- **代码**: query("SELECT * FROM users WHERE id = " + userId)
- **建议**: 使用参数化查询

### 问题 2: [质量] 缺少错误处理
- **严重性**: 中
- **位置**: apps/server/src/services/auth-service.ts:78
- **描述**: login 函数未捕获数据库连接异常
- **建议**: 添加 try-catch

...
```

## 命令模板

```bash
#!/bin/bash
set -euo pipefail

round=1
max_rounds=${REVIEW_MAX_ROUNDS:-1}

while [ $round -le $max_rounds ]; do
  echo "🔍 Code Review 第 $round 轮..."

  DIFF=$(git diff --no-color)

  PROMPT="$(cat <<EOF
审查以下代码变更。

检查:
1) 代码质量与可读性
2) 安全漏洞 (OWASP Top 10)
3) 架构合规性
4) 编码规范符合度
5) 错误处理完备性
6) 文件是否落在正确 workspace

给出 PASS/FAIL 及具体问题列表。

=== git diff ===
$DIFF

=== CODING_GUIDELINES.md ===
$(cat .claude/CODING_GUIDELINES.md)

=== SECURITY.md ===
$(cat .claude/SECURITY.md)
EOF
)"

  if ! result=$(codex exec --full-auto "$PROMPT" 2> /tmp/code-review-codex.stderr); then
    echo "❌ Codex 代码审查调用失败"
    cat /tmp/code-review-codex.stderr
    exit 1
  fi

  if echo "$result" | grep -qiE "^PASS$|^\*\*结论\*\*: PASS$|^结论: PASS$"; then
    echo "✅ Code Review 通过"
    exit 0
  fi

  if [ $round -eq $max_rounds ]; then
    echo "❌ Code Review 超过 $max_rounds 轮，需人工介入"
    exit 1
  fi

  echo "⚠️ Code Review 失败，修复中..."
  # Claude Code 修复代码

  round=$((round + 1))
done
```

## 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| Codex CLI 调用失败 | 记录原始 stderr，立即中止 Pipeline，通知人工介入 |
| git diff 为空 | 警告：无可审查代码 |
| 审查超时 | 重试最多 3 次，仍失败则中止 |
| 严重安全漏洞 | 高优先级通知，立即修复 |
| 文件落位违反 monorepo 约定 | FAIL，要求回退修复目录结构 |

## 相关文件

- 输入：
  - git diff
  - .claude/CODING_GUIDELINES.md
  - .claude/SECURITY.md
- 输出：审查结果（PASS/FAIL）
- 参考：
  - references/09-test-pipeline.md（下一步：测试执行）
  - references/05-design-reviewer.md（Gate 1）
