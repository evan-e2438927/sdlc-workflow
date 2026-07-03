# 用户自定义 Skills 集成 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 SDLC pipeline 发现并优先调用用户放在项目 `.claude/skills/` 下的自定义 skill，Claude Code 与 Codex 两个运行时都生效。

**Architecture:** 三层改动——(1) `context-loader.md` 作为唯一真源，在统一加载清单里新增 `.claude/skills/` **索引项**（只扫 frontmatter 的 name+description，不加载正文）+ 一条「相关则优先调用」规则；(2) `CLAUDE.md.tpl` 面向用户新增「自定义 Skills」小节；(3) `init-project.sh` scaffold `.claude/skills/` 目录并放占位 README。

**Tech Stack:** Markdown（reference / 模板）、Bash（scaffold 脚本）。无编译、无单元测试框架——每个 task 以「改文件 → 命令校验内容」闭环。

## Global Constraints

- 只加载 skills **索引**（`name + description`），**绝不**在 context-loader 加载 skill 正文——正文调用时才加载。
- 沿用既有层级/优先级：`~/.claude/skills/`（全局）与 `<project>/.claude/skills/`（项目），项目级同名覆盖全局级；worktree 内 `<project>` 指向 worktree 根。
- 缺失（目录不存在或为空）→ 跳过，不报错。
- 不引入 registry / 配置 schema（阶段绑定靠 skill 自身 description 里点明阶段，零配置）。
- 不改各阶段 reference 文件逐一罗列 skills（沿用「执行统一上下文加载」收敛原则）。
- 设计真源：`docs/superpowers/specs/2026-07-02-user-skills-integration-design.md`。

---

### Task 1: context-loader.md 新增 skills 索引加载（唯一真源）

**Files:**
- Modify: `sdlc-workflow/references/context-loader.md`（加载清单 29-34；加载流程 51-60；缺失处理 68-74）

**Interfaces:**
- Consumes: 无（本 task 是机制真源，最先做）
- Produces: 「可用 skills 目录表」这一上下文概念 + 优先级规则，供 CLAUDE.md.tpl（Task 2）在用户契约里引用措辞。

- [ ] **Step 1: 在「加载清单」代码块追加 skills 索引行**

在 `sdlc-workflow/references/context-loader.md` 的加载清单代码块（第 33 行 `rules/*.md` 之后、第 34 行闭合 ``` 之前）加一行：

```text
<level>/skills/*/SKILL.md          # 自定义 skill 索引（仅 name+description，正文调用时才加载）
```

- [ ] **Step 2: 在「加载流程」伪代码里把 skills 索引纳入循环**

把第 54 行：

```text
    FOR f IN [CLAUDE.md, ARCHITECTURE.md, SECURITY.md, CODING_GUIDELINES.md, rules/*.md]:
      IF exists(level + f): CTX.merge(read(level + f))     # 项目级覆盖全局级
```

改为（新增 skills 索引扫描，只取 frontmatter）：

```text
    FOR f IN [CLAUDE.md, ARCHITECTURE.md, SECURITY.md, CODING_GUIDELINES.md, rules/*.md]:
      IF exists(level + f): CTX.merge(read(level + f))     # 项目级覆盖全局级
    FOR s IN glob(level + skills/*/SKILL.md):              # 仅索引，不读正文
      CTX.skills.add(frontmatter(s).name, frontmatter(s).description)  # 项目级同名覆盖全局级
```

- [ ] **Step 3: 在「加载流程」区块末尾补一条优先级规则**

在加载流程 ``` 代码块之后（第 60 行 `RETURN CTX` 所在块的闭合之后）新增一段文字：

```markdown
> **skills 优先级规则**：若 `CTX.skills` 中某 skill 的 `description` 与当前阶段任务相关，
> **优先调用它（先 skill、后自造）**；其正文在**调用时**才加载。此规则对齐 superpowers
> 的 `using-superpowers`。用户想让某 skill 只用于特定阶段，在其 `description` 里点明阶段即可，
> 无需额外配置。
```

- [ ] **Step 4: 在「缺失处理」小节补 skills 缺失分支**

在缺失处理小节（第 68-74 行）列表末尾追加一条：

```markdown
- `<level>/skills/` 不存在或为空 → 跳过，无自定义 skill，不报错
```

- [ ] **Step 5: 校验四处改动都落地**

Run:
```bash
grep -n "skills/\*/SKILL.md\|CTX.skills\|skills 优先级规则\|skills/. 不存在或为空" sdlc-workflow/references/context-loader.md
```
Expected: 至少 4 行命中（加载清单 1 行、加载流程 1-2 行含 `CTX.skills`、优先级规则标题 1 行、缺失处理 1 行）。

- [ ] **Step 6: Commit**

```bash
git add sdlc-workflow/references/context-loader.md
git commit -m "feat(context-loader): index .claude/skills/ and add skill-priority rule"
```

---

### Task 2: CLAUDE.md.tpl 新增「自定义 Skills」用户契约小节

**Files:**
- Modify: `sdlc-workflow/templates/CLAUDE.md.tpl:46-55`（在文件末尾 `## SDLC Workflow` 小节之后追加新小节）

**Interfaces:**
- Consumes: Task 1 定义的「相关则优先调用（先 skill、后自造）」措辞
- Produces: 拷进用户项目的面向用户说明，无下游代码依赖

- [ ] **Step 1: 在 CLAUDE.md.tpl 末尾追加小节**

在 `sdlc-workflow/templates/CLAUDE.md.tpl` 最后一行（第 55 行 `- 配置见 \`.claude/.sdlc-config\``）之后追加：

```markdown

## 自定义 Skills
把项目专属 skill 放到 `.claude/skills/<name>/SKILL.md`（frontmatter 需含 `name` 与 `description`）。SDLC pipeline 会自动发现它们，并在 `description` 与当前阶段相关时**优先调用**（先 skill、后自造）。
- Claude Code：harness 原生自动发现。
- Codex：由统一上下文加载入口扫描目录索引后可用。
- 想让某 skill 只在特定阶段用，在其 `description` 里点明阶段即可，无需额外配置。
```

- [ ] **Step 2: 校验小节已写入**

Run:
```bash
grep -n "## 自定义 Skills\|.claude/skills/<name>/SKILL.md\|先 skill、后自造" sdlc-workflow/templates/CLAUDE.md.tpl
```
Expected: 3 行命中。

- [ ] **Step 3: Commit**

```bash
git add sdlc-workflow/templates/CLAUDE.md.tpl
git commit -m "docs(template): add 自定义 Skills section to CLAUDE.md template"
```

---

### Task 3: init-project.sh scaffold `.claude/skills/` + 占位 README

**Files:**
- Modify: `sdlc-workflow/scripts/init-project.sh:16`（mkdir 区块新增一行）
- Modify: `sdlc-workflow/scripts/init-project.sh:87`（在末尾提示前，写入占位 README）

**Interfaces:**
- Consumes: 无
- Produces: 用户项目里 `.claude/skills/` 目录 + `.claude/skills/README.md`

- [ ] **Step 1: 在 mkdir 区块新增 skills 目录**

在 `sdlc-workflow/scripts/init-project.sh` 第 16 行 `mkdir -p "$PROJECT_ROOT/.claude/rules"` 之后新增一行：

```bash
mkdir -p "$PROJECT_ROOT/.claude/skills"
```

- [ ] **Step 2: 写入占位 README（仅当不存在）**

在第 87 行 `echo "📝 请编辑 .claude/CLAUDE.md 填写项目信息"` **之前**插入：

```bash
# 自定义 skills 目录占位说明（不覆盖已存在的）
if [ ! -f "$PROJECT_ROOT/.claude/skills/README.md" ]; then
  cat > "$PROJECT_ROOT/.claude/skills/README.md" <<'EOF'
# 自定义 Skills

把项目专属 skill 放到本目录：`.claude/skills/<name>/SKILL.md`
（frontmatter 需含 `name` 与 `description`）。

SDLC pipeline 会自动发现并在与当前阶段相关时优先调用。
详见项目根 `.claude/CLAUDE.md` 的「自定义 Skills」小节。
EOF
fi
```

- [ ] **Step 3: 语法检查脚本**

Run:
```bash
bash -n sdlc-workflow/scripts/init-project.sh && echo "syntax OK"
```
Expected: `syntax OK`

- [ ] **Step 4: 在临时目录跑一遍 scaffold 验证**

Run:
```bash
T=$(mktemp -d) && bash sdlc-workflow/scripts/init-project.sh "$T" >/dev/null 2>&1; \
ls "$T/.claude/skills/README.md" && echo "--- README 内容 ---" && cat "$T/.claude/skills/README.md"; \
rm -rf "$T"
```
Expected: 打印出 `README.md` 路径且内容含「自定义 Skills」与 `.claude/skills/<name>/SKILL.md`。

- [ ] **Step 5: Commit**

```bash
git add sdlc-workflow/scripts/init-project.sh
git commit -m "feat(init): scaffold .claude/skills/ with placeholder README"
```

---

## Self-Review

- **Spec coverage:**
  - 第 1 层（加载机制，仅索引 + 优先级 + 缺失处理）→ Task 1 ✅
  - 第 2 层（用户契约小节）→ Task 2 ✅
  - 第 3 层（scaffold 目录 + 占位 README）→ Task 3 ✅
  - A 的软替代（description 点明阶段，零配置）→ Task 1 Step 3 + Task 2 Step 1 均已写入 ✅
  - 非目标（不做 registry / 不加载正文 / 不改各阶段 reference）→ Global Constraints 已固定，无任务违反 ✅
- **Placeholder scan:** 无 TBD/TODO；每个改动步骤均给出确切文本、路径、命令与期望输出 ✅
- **Type consistency:** 跨 task 一致用语——「索引=name+description」「先 skill、后自造」「`.claude/skills/<name>/SKILL.md`」「`CTX.skills`」在 Task 1/2/3 表述统一 ✅
