# 用户自定义 Skills 集成设计

- 日期：2026-07-02
- 状态：已批准，待实现
- 范围：让 SDLC pipeline 发现并使用用户放在项目 `.claude/skills/` 下的自定义 skill

## 背景与问题

`init-project.sh` 会在用户项目 scaffold `.claude/`（CLAUDE.md、ARCHITECTURE/SECURITY/CODING_GUIDELINES.md、rules/、.sdlc-config），但**没有 `.claude/skills/`**，pipeline 也不感知用户 skill。

关键事实：

1. **`.claude/skills/` 是 Claude Code 的原生约定目录**——放进去的 skill 由 harness 自动发现并通过 Skill 工具暴露给 agent。因此在 Claude Code 下「让 AI 知道 skill 存在」这一半基本无需自建。
2. 本项目是**双运行时**（Claude Code + Codex）。Codex 不保证自动发现 `.claude/skills/`。
3. SDLC 各阶段以**聚焦子任务**运行，即使 harness 列出了 skill，聚焦 agent 未必主动想到调用——需要一句明确引导。

真正的缺口只有两个：Codex 侧的发现，以及聚焦 agent 的调用引导。

## 方向取舍

- **A 阶段级绑定**（skill 声明绑定到 apply/qa 等阶段，pipeline 到点自动调用）：不做。需发明 registry / 配置 schema，用户需学一套映射语法，与 skill「按描述自然发现」的模型冲突，典型 YAGNI。
- **B 全程可用**（agent 感知 skill 存在，相关时自行调用）：采纳为主体。CC 下 harness 已完成一半。
- **C 仅发现 + 文档化**（约定目录被加载/列出）：采纳为补齐；单独做不够（Codex 无人列、聚焦 agent 不主动想）。

**最终方案 = B 打底 + C 补齐，以「渐进式披露」实现，不做 A。** 因两者属不同层，`context-loader.md` 与 `CLAUDE.md.tpl` **都要改**，非二选一。

## 分层设计

### 第 1 层 · 加载机制（`sdlc-workflow/references/context-loader.md`，唯一真源）

在统一加载清单中新增 `.claude/skills/`，**只加载索引，不加载 skill 正文**：

- 扫描每个 `<level>/skills/*/SKILL.md` 的 frontmatter，汇总 `name + description` 成一张「可用 skills 目录表」。
- 与既有层级/优先级一致：全局 `~/.claude/skills/` 与项目 `<project>/.claude/skills/` 都扫描，项目级同名覆盖全局级。
- worktree 内 `<project>` 指向该 worktree 根。
- 缺失（目录不存在或为空）→ 跳过，不报错。

补一条优先级规则（对齐 superpowers `using-superpowers`）：

> 若某 skill 的 `description` 与当前阶段任务相关，**优先调用它（先 skill、后自造）**；skill 正文在**调用时**才加载。

**只加载索引而非正文的理由**：skill 本为渐进式披露设计，正文调用时才需要；若每个 pipeline 步骤都把全部 skill 正文塞入上下文会爆。context-loader 作为「规范从哪来」的收敛点，在此**声明一次**「skills 也是一种上下文源」即可。该层是协议、不依赖 harness，故**对两个运行时都生效**。

### 第 2 层 · 用户契约（`sdlc-workflow/templates/CLAUDE.md.tpl`，拷进用户项目）

新增一小节（面向用户，只讲「往哪放、会怎样被用」，不含加载协议细节）：

> ## 自定义 Skills
> 把项目专属 skill 放到 `.claude/skills/<name>/SKILL.md`（frontmatter 含 `name` 与 `description`）。SDLC pipeline 会自动发现它们，并在 `description` 与当前阶段相关时**优先调用**（先 skill、后自造）。
> - Claude Code：harness 原生自动发现。
> - Codex：由统一上下文加载入口扫描目录索引后可用。
> 想让某 skill 只在特定阶段用，在其 `description` 里点明阶段即可（无需额外配置）。

### 第 3 层 · Scaffold（`sdlc-workflow/scripts/init-project.sh`）

- 新增 `mkdir -p "$PROJECT_ROOT/.claude/skills"`。
- 放一个占位说明文件（如 `.claude/skills/README.md`），内容为「把自定义 skill 放这里」的一句话指引 + 指向 CLAUDE.md 的「自定义 Skills」小节，确保目录纳入 git 且自解释。

## A 的软替代

不建 registry，但因匹配基于 `description` 相关性，任何 skill 只要在 `description` 写明「用于 xxx 阶段」即自动实现轻量版阶段绑定——零 schema、零学习成本。想要的人自然得到，不想要的人零负担。

## 影响文件

| 文件 | 改动 |
|------|------|
| `sdlc-workflow/references/context-loader.md` | 加载清单加 `.claude/skills/` 索引项 + 优先级规则 + 缺失处理 |
| `sdlc-workflow/templates/CLAUDE.md.tpl` | 新增「自定义 Skills」小节 |
| `sdlc-workflow/scripts/init-project.sh` | `mkdir .claude/skills` + 占位 README |

## 非目标（Out of Scope）

- 不实现阶段绑定 registry / 配置 schema。
- 不在 context-loader 加载 skill 正文（仅索引）。
- 不改各阶段 reference 文件逐一罗列 skills（沿用「执行统一上下文加载」的收敛原则）。

## 验证

- init 后 `.claude/skills/` 存在且含占位说明。
- 放入一个含 frontmatter 的示例 skill，进入任一 pipeline 阶段时，统一上下文加载能列出其 `name + description`。
- Codex 运行时同样能从索引感知该 skill。
