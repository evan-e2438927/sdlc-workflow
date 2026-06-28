# 步骤 ①: Requirements Ingestion — 需求采集与路由

## 输入

`/sdlc-workflow` 的参数，接受三种格式：

| 格式 | 示例 | 处理方式 |
|------|------|----------|
| 纯文本 | `创建一个用户登录模块` | 直接作为需求内容 |
| file:// 路径 | `file:///path/to/requirements.txt` | 读取本地文件 |
| URL | `https://jira.company.com/browse/PROJ-123` | Playwright MCP 提取 |

## 输出

`docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/requirements.md`

## 详细行为

### 1. 输入类型判断

```bash
INPUT="$1"

if [[ "$INPUT" == file://* ]]; then
  # 读取本地文件
  CONTENT=$(cat "${INPUT#file://}")
  TYPE="local_file"
elif [[ "$INPUT" == http://* ]] || [[ "$INPUT" == https://* ]]; then
  # URL 提取
  TYPE="url"
  # 使用 Playwright MCP 打开 URL 并提取内容
  # 详见 Playwright MCP 文档
else
  # 纯文本
  CONTENT="$INPUT"
  TYPE="text"
fi
```

### 2. Slug 生成规则

从需求内容生成稳定、可读、语言无关的 slug：

- 优先让 Claude 根据需求摘要生成一个英文 kebab-case slug
- 最长 30 个字符
- 若需求主要是中文或其他非 ASCII 内容，导致清洗后为空，则回退到 `req-<hash8>`
- slug 只负责稳定标识，不要求和原文逐字对应

```bash
SLUG_CANDIDATE="$(echo "$CONTENT" | \
  tr '[:upper:]' '[:lower:]' | \
  sed 's/[^a-z0-9 ]//g' | \
  tr -s ' ' '-' | \
  cut -c1-30 | \
  sed 's/^-*//; s/-*$//')"

if [ -n "$SLUG_CANDIDATE" ]; then
  SLUG="$SLUG_CANDIDATE"
else
  HASH="$(printf '%s' "$CONTENT" | shasum | cut -c1-8)"
  SLUG="req-$HASH"
fi
```

### 3. 变更类型推断

根据需求内容关键词推断变更类型：

| 类型 | 关键词 | 说明 |
|------|--------|------|
| feature | add, new, create, implement, 功能, 新增 | 新功能 |
| fix | fix, bug, patch, 修复, 解决 | Bug 修复 |
| refactor | refactor, optimize, improve, 重构, 优化 | 重构优化 |
| docs | docs, documentation, 文档 | 文档更新 |
| test | test, testing, 测试 | 测试相关 |
| chore | chore, setup, config, 配置, 部署 | 维护任务 |

```bash
TYPE="feature"  # 默认值
if echo "$CONTENT" | grep -qiE "(fix|bug|patch|修复|解决)"; then
  TYPE="fix"
elif echo "$CONTENT" | grep -qiE "(refactor|optimize|improve|重构|优化)"; then
  TYPE="refactor"
elif echo "$CONTENT" | grep -qiE "(docs?|文档)"; then
  TYPE="docs"
elif echo "$CONTENT" | grep -qiE "(test|测试)"; then
  TYPE="test"
elif echo "$CONTENT" | grep -qiE "(chore|setup|config|配置|部署)"; then
  TYPE="chore"
fi
```

### 4. 顺序号生成

同一天内的 iteration 目录必须带递增序号，保证执行顺序可追踪且按字典序可排序：

```bash
DATE=$(date +%Y-%m-%d)
DATE_DIR="docs/iterations/$DATE"
mkdir -p "$DATE_DIR"

LAST_SEQ=$(find "$DATE_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | \
  sed -n 's/^\([0-9][0-9][0-9]\)-.*/\1/p' | sort | tail -n1)

if [ -n "$LAST_SEQ" ]; then
  SEQ=$(printf "%03d" $((10#$LAST_SEQ + 1)))
else
  SEQ="001"
fi
```

### 5. 目录创建

```bash
ITER_DIR="docs/iterations/$DATE/${SEQ}-${SLUG}-${TYPE}/"
mkdir -p "$ITER_DIR"
```

### 6. 需求文档写入

创建 `requirements.md`，包含：

```markdown
# 需求文档

## 基本信息

- **采集时间**: YYYY-MM-DD HH:mm:ss
- **迭代序号**: <seq>
- **输入类型**: text | file | url
- **变更类型**: feature | fix | refactor | docs | test | chore
- **Slug**: <slug>
- **业务优先级**: P0(紧急) | P1(高) | P2(中) | P3(低)
- **技术风险**: 高 | 中 | 低

## 原始需求

<需求内容原文>

## 需求摘要

<50字内的需求摘要>

## 需求详情

<结构化需求详情>

为需求详情中的每条核心能力分配 Requirement ID：

- R-001: <核心能力 1>
- R-002: <核心能力 2>
- R-003: <核心能力 3>

## 验收标准

每条核心需求必须有可验证的验收标准，使用 Given-When-Then 格式。
验收标准 ID 必须关联 Requirement ID，形成 R-ID → AC-ID 追溯链。

**⚠️ 验收标准生成规则**：每个 Requirement 必须按以下 5 个维度系统化枚举验收场景，不得只写 happy path：

| 维度 | 说明 | 必须/可选 |
|------|------|-----------|
| Happy Path | 正常操作路径，用户期望的成功结果 | **必须** |
| Error / Failure | 输入无效、权限不足、依赖不可用时的错误处理 | **必须** |
| Boundary / Edge | 边界值、空值、极端长度、并发、溢出等 | **必须** |
| UI State（前端）| 加载中、空状态、错误提示、禁用态、skeleton 等 UI 状态切换 | 涉及前端时**必须** |
| Security | XSS/注入防护、权限越权、敏感数据脱敏等 | 涉及用户输入或权限时**必须** |

每条 AC 必须包含具体的**期望值**或**可量化判定条件**，禁止模糊描述如"正常工作"、"表现正确"。

### AC-001: <验收标准标题>（Happy Path）
- **关联需求**: R-001
- **场景维度**: happy-path
- **Given**: <具体的前置条件和数据状态>
- **When**: <用户的具体操作步骤或系统触发条件>
- **Then**: <可观测、可验证的期望结果，含具体值>
- **验证方式**: unit | e2e | playwright-mcp | manual

### AC-002: <验收标准标题>（Error）
- **关联需求**: R-001
- **场景维度**: error
- **Given**: <导致错误的前置条件>
- **When**: <触发错误的操作>
- **Then**: <期望的错误提示文案、HTTP 状态码、UI 错误状态>
- **验证方式**: unit | e2e | playwright-mcp

### AC-003: <验收标准标题>（Boundary）
- **关联需求**: R-001
- **场景维度**: boundary
- **Given**: <边界条件描述，如空输入/最大长度/并发>
- **When**: <触发边界条件的操作>
- **Then**: <边界情况下的期望行为，含具体约束值>
- **验证方式**: unit | e2e

### AC-004: <验收标准标题>（UI State）
- **关联需求**: R-001
- **场景维度**: ui-state
- **Given**: <导致特定 UI 状态的条件，如网络延迟/空数据/首次加载>
- **When**: <用户操作或页面加载>
- **Then**: <期望的 UI 状态：loading spinner / empty placeholder / 错误卡片 / disabled 按钮等>
- **验证方式**: playwright-mcp

## 非功能性需求

<!-- 根据需求内容推断，无明确要求的项标注 "N/A" -->

| ID | 类别 | 描述 | 验收指标 |
|----|------|------|----------|
| NFR-001 | 性能 | <描述> | <可量化指标，如 LCP ≤ 2s> |
| NFR-002 | 安全 | <描述> | <如 XSS 防护、输入校验> |
| NFR-003 | 兼容性 | <描述> | <如 Chrome 90+, Safari 15+> |
| NFR-004 | 可访问性 | <描述> | <如 WCAG AA> |

## 需求边界

### 包含 (In Scope)
- <本次迭代明确要做的事项>

### 不包含 (Out of Scope)
- <明确排除的事项，防止 scope creep>

### 未来考虑 (Future Considerations)
- <可能的后续迭代方向>

## 用户故事

<!-- 可选：复杂需求时填写，简单 fix/chore 可省略 -->

### US-001: <故事标题>
- **角色**: 作为<某类用户>
- **目标**: 我想要<某个功能>
- **价值**: 以便<获得某种价值>
- **关联需求**: R-001, R-002

## UI/UX 约束

<!-- 可选：涉及 UI 变更时填写，纯后端/配置类需求可省略 -->
- **设计稿**: <链接或截图路径，如无则标注"无">
- **交互规范**: <关键交互说明>
- **响应式要求**: mobile-first | desktop-first | 自适应
- **动画/过渡**: <性能预算，如无特殊要求则标注"默认">

## 变更影响评估

- **Breaking Changes**: 是 | 否
  <!-- 如有，描述影响范围和迁移方案 -->
- **数据库变更**: 是 | 否
  <!-- 如有，描述 migration 计划 -->
- **API 变更**: 是 | 否
  <!-- 如有，描述向后兼容性 -->
- **配置变更**: 是 | 否
  <!-- 如有，列出新增/修改的环境变量或配置项 -->

## 外部依赖

<!-- 如有外部文档/JIRA 链接，在此标注 -->
- 来源: <URL 或 文件路径>
- 内容摘要: <提取的关键信息>

## 假设标注

<!-- 在澄清环节（步骤②）填充 -->
```

### 7. 外部文档拉取

检测需求中是否指定了外部文档来源：

```bash
# 检测 URL/文件引用
if echo "$CONTENT" | grep -qE "(https?://|file://)"; then
  # 提取并拉取外部文档
  # 更新 .claude/ARCHITECTURE.md / SECURITY.md / CODING_GUIDELINES.md
fi
```

### 8. 完成输出

```bash
echo "✅ 需求已收录: $(echo "$CONTENT" | head -c 50)..."
```

## 命令模板

```bash
# 1. 判断输入类型
case "$INPUT_TYPE" in
  text)
    CONTENT="$INPUT"
    ;;
  file)
    CONTENT=$(cat "${INPUT#file://}")
    ;;
  url)
    # 使用 Playwright MCP 打开页面并提取正文摘要
    # 不要调用不存在的 mcp__chrome_devtools__extract
    CONTENT="<从页面可见正文提取的结构化摘要>"
    ;;
esac

# 2. 生成 slug 和 type
SLUG=$(generate_slug "$CONTENT")
TYPE=$(infer_type "$CONTENT")

# 3. 创建目录
DATE=$(date +%Y-%m-%d)
DATE_DIR="docs/iterations/$DATE"
mkdir -p "$DATE_DIR"
LAST_SEQ=$(find "$DATE_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | \
  sed -n 's/^\([0-9][0-9][0-9]\)-.*/\1/p' | sort | tail -n1)
if [ -n "$LAST_SEQ" ]; then
  SEQ=$(printf "%03d" $((10#$LAST_SEQ + 1)))
else
  SEQ="001"
fi
ITER_DIR="$DATE_DIR/${SEQ}-${SLUG}-${TYPE}/"
mkdir -p "$ITER_DIR"

# 4. 写入 requirements.md
cat > "$ITER_DIR/requirements.md" << 'EOF'
...
EOF

echo "✅ 需求已收录: $(echo "$CONTENT" | head -c 50)..."
```

## 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| 文件不存在 (file://) | 记录日志，提示用户检查路径 |
| URL 无法访问 | 记录日志，保留 URL 引用待人工处理 |
| Playwright MCP 失败 | 降级为手动复制粘贴，提示用户 |
| 目录创建失败 | 中止 Pipeline，提示权限问题 |
## 相关文件

- 输入：用户提供的需求（文本/文件/URL）
- 输出：docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/requirements.md
- 参考：references/02-requirements-clarifier.md（下一步）
