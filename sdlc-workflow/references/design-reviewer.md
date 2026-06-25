# 步骤 ⑤: Design Reviewer — Gate 1 设计审查

## 输入

1. `docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/design.md`
2. `docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/tasks.md`
3. `.claude/ARCHITECTURE.md`
4. `.claude/SECURITY.md`

## 输出

PASS 或 FAIL + 问题列表

## 详细行为

### 1. Codex CLI 调用

使用 Codex CLI 非交互执行设计审查：

```bash
codex exec --full-auto "审查以下设计文档和任务分解。

对照架构规范和安全规范检查:
1) 技术方案可行性
2) 安全设计完备性
3) 架构合规性
4) 任务分解完整性（边界条件/错误处理）
5) 数据模型合理性
6) 目录落位是否符合 Better-T-Stack 风格 monorepo
7) 验收标准覆盖度:
   - requirements.md 中的每个 AC-ID 是否在 tasks.md 中被至少一个任务引用
   - tasks.md 中的 AC 是否保留了 Given-When-Then 格式和场景维度标注
   - 是否存在模糊的、不可验证的 AC 描述（如"正常工作"、"数据正确"）
   - 每个 Requirement 是否至少覆盖 happy-path 和 error 两个场景维度
8) Track 一致性:
   - 每个任务是否声明了 Track 字段（frontend / backend / shared / infra / test）
   - Track 取值是否与"目标文件"路径自洽
   - test Track 任务是否仅出现在 Phase 3
   - "任务 Track 汇总"表是否覆盖所有任务且总数与 Phase 总览一致

给出 PASS/FAIL 及具体问题列表。

=== design.md ===
$(cat docs/iterations/$DATE/$SEQ-$SLUG-$TYPE/design.md)

=== tasks.md ===
$(cat docs/iterations/$DATE/$SEQ-$SLUG-$TYPE/tasks.md)

=== ARCHITECTURE.md ===
$(cat .claude/ARCHITECTURE.md)

=== SECURITY.md ===
$(cat .claude/SECURITY.md)"
```

### 2. 审查维度

| 维度 | 检查项 | 通过标准 |
|------|--------|----------|
| 可行性 | 技术选型合理 | 无过度设计的超前技术 |
| 安全性 | 无安全漏洞 | 满足安全规范所有条目 |
| 架构合规 | 符合架构约定 | 无违反架构决策 |
| 完整性 | 边界条件处理 | 所有 API 有错误处理 |
| 数据模型 | 合理性 | 无数据冗余、关系清晰 |
| 目录结构 | workspace 落位正确 | Web 在 `apps/web`，Server 在 `apps/server`，共享逻辑在 `packages/*` |
| **AC 覆盖度** | **需求级 AC 到任务级 AC 的映射完整性** | **见下方 AC 覆盖度检查规则** |
| **Track 一致性** | **每个任务声明 Track 且与目标文件路径自洽** | **见下方 Track 一致性检查规则** |

### 2.1 AC 覆盖度检查规则（Gate 1 必做）

Gate 1 必须验证 requirements.md → tasks.md 的验收标准传递链路完整，防止 AC 在任务分解过程中退化或遗漏：

```
AC_COVERAGE_CHECK:
  1. 提取 requirements.md 中所有 AC-ID 列表 → REQ_ACS
  2. 提取 tasks.md 中所有引用的 AC-ID 列表 → TASK_ACS
  3. 计算未被覆盖的 AC:
     ORPHAN_ACS = REQ_ACS - TASK_ACS
     IF ORPHAN_ACS is not empty:
       FAIL "以下需求级验收标准未被任何任务引用: $ORPHAN_ACS"

  4. 检查每个任务的 AC 格式质量:
     FOR EACH task_ac IN TASK_ACS:
       IF task_ac 缺少场景维度标注 (happy-path/error/boundary/ui-state/security):
         WARN "任务 AC 缺少场景维度: $task_ac"
       IF task_ac 包含模糊描述 ("正常工作"|"表现正确"|"数据正确"|"功能正常"):
         FAIL "任务 AC 描述不可验证: $task_ac — 需补充具体判定条件"
       IF task_ac 缺少 Given-When-Then 结构:
         WARN "任务 AC 缺少 Given-When-Then: $task_ac"

  5. 检查场景维度覆盖（每个 Requirement 至少覆盖 happy-path + error）:
     FOR EACH req_id IN REQUIREMENT_IDS:
       DIMENSIONS = 获取 req_id 关联的所有 AC 的场景维度集合
       IF "happy-path" NOT IN DIMENSIONS:
         FAIL "R-$req_id 缺少 happy-path 验收标准"
       IF "error" NOT IN DIMENSIONS:
         WARN "R-$req_id 缺少 error 场景验收标准（建议补充）"
```

审查 prompt 中需追加以下检查指令：

```
7) 验收标准覆盖度:
   - requirements.md 中的每个 AC-ID 是否在 tasks.md 中被至少一个任务引用
   - tasks.md 中的 AC 是否保留了 Given-When-Then 格式
   - 是否存在模糊的、不可验证的 AC 描述
   - 每个 Requirement 是否至少覆盖了 happy-path 和 error 两个场景维度
```

### 2.2 Track 一致性检查规则（Gate 1 必做）

Gate 1 必须验证每个任务都声明了 Track 字段、Track 与目标文件路径自洽、且 `tasks.md` 顶部的"任务 Track 汇总"表与各任务实际 Track 一致：

```
TRACK_CONSISTENCY_CHECK:
  TRACK_PATH_RULES = {
    "frontend": ["apps/web/", "apps/native/", "packages/ui/"],
    "backend":  ["apps/server/", "packages/api/", "packages/db/"],
    "shared":   ["packages/config/", "packages/env/", "packages/auth/"],
    "infra":    ["db/migrations/", ".github/workflows/", "<root-config-files>"],
    "test":     ["tests/unit/", "tests/e2e/"]
  }

  1. 字段存在性:
     FOR EACH task IN tasks.md:
       IF "Track" NOT IN task.fields:
         FAIL "$task.id 缺少 Track 字段"
       IF task.track NOT IN ["frontend","backend","shared","infra","test"]:
         FAIL "$task.id Track 取值非法: $task.track"

  2. Track ↔ 目标文件 自洽性:
     FOR EACH task IN tasks.md:
       allowed_prefixes = TRACK_PATH_RULES[task.track]
       FOR EACH file IN task.target_files:
         IF NOT any(file.startswith(p) for p in allowed_prefixes):
           # 罕见跨 Track 情况：允许"主要修改面"判定，但需任务描述里说明
           IF "主要修改面" NOT IN task.description:
             FAIL "$task.id Track=$track 与目标文件 $file 不自洽"

  3. test Track 限制:
     FOR EACH task WITH track == "test":
       IF task.phase != "Phase 3":
         FAIL "$task.id 是 test Track，必须落在 Phase 3"

  4. Track 汇总表一致性:
     SUMMARY_TABLE = parse_track_summary(tasks.md)  # "任务 Track 汇总" 表
     ACTUAL = group_tasks_by_track(tasks.md)        # 从各任务 Track 字段聚合
     IF SUMMARY_TABLE.task_ids != ACTUAL.task_ids:
       FAIL "Track 汇总表与实际任务 Track 字段不一致: $diff"
     IF sum(SUMMARY_TABLE.counts) != total_tasks:
       FAIL "Track 汇总表任务总数 != Phase 总览任务总数"
```

审查 prompt 中需追加以下检查指令：

```
8) Track 一致性:
   - 每个任务是否声明了 Track 字段（frontend / backend / shared / infra / test）
   - Track 取值是否与"目标文件"路径自洽
   - test Track 任务是否仅出现在 Phase 3
   - "任务 Track 汇总"表是否覆盖所有任务且总数与 Phase 总览一致
```

### 3. 循环逻辑

```bash
round=1
max_rounds=${REVIEW_MAX_ROUNDS:-1}

while [ $round -le $max_rounds ]; do
  echo "🔍 设计 Review 第 $round 轮..."

  # 调用 Codex 审查
  if ! result=$(codex exec --full-auto "$PROMPT" 2> /tmp/design-review-codex.stderr); then
    echo "❌ Codex 设计审查调用失败"
    cat /tmp/design-review-codex.stderr
    echo "⚠️ 设计 Review 调用失败，已中止 Pipeline"
    exit 1
  fi

  if echo "$result" | grep -qiE "^PASS$|^\*\*结论\*\*: PASS$|^结论: PASS$"; then
    echo "✅ 设计审查通过"
    exit 0
  else
    # 提取问题列表
    issues=$(echo "$result" | grep -A 100 "问题列表" || echo "$result")

    if [ $round -lt $max_rounds ]; then
      echo "⚠️ 设计审查失败，第 $round 轮问题："
      echo "$issues"

      # Claude Code 根据反馈修订
      echo "📝 Claude Code 修订 design.md + tasks.md..."
      # ... 修订逻辑 ...

    else
      echo "❌ 设计审查超过 $max_rounds 轮，需人工介入"
      exit 1
    fi
  fi

  round=$((round + 1))
done
```

### 4. 审查报告格式

Codex 返回格式：

```
## 审查结果

**结论**: PASS | FAIL

## 问题列表

### 问题 1: [安全] Token 过期时间过长
- **严重性**: 高
- **位置**: design.md 第 5 节
- **描述**: 当前 Token 过期时间为 30 天，建议缩短到 24 小时
- **建议**: 将 expires_in 从 '30d' 改为 '24h'

### 问题 2: [完整性] 缺少错误处理
- **严重性**: 中
- **位置**: tasks.md T-003
- **描述**: 登录 API 缺少网络超时处理
- **建议**: 添加 try-catch 和超时处理

...
```

## 命令模板

```bash
#!/bin/bash
set -euo pipefail

ITER_DIR="docs/iterations/$DATE/$SEQ-$SLUG-$TYPE"
REQ_FILE="$ITER_DIR/requirements.md"
DESIGN_FILE="$ITER_DIR/design.md"
TASKS_FILE="$ITER_DIR/tasks.md"
ARCH_FILE=".claude/ARCHITECTURE.md"
SEC_FILE=".claude/SECURITY.md"

round=1
max_rounds=${REVIEW_MAX_ROUNDS:-1}

while [ $round -le $max_rounds ]; do
  echo "🔍 设计 Review 第 $round 轮..."

  PROMPT="$(cat <<EOF
审查以下设计文档和任务分解。

对照架构规范和安全规范检查:
1) 技术方案可行性
2) 安全设计完备性
3) 架构合规性
4) 任务分解完整性（边界条件/错误处理）
5) 数据模型合理性
6) 目录落位是否符合 Better-T-Stack 风格 monorepo
7) 验收标准覆盖度:
   - requirements.md 中的每个 AC-ID 是否在 tasks.md 中被至少一个任务引用
   - tasks.md 中的 AC 是否保留了 Given-When-Then 格式和场景维度标注
   - 是否存在模糊的、不可验证的 AC 描述
   - 每个 Requirement 是否至少覆盖 happy-path 和 error 两个场景维度
8) Track 一致性:
   - 每个任务是否声明了 Track 字段（frontend / backend / shared / infra / test）
   - Track 取值是否与"目标文件"路径自洽
   - test Track 任务是否仅出现在 Phase 3
   - "任务 Track 汇总"表是否覆盖所有任务且总数与 Phase 总览一致

给出 PASS/FAIL 及具体问题列表。

=== requirements.md ===
$(cat "$REQ_FILE")

=== design.md ===
$(cat "$DESIGN_FILE")

=== tasks.md ===
$(cat "$TASKS_FILE")

=== ARCHITECTURE.md ===
$(cat "$ARCH_FILE")

=== SECURITY.md ===
$(cat "$SEC_FILE")
EOF
)"
  if ! result=$(codex exec --full-auto "$PROMPT" 2> /tmp/design-review-codex.stderr); then
    echo "❌ Codex 设计审查调用失败"
    cat /tmp/design-review-codex.stderr
    exit 1
  fi

  if echo "$result" | grep -qiE "^PASS$|^\*\*结论\*\*: PASS$|^结论: PASS$"; then
    echo "✅ 设计审查通过"
    exit 0
  fi

  if [ $round -eq $max_rounds ]; then
    echo "❌ 设计审查超过 $max_rounds 轮，需人工介入"
    exit 1
  fi

  echo "⚠️ 设计审查失败，修订中..."
  # Claude 修订 design.md + tasks.md

  round=$((round + 1))
done
```

## 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| Codex CLI 调用失败 | 记录原始 stderr，立即中止 Pipeline，通知人工介入 |
| 审查超时 | 重试最多 3 次，仍失败则中止 |
| .env 未设置 | 使用默认 max_rounds=1 |
| 设计文档不存在 | 回退到步骤③ |
| 目录结构偏离默认约定 | FAIL，回退到步骤③补充目录影响声明 |

## Gate 1 通过后：增量文档同步（⑤.1）

若 Gate 1 经过 ≥1 轮修订才通过（即 design.md 或 tasks.md 被 Claude 修订过），在进入 ⑥ 开发之前，必须同步更新受影响的基线文档：

### 触发条件

```
round > 1（即 Gate 1 不是首轮直接通过）
```

### 同步范围

| 修订内容 | 同步目标 |
|----------|----------|
| 技术选型/架构决策变更 | `.claude/ARCHITECTURE.md` 对应章节 |
| 安全设计变更（认证/授权/加密方案） | `.claude/SECURITY.md` 对应章节 |
| 目录结构/模块落位调整 | `.claude/EXISTING_STRUCTURE.md`（existing project） |
| 新增编码约定 | `.claude/CODING_GUIDELINES.md` |

### 行为规则

1. **只更新被修订影响的章节**，不做全量重写
2. 以 design.md 修订前后的 diff 为依据，不凭猜测
3. 同步完成后 LOG `"📄 Gate 1 修订已同步到基线文档"`
4. 同步失败不阻塞 Pipeline（LOG warning，继续进入 ⑥）

## 相关文件

- 输入：
  - design.md
  - tasks.md
  - .claude/ARCHITECTURE.md
  - .claude/SECURITY.md
- 输出：审查结果（PASS/FAIL）+ 增量文档同步
- 参考：
  - SKILL.md Part 4（下一步：步骤⑥ Claude Code 开发）
  - references/code-reviewer.md（Gate 2）
  - references/docs-updater.md（最终文档更新）
