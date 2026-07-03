# Context Loader — 统一上下文加载入口

## 目的

所有 SDLC 命令（proposal / apply / qa / accept / pr / doit / mini）在执行任何业务步骤
**之前**，必须先经过这个统一入口加载「项目规范 + 全局规范」。

**收敛原则**：规范从哪里来、按什么优先级合并，只在本文件定义一次。其他命令与 reference
文件**不再各自罗列** `.claude/CLAUDE.md`、`.claude/ARCHITECTURE.md` 等清单，只需声明
「执行统一上下文加载（见 references/context-loader.md）」。

## 加载层级与优先级

按顺序加载，**后者覆盖前者**（项目级 > 全局级）：

| 层级 | 路径 | 含义 |
|------|------|------|
| 1. 全局级 | `~/.claude/` | 用户跨项目通用规范（个人编码习惯、默认安全基线、通用 rules） |
| 2. 项目级 | `<project>/.claude/` | 当前项目专属规范，覆盖全局同名约定 |

> 合并规则：同名文件/同主题约定，项目级整体覆盖全局级；项目级未定义的，沿用全局级。
> 命令的 `--review` / `--qa` 等运行时参数优先级最高，可临时覆盖文件中的默认值。

## 加载清单

每一层都按以下清单探测并加载（文件不存在则跳过，不报错）：

```text
<level>/CLAUDE.md                  # 项目/全局总入口与约定索引
<level>/ARCHITECTURE.md            # 架构与目录约定
<level>/SECURITY.md                # 安全基线
<level>/CODING_GUIDELINES.md       # 编码规范
<level>/rules/*.md                 # 细分规则（workflow-rules 等）
<level>/skills/*/SKILL.md          # 自定义 skill 索引（仅 name+description，正文调用时才加载）
```

existing project 额外加载项目级基线（仅 `<project>/.claude/`）：

```text
<project>/.claude/PROJECT_BASELINE.md
<project>/.claude/EXISTING_STRUCTURE.md
<project>/.claude/TEST_BASELINE.md
```

运行时配置：`<project>/.claude/.sdlc-config`（TEST_FRAMEWORK / LINT_TOOL / GIT_BRANCH_PREFIX 等，
KEY=VALUE 格式），缺省回退到全局 `~/.claude/.sdlc-config`，再回退到内置默认。
（旧的项目根 `.env` 已废弃，配置统一收敛到 `.claude/.sdlc-config`。）

## 加载流程

```text
load_context():
  CTX = {}
  FOR level IN [ ~/.claude/ , <project>/.claude/ ]:        # 顺序即优先级
    FOR f IN [CLAUDE.md, ARCHITECTURE.md, SECURITY.md, CODING_GUIDELINES.md, rules/*.md]:
      IF exists(level + f): CTX.merge(read(level + f))     # 项目级覆盖全局级
    FOR s IN glob(level + skills/*/SKILL.md):              # 仅索引，不读正文
      CTX.skills.add(frontmatter(s).name, frontmatter(s).description)  # 项目级同名覆盖全局级
  IF project_mode == existing:
    load <project>/.claude/{PROJECT_BASELINE,EXISTING_STRUCTURE,TEST_BASELINE}.md
  load <project>/.claude/.sdlc-config  (fallback: ~/.claude/.sdlc-config → 内置默认)
  RETURN CTX
```

> **skills 优先级规则**：若 `CTX.skills` 中某 skill 的 `description` 与当前阶段任务相关，
> **优先调用它（先 skill、后自造）**；其正文在**调用时**才加载。此规则对齐 superpowers
> 的 `using-superpowers`。用户想让某 skill 只用于特定阶段，在其 `description` 里点明阶段即可，
> 无需额外配置。

## 何时调用

- 在步骤 ⓪ 初始化之后、步骤 ① 之前，由 SKILL.md 编排统一调用**一次**
- `/compact` 之后重新进入 pipeline 时，必须重新执行一次加载（上下文已被压缩）
- worktree 内运行的命令：`<project>` 指向该 worktree 根目录，全局级仍为 `~/.claude/`

## 缺失处理

- `<project>/.claude/CLAUDE.md` 或 `ARCHITECTURE.md` 不存在 → 项目未初始化，回退执行
  `/sdlc-workflow:init`（见步骤 ⓪）
- 全局级 `~/.claude/` 不存在或为空 → 正常，仅使用项目级 + 内置默认
- existing project 缺少 baseline 三件套 → 回退执行 existing-project-intake（见
  references/00-existing-project-intake.md）
- `<level>/skills/` 不存在或为空 → 跳过，无自定义 skill，不报错

## 相关文件

- references/00-existing-project-intake.md — existing 项目基线生成
- 各步骤 reference 中列出的 `.claude/*` 仅表示该步骤**消费**哪些上下文，
  实际加载统一由本入口完成
