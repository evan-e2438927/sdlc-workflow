# 步骤 ②: Requirements Clarifier — 需求澄清（交互式选择询问）

## 输入

`docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/requirements.md`

## 输出

更新后的 `docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/requirements.md`（带置信度标注）

## 详细行为

### 1. 置信度分析

对 requirements.md 中的每条需求进行置信度评估：

```javascript
// 置信度评分标准
const confidenceCriteria = {
  HIGH: 0.8,    // ≥0.8: 高置信度，直接确认
  MEDIUM: 0.5,  // 0.5-0.8: 中置信度，假设标注
  LOW: 0.5      // <0.5: 低置信度，主会话内交互式选择询问
                //        (doit / OPENCLAW_TRIGGER_USER 等无人值守场景 fallback 为 auto-assume)
};

// 评分因素
function assessConfidence(requirement) {
  let score = 0.5; // 基础分

  // 明确的业务价值 (+0.1)
  if (requirement.businessValue) score += 0.1;

  // 具体的技术描述 (+0.1)
  if (requirement.technicalSpec) score += 0.1;

  // 明确的验收标准，含 Given-When-Then (+0.15)
  if (requirement.acceptanceCriteria?.length > 0) score += 0.15;

  // 明确的依赖关系 (+0.05)
  if (requirement.dependencies) score += 0.05;

  // 需求边界清晰（有明确的 In/Out of Scope）(+0.1)
  if (requirement.scopeBoundaries) score += 0.1;

  // 模糊的描述 (-0.2)
  if (requirement.description.includes('...')) score -= 0.2;

  // 缺少边界条件描述 (-0.1)
  if (!requirement.edgeCases) score -= 0.1;

  // 缺少非功能性需求 (-0.05)
  if (!requirement.nfrs || requirement.nfrs.length === 0) score -= 0.05;

  return Math.max(0, Math.min(1, score));
}
```

### 2. 标注处理规则

| 置信度 | 条件 | 处理方式 | 标注标记 |
|--------|------|----------|----------|
| 高 | ≥0.8 | 直接确认，不阻塞流程 | `[✅ 已确认]` |
| 中 | 0.5-0.8 | 自行假设，不阻塞流程 | `[⚠️ 假设: <具体假设内容>]` |
| 低 | <0.5 | **交互模式**：主会话内选择询问 → 用户选择写入需求；**无人值守模式**（doit / TG 触发）：fallback 为标注假设 | 交互后已确认 → `[✅ 已确认（用户选择）]`；否则 `[⚠️ 假设: <具体假设内容>]` |

> **模式判定**：`INTERACTIVE = (mode in ["proposal", "mini"]) AND (NOT OPENCLAW_TRIGGER_USER)`。
> 仅交互模式下才发起选择询问；其余情况低置信度项一律按 MEDIUM 一样自行假设并写入"假设记录"。
> 无论模式如何，流程**不阻塞**——用户跳过/取消询问也立即 fallback 为 auto-assume。

### 3. 假设管理

```javascript
// 假设记录结构
const assumptions = {
  id: "ASM-001",
  requirement: "原始需求描述",
  assumption: "所做的假设内容",
  confidence: "medium | low",
  status: "pending | confirmed | rejected",
  confirmedBy: null, // "interactive"（主会话选择询问）/ "auto-assumed"（无人值守 fallback）/ "human-review"（事后人工评审）
  confirmedAt: null
};
```

### 4. 交互式选择询问策略

> **TG 通道是单向通知**——不存在 TG 回复解析。低置信度需求**禁止依赖 TG 提问 + 用户回复**完成澄清，
> 必须改用主会话内的选择询问，让用户在同一会话里直接作答。

#### 4.1 触发条件

```
INTERACTIVE = (mode in ["proposal", "mini"]) AND (NOT OPENCLAW_TRIGGER_USER)

IF NOT INTERACTIVE:
  # doit 全自动模式 / OpenClaw TG 触发的远程运行 → 无人值守
  → 全部低置信度项按假设处理（同 MEDIUM 流程），写入"假设记录"，confirmedBy="auto-assumed"
  → 不发起任何询问，流程继续
ELSE:
  → 进入 §4.2 批量选择询问
```

#### 4.2 选择题生成规则

对每个低置信度需求项生成一道选择题：

- 由 Claude 基于需求语境**列出 2–4 个候选解释**（覆盖最常见的歧义边界）
- 每个候选解释自带"如果选这个会带来的具体行为"说明，避免选项语义模糊
- 末尾固定附 `其他（自由描述）` 选项 —— 由 AskUserQuestion 工具自动提供，无需手动加入
- 每道题应该单选；如果一个需求项内含多个独立歧义，应拆为多道题

#### 4.3 批量提问与合并

- 单次询问**最多 ≤4 道题**（AskUserQuestion 上限），多于 4 道时按需求 ID 分组分批
- 同一需求 ID 下的相关歧义优先合并为一道题，控制总题数；目标 ≤5 道，避免用户疲劳
- 一轮内问完，禁止反复来回触发新一轮询问

#### 4.4 写入解答

```
FOR each low_conf_item:
  IF user 选择了候选解释:
    → 把该解释作为"已确认的需求内容"覆盖原 description
    → 标注 [✅ 已确认（用户选择）]
    → assumption record: status="confirmed", confirmedBy="interactive", confirmedAt=now()
  ELIF user 选择了"其他（自由描述）"并填写:
    → 用自由文本作为"已确认的需求内容"覆盖原 description
    → 标注 [✅ 已确认（用户输入）]
    → assumption record: status="confirmed", confirmedBy="interactive", confirmedAt=now()
  ELSE （用户取消 / 跳过 / 工具不可用）:
    → fallback 为 auto-assume：保留 Claude 的最佳假设
    → 标注 [⚠️ 假设: <具体假设内容>]
    → assumption record: status="pending", confirmedBy="auto-assumed", confirmedAt=now()
```

#### 4.5 实现接口

通过 Claude Code 内置的 `AskUserQuestion` 工具实现，无需额外脚本或依赖：

- 每道题携带 `question` / `header` / 2–4 个 `options`（含 label + description）
- 工具自动追加"Other"选项处理自由回答场景
- 用户作答后，主会话直接拿到结构化答案并写入 requirements.md

#### 4.6 澄清完成后通知

澄清结束后通过 TG 发**状态摘要**（非提问，不要求回复）：

```
❓ 需求澄清完成
✅ 已确认（用户交互/无歧义）: <N>
⚠️ 已假设（流程继续）: <M>
📂 详见: <iter_dir>/requirements.md > 假设记录
```

### 5. 更新 requirements.md

```markdown
## 需求详情

### 需求项 1
- **描述**: <需求描述>
- **置信度**: 高
- **标注**: [✅ 已确认]

### 需求项 2
- **描述**: <需求描述>
- **置信度**: 中
- **标注**: [⚠️ 假设: <假设内容>]
- **假设理由**: <为什么做出这个假设>

### 需求项 3
- **描述**: <需求描述>
- **置信度**: 低
- **标注**: [❓ 待确认: <问题>]
- **假设**: [⚠️ 假设: <假设内容>]

## 验收标准

<!-- 对步骤①生成的验收标准进行置信度审查 -->

### AC-001: <验收标准标题>
- **关联需求**: R-001
- **Given**: <前置条件>
- **When**: <用户操作/系统触发>
- **Then**: <期望结果>
- **验证方式**: unit | e2e | playwright-mcp | manual
- **置信度**: 高 [✅ 已确认]

### AC-002: <验收标准标题>
- **关联需求**: R-002
- **Given**: <前置条件>
- **When**: <用户操作/系统触发>
- **Then**: <期望结果> [⚠️ 假设: <期望结果的假设>]
- **验证方式**: e2e
- **置信度**: 中

## 需求边界

<!-- 澄清阶段补充或修正步骤①的边界判断 -->

### 包含 (In Scope)
- <确认后的事项>

### 不包含 (Out of Scope)
- <澄清后明确排除的事项>

## 假设记录

| ID | 关联 | 假设内容 | 状态 | 确认人 | 确认时间 |
|----|------|----------|------|--------|----------|
| ASM-001 | R-001 | ... | pending | - | - |
| ASM-002 | AC-002 | ... | pending | - | - |
| ASM-003 | NFR-001 | ... | pending | - | - |
```

## 命令模板

```bash
# 1. 读取 requirements.md
REQ_FILE="docs/iterations/$DATE/$SEQ-$SLUG-$TYPE/requirements.md"

# 2. 分析置信度
CLAUDE 分析每条需求，计算置信度

# 3. 分类处理
HIGH_CONF=$(jq -r '.requirements[] | select(.confidence >= 0.8)')
MEDIUM_CONF=$(jq -r '.requirements[] | select(.confidence >= 0.5 and .confidence < 0.8)')
LOW_CONF=$(jq -r '.requirements[] | select(.confidence < 0.5)')

# 4. 低置信度需求 → 交互式选择询问 / 无人值守 fallback
INTERACTIVE_MODE = (MODE in ["proposal", "mini"]) AND (-z "$OPENCLAW_TRIGGER_USER")

if [ -n "$LOW_CONF" ]; then
  if [ "$INTERACTIVE_MODE" = "1" ]; then
    # 主会话内通过 AskUserQuestion 工具发起选择询问（≤4 题/轮，≤5 题总量）
    ASK_USER(low_conf_items)
    # 用户选择 → 写入 description / 标注 ✅；取消 → fallback 为 auto-assume
  else
    # doit 全自动 / OPENCLAW_TRIGGER_USER 远程触发 → 全部 auto-assume
    mark_all_as_auto_assumed(low_conf_items)
  fi
fi

# 5. 更新 requirements.md
# 添加置信度标注和假设记录（含 confirmedBy: interactive / auto-assumed）

# 6. TG 状态摘要（非提问、不要求回复）
notify_tg "❓ 需求澄清完成
✅ 已确认（用户交互/无歧义）: $CONFIRMED_COUNT
⚠️ 已假设（流程继续）: $ASSUMED_COUNT
📂 详见: $ITER_DIR/requirements.md > 假设记录"
```

## 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| requirements.md 不存在 | 回退到步骤①，重新执行 requirements-ingestion |
| 置信度分析失败 | 默认为中置信度，添加假设标注 |
| TG 通知发送失败 | 记录日志，继续执行（不阻塞） |
| AskUserQuestion 不可用 / 工具调用失败 | fallback 为 auto-assume，confirmedBy="auto-assumed"，不阻塞 |
| 用户跳过 / 取消选择询问 | fallback 为 auto-assume，confirmedBy="auto-assumed"，不阻塞 |
| 处于 doit / TG 触发等无人值守模式 | 不发起询问，全部 auto-assume |

## TG 通知文案

### 需求澄清完成通知（流程结束时统一发送）

```
❓ 需求澄清完成
✅ 已确认（用户交互/无歧义）: <N>
⚠️ 已假设（流程继续）: <M>
📂 详见: <iter_dir>/requirements.md > 假设记录
```

> 此通知**仅作状态同步**，不要求回复。低置信度项的澄清已经在主会话内通过
> 选择询问完成；TG 只用于事后告知，不再承载交互职能。

## 相关文件

- 输入：requirements.md（原始）
- 输出：requirements.md（标注版，含假设记录）
- 参考：references/design-generator.md（下一步）
