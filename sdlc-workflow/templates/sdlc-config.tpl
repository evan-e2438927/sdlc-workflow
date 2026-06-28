# ╔══════════════════════════════════════════════════════════════╗
# ║              SDLC Workflow 配置文件                            ║
# ║  位置: <project>/.claude/.sdlc-config                         ║
# ║  格式: KEY=VALUE（shell 风格，# 开头为注释）                  ║
# ║  由 /sdlc-workflow init 生成；按需编辑。无敏感信息。          ║
# ╚══════════════════════════════════════════════════════════════╝
#
# 加载规则：统一上下文加载入口读取本文件（见 references/context-loader.md）。
# 全局默认可放在 ~/.claude/.sdlc-config，项目级 <project>/.claude/.sdlc-config 覆盖之。

# ──────────────────────────────────────────────────────────────
# 测试配置
# ──────────────────────────────────────────────────────────────

# [可选] 单元测试框架   枚举: jest | vitest | mocha   默认: jest
# 用于执行 tests/unit/ 下的测试（apply 步骤 ⑨ test-pipeline）
TEST_FRAMEWORK=jest

# [可选] Lint 工具   枚举: eslint | biome   默认: eslint
# 测试执行前的静态检查（快速失败）
LINT_TOOL=eslint

# [固定] E2E 框架   固定: playwright
# qa 命令（步骤 ⑩）编写并通过 Playwright MCP 执行浏览器功能验收
E2E_FRAMEWORK=playwright

# [可选] 测试基础设施补齐策略   枚举: report | auto | never   默认: report
# - report: 缺少 lint/unit/浏览器验收能力时，在报告中列出缺口与建议命令，不交互追问
# - auto:   允许场景下自动补齐缺失的测试基础设施（更适合 fresh project）
# - never:  检测到缺口直接中止
TEST_BOOTSTRAP_POLICY=report

# ──────────────────────────────────────────────────────────────
# 审查配置
# ──────────────────────────────────────────────────────────────

# [可选] Review/Test 最大循环轮数   类型: 正整数(1-10)   默认: 1
# Gate1(设计审查)、Gate2(代码审查)、测试修复 各环节的最大重试次数
# 超过仍未通过 → 中止 Pipeline → 等待人工介入（仅 --review 时生效 Gate）
REVIEW_MAX_ROUNDS=1

# ──────────────────────────────────────────────────────────────
# Git / PR 配置（Conventional Commits）
# ──────────────────────────────────────────────────────────────

# [可选] Git 分支前缀   以 / 结尾   默认: feat/
# 传统模式分支名: ${GIT_BRANCH_PREFIX}<slug>-YYYY-MM-DD
GIT_BRANCH_PREFIX=feat/

# [可选] 默认 commit type   枚举见 Conventional Commits   默认: 从迭代 type 推断
# 留空则按迭代目录的 <type> 映射（feature→feat, fix→fix, ...）
COMMIT_TYPE=

# [可选] Conventional Commits scope   默认: 留空（自动从变更最多的目录推断）
# 示例: auth → feat(auth): ...   api → fix(api): ...
COMMIT_SCOPE=

# [可选] PR body 模板路径（相对项目根）   默认: 内置模板
# 占位符: {{requirements}} {{design}} {{test_summary}} {{file_list}}
# 示例: PR_TEMPLATE=.github/pull_request_template.md
PR_TEMPLATE=
