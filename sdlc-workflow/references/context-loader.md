# Context Loader — 统一上下文加载入口

## 目的

所有 SDLC 命令（proposal / apply / qa / accept / pr / doit / mini）在执行任何业务步骤
**之前**，必须先经过这个统一入口加载「项目规范 + 全局规范」，并确认各平台文件与 `.agents/` 一致。

**收敛原则**：规范从哪里来、按什么优先级合并，只在本文件定义一次。其他命令与 reference
文件**不再各自罗列** `.agents/AGENTS.md`、`.agents/ARCHITECTURE.md` 等清单，只需声明
「执行统一上下文加载（见 references/context-loader.md）」。

## 加载层级与优先级

按顺序加载，**后者覆盖前者**（项目级 > 全局级）：

| 层级 | 路径 |
|------|------|
| 1. 全局（旧） | `~/.claude/` |
| 2. 全局 | `~/.agents/` |
| 3. 项目 | `<project>/.agents/` |

- 全局（旧）：用户早期放在 `~/.claude/` 的通用规范，继续读取以保持兼容；入口文件名为 `CLAUDE.md`。
- 全局：跨项目、跨平台的通用规范（个人编码习惯、默认安全基线、通用 rules）；入口文件名为 `AGENTS.md`。
- 项目：当前项目专属规范，`.agents/` 是唯一事实来源；根目录 `AGENTS.md` / `CLAUDE.md` 是指向 `.agents/AGENTS.md` 的软链接。

> 合并规则：同名文件/同主题约定，后加载的层整体覆盖先加载的层；未定义的沿用前一层。
> 命令的 `--review` / `--qa` 等运行时参数优先级最高，可临时覆盖文件中的默认值。

## 加载清单

每一层都按以下清单探测并加载（文件不存在则跳过，不报错）：

```text
<level>/AGENTS.md                  # 总入口与约定索引（~/.claude/ 层为 CLAUDE.md）
<level>/ARCHITECTURE.md            # 架构与目录约定
<level>/SECURITY.md                # 安全基线
<level>/CODING_GUIDELINES.md       # 编码规范
<level>/rules/*.md                 # 细分规则（workflow-rules 等）
<level>/skills/*/SKILL.md          # 自定义 skill 索引（仅 name+description，正文调用时才加载）
```

项目自定义 skill 从 `<project>/.agents/skills/*/SKILL.md` 发现，**排除 sdlc-workflow 自己的 skill**
（固定名单：sdlc-workflow、sdlc-init、sdlc-update、sdlc-proposal、sdlc-apply、sdlc-qa、sdlc-accept、sdlc-pr、sdlc-review、sdlc-doit、sdlc-mini、sdlc-worktree）——
用 `npx skills add` 装在项目里的 sdlc 本身也位于 `.agents/skills/`，它们不是「项目自定义 skill」。

existing project 额外加载项目级基线（仅 `<project>/.agents/`）：

```text
<project>/.agents/PROJECT_BASELINE.md
<project>/.agents/EXISTING_STRUCTURE.md
<project>/.agents/TEST_BASELINE.md
```

运行时配置：`<project>/.agents/.sdlc-config`（TEST_FRAMEWORK / LINT_TOOL / GIT_BRANCH_PREFIX / HISTORY_ITER_DEPTH 等，
KEY=VALUE 格式），缺省回退到全局 `~/.agents/.sdlc-config`，再回退到 `~/.claude/.sdlc-config`，最后是内置默认。

## 加载流程

```text
load_context():
  IF <project>/.claude/CLAUDE.md 是实体文件（旧布局）:
    STOP：提示先执行 update（/sdlc-update）把项目迁移到 .agents/，不自动迁移
  IF NOT exists(<project>/.agents/AGENTS.md):
    回退执行 init（见步骤 ⓪）
  CTX = {}
  FOR level IN [ ~/.claude/ , ~/.agents/ , <project>/.agents/ ]:   # 顺序即优先级
    entry = (level == ~/.claude/) ? CLAUDE.md : AGENTS.md
    FOR f IN [entry, ARCHITECTURE.md, SECURITY.md, CODING_GUIDELINES.md, rules/*.md]:
      IF exists(level + f): CTX.merge(read(level + f))           # 后者覆盖前者
    FOR s IN glob(level + skills/*/SKILL.md):                     # 仅索引，不读正文
      IF frontmatter(s).name NOT IN sdlc 自身 skill 名单:
        CTX.skills.add(frontmatter(s).name, frontmatter(s).description)  # 同名后者覆盖
  IF project_mode == existing:
    load <project>/.agents/{PROJECT_BASELINE,EXISTING_STRUCTURE,TEST_BASELINE}.md
  load <project>/.agents/.sdlc-config  (fallback: ~/.agents/.sdlc-config → ~/.claude/.sdlc-config → 内置默认)
  sync_check()                                                    # 见下节
  RETURN CTX
```

> **skills 优先级规则**：若 `CTX.skills` 中某 skill 的 `description` 与当前阶段任务相关，
> **优先调用它（先 skill、后自造）**；其正文在**调用时**才加载。此规则对齐 superpowers
> 的 `using-superpowers`。用户想让某 skill 只用于特定阶段，在其 `description` 里点明阶段即可，
> 无需额外配置。

## 同步检查（平台文件与 .agents/ 一致）

加载完上下文后，在项目根执行（`SDLC_CORE` 见核心 SKILL.md「核心目录（SDLC_CORE）」）：

```bash
bash "$SDLC_CORE/scripts/sdlc-sync-agents.sh" --check .
```

- 退出码 0：一致，继续。
- 退出码 1：有漂移 → 立即执行 `bash "$SDLC_CORE/scripts/sdlc-sync-agents.sh" .` 自动同步，并在输出中**说明改了什么**（脚本逐项列出）。
  如果改动涉及要提交的文件（根目录 `AGENTS.md` / `CLAUDE.md`、子目录 `CLAUDE.md`、`.claude/skills/*`、`.claude/agents/*` 软链接，`.agents/hooks/*`），
  **提醒用户提交**。脚本报告的冲突（实体文件占了软链接的位置）不自动处理，原样转告用户。
- 退出码 2：出错（如缺少 jq、缺少 `.agents/config.json`）→ 转告错误并按提示处理（多数情况执行 update 即可）。

同步脚本负责：根目录与子目录的 `AGENTS.md` / `CLAUDE.md` 软链接、`.claude/skills/*` 与 `.claude/agents/*` 软链接、
`.agents/hooks/*`、由 `.agents/config.json` 生成的 `.claude/settings.json` / `.mcp.json` / `.cursor/mcp.json` /
`.codex/config.toml` / `.codex/hooks.json`，以及 `.gitignore` 中的 sdlc 托管块。用户要改 MCP 或平台设置，改 `.agents/config.json`。

项目内同步入口 `.agents/bin/sdlc-sync`（同步脚本生成并提交）供用户在终端里、重启工具之前手动同步（例如改了 MCP 配置）；参数与退出码同同步脚本，自动按 `SDLC_CORE` 环境变量 → 项目内安装 → `~/.claude/skills/` → Claude Code 插件缓存 的顺序找核心。agent 在会话里同步时仍直接调用 `bash "$SDLC_CORE/scripts/sdlc-sync-agents.sh" .`。

**插件与项目内安装并存**：项目里存在 `.agents/skills/sdlc-workflow`，而当前解析出的 `SDLC_CORE` 不在该目录下（说明正在运行插件里的 skill）时，
提示「本项目已在项目内安装 sdlc，建议在此项目停用插件，避免命令重复、版本不一致」。只提示，不阻断。

## 何时调用

- 在步骤 ⓪ 初始化之后、步骤 ① 之前，由 SKILL.md 编排统一调用**一次**
- `/compact` 之后重新进入 pipeline 时，必须重新执行一次加载（上下文已被压缩）
- worktree 内运行的命令：`<project>` 指向该 worktree 根目录，全局层不变（`worktree create` 已在新 worktree 中执行过一次同步）

## 缺失处理

- 发现旧布局（`<project>/.claude/CLAUDE.md` 是实体文件）→ 提示先执行 update 迁移，不自动迁移
- `<project>/.agents/AGENTS.md` 或 `ARCHITECTURE.md` 不存在 → 项目未初始化，回退执行 init（见步骤 ⓪）
- 全局层 `~/.agents/`、`~/.claude/` 不存在或为空 → 正常，仅使用项目级 + 内置默认
- existing project 缺少 baseline 三件套 → 回退执行 existing-project-intake（见
  references/00-existing-project-intake.md）
- `<level>/skills/` 不存在或为空 → 跳过，无自定义 skill，不报错

## 相关文件

- references/00-existing-project-intake.md — existing 项目基线生成
- 核心脚本 `sdlc-sync-agents.sh` — 由 `.agents/` 生成各平台文件（`--check` / `--check-paths`）
- 各步骤 reference 中列出的 `.agents/*` 仅表示该步骤**消费**哪些上下文，
  实际加载统一由本入口完成
