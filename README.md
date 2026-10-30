# Enterprise SDLC Workflow — an AI-driven, automated software delivery pipeline

<p align="center"><b>English</b> · <a href="./README.zh-CN.md">简体中文</a></p>

<p align="center">
  <strong>🏭 Claude Code writes · Codex CLI reviews · browser automation verifies · every step traceable and resumable</strong>
</p>

<p align="center">
  <a href="./DESIGN-PROMO.md#design-philosophy">💡 Design philosophy</a> ·
  <a href="./examples/30-second-demo.md">⚡ Tutorial &amp; 30-second demo (Chinese)</a> ·
  <a href="./sdlc-workflow/SKILL.md">🔧 Core spec</a>
</p>

---

> **How to read these docs**
> - 🏃 **Want to use it now** → [Install](#install) → [Your first full run](#your-first-full-run)
> - 🤔 **Evaluating whether to adopt** → [Why you need it](#why-you-need-it) → [Compared with other approaches](#compared-with-other-approaches)
> - 🧠 **Want the design rationale** → [DESIGN-PROMO.md · design philosophy](./DESIGN-PROMO.md) ｜ [workflow-overview.md · mechanics (Chinese)](./docs/workflow-overview.md)
>
> **Doc map (three docs, no overlap)**: this **README** = front door + install + command reference; **[DESIGN-PROMO](./DESIGN-PROMO.md)** = why it is designed this way (deep rationale, good for evangelism); **[workflow-overview](./docs/workflow-overview.md)** = the 2-model / 4-stage / command mechanics in full (good for training; currently Chinese only).

---

## What is this?

A **Skill plugin** for [Claude Code](https://claude.ai/code) and [Codex](https://github.com/openai/codex) (one shared skill set across both runtimes, single entry point) that splits software delivery into five reviewable, resumable, artifact-producing stages, so the AI advances by an engineering **contract** rather than prompt tricks:

```
Main line: proposal → apply → qa → accept → pr
           break down  build  verify  finalize  ship
```

| Stage | Command | What it does | Output phase |
|-------|---------|--------------|--------------|
| Break down | `proposal` | requirement → clarify → design → tasks (split by track) → [Gate 1] → **pause for human review** | pending_review |
| Build | `apply` | implement frontend/backend/unit-test → unit tests → [Gate 2] → lint+unit | applied |
| Browser QA | `qa` | turn the qa track into Playwright scripts and run them via Playwright MCP | qa_passed / qa_failed |
| Finalize | `accept` | summarize changes → update docs → **local commit** (no push) | accepted |
| Ship | `pr` | `git push` → `gh pr create` (the only step that touches the remote) | pr_created |

Plus a few auxiliary lines:
- `init`: initialize / onboard a project, generating a baseline that locks the structure
- `doit`: chain all five stages fully automatically (`--qa` includes browser QA), straight to a PR
- `mini`: lightweight flow for tiny changes, but Gates and QA are not skipped
- `worktree`: isolate multiple parallel pipelines via git worktree
- `review`: run Codex Gate 1 / Gate 2 standalone

**Highlights**:
- 🤖 **AI-driven**: full automation from requirement to PR, every step producing artifacts, evidence, and recoverable state
- 🎯 **Stage separation**: build (apply), browser QA (qa), local finalize (accept), and remote ship (pr) are independent — clear boundaries, each re-runnable on its own
- 🧍 **Human review gate**: pause after proposal so the design is human-confirmed before coding, so the AI never decides everything alone
- 🔒 **Dual-model gating**: Claude Code generates, Codex CLI reviews independently (enabled by `--review`; never downgraded, never silently skipped)
- 🧪 **Evidence-chain acceptance**: qa runs real browser verification with Playwright scripts + Playwright MCP and produces a report; success screenshots are stored under `tests/reports/` (gitignored, kept out of the main branch) and embedded into the PR body by `pr` via an isolated `pr-assets` branch — not "trust me, I tested it"
- 🧭 **Unified context loading**: the source of conventions (global `~/.agents/` + project `.agents/`, project overrides global; the legacy `~/.claude/` is still read) is defined exactly once, converged at a single entry
- 🧩 **Custom skills discovery**: a project's `.agents/skills/<name>/SKILL.md` is discovered by unified context loading, and the pipeline prefers it at relevant stages (skill first, hand-rolled second); works across both Claude Code and Codex
- 🔗 **One source for every tool**: rules, MCP servers, project skills and hooks live in `.agents/`; `AGENTS.md`, `CLAUDE.md` and the Claude Code / Codex / Cursor config are generated from it
- 📦 **Config convergence**: project config lives in one place, `.agents/.sdlc-config`, with no scattered root-level `.env`
- 🔧 **Resumable**: each requirement produces a structured iteration directory; `status.json` records the phase, so the next session can continue after an interruption
- 🛡️ **Safe for existing projects**: existing projects run an intake to generate a baseline first, preventing the AI from rebuilding your directory structure
- 🌲 **Worktree parallelism**: multiple requirements / agents run at once, with auto-allocated ports and isolated branches and config

---

## Why you need it

You are already coding with Claude Code / Cursor / Codex, but you have probably hit:

| Pain point | How you handle it today | With this system |
|------------|-------------------------|------------------|
| Existing project rebuilt as if new when handed to AI | Repeatedly explain "don't touch the current architecture" | Intake before building; baseline locks the structure |
| Model changes the directory layout on its own | Fix it up afterward | Directory constraints injected as rules, checked by a Gate |
| Code written before anyone reviews the design | Only discover the wrong direction after it's written | proposal pauses for human review; apply only starts after |
| "It's done" when nothing was actually tested | Manually verify one by one | qa requires real browser-interaction evidence and a report |
| Review depends on you reading the diff | Skip it when there's too much | Codex CLI reviews automatically; the Gate stops on failure |
| commit / PR done in one shot, hard to roll back | Only option is reset | accept commits locally only; pr pushes and ships after you confirm |
| Config scattered, secrets included | `.env` everywhere | Unified `.agents/.sdlc-config`, gitignored |
| Parallel requirements stuck in serial | Queue up; even a hotfix waits | worktree: isolated work tree + branch + ports |

**In one sentence**: an SDLC system that constrains AI behavior with an **engineering contract** instead of prompt tricks.

---

## Compared with other approaches

| | Bare Claude Code | Cursor Rules | SDLC Workflow |
|--|------------------|--------------|---------------|
| Directory constraints | ❌ via prompt | ⚠️ configurable rules, not enforced | ✅ injected into the workflow, enforced at runtime |
| Design review | ❌ | ❌ | ✅ Codex CLI Gate 1 |
| Human review gate | ❌ | ❌ | ✅ proposal pauses → human → apply |
| Code review | ❌ | ❌ | ✅ Codex CLI Gate 2 |
| Browser QA | ⚠️ narrated | ⚠️ narrated | ✅ qa: Playwright + MCP evidence |
| Commit / ship separation | ❌ one shot | ❌ | ✅ accept local commit / pr remote ship |
| Resumable iterations | ❌ relies on chat history | ❌ | ✅ iteration dir + status.json |
| Safe onboarding of existing projects | ❌ often rebuilt | ⚠️ hit or miss | ✅ intake → baseline → constraints |
| Parallel-dev isolation | ❌ single-repo serial | ❌ | ✅ git worktree + port isolation |

---

## Install

> Works with **Claude Code** and **Codex** (and other tools that read `AGENTS.md`). Needs `git`, `bash`, [jq](https://jqlang.org/) and Node.js (for `npx`).

### npx skills, project-level (recommended)

Installs sdlc into the project itself, so the whole team uses one pinned version — in Claude Code and Codex alike:

```bash
cd your-project
npx skills add evan-e2438927/sdlc-workflow --skill '*' -a claude-code -a codex -y
```

It creates (commit all of it):

- `.agents/skills/<name>/` — the 12 skills as real files
- `.claude/skills/<name>` → `../../.agents/skills/<name>` symlinks — Claude Code only discovers skills under `.claude/skills/`
- `skills-lock.json` — the pinned versions

Then run `/sdlc-init` in Claude Code (in Codex, say "run sdlc init") and commit what it generates. Teammates who clone the repo see the rules and the `/sdlc-*` commands right away; the gitignored platform files are regenerated the first time anyone runs an sdlc command or `.agents/bin/sdlc-sync`.

### npx skills, global (personal)

Available in every project on your machine, nothing added to a repo:

```bash
npx skills add evan-e2438927/sdlc-workflow -g --skill '*' -a claude-code -a codex -y
```

A global install does not register the multi-agent role sub-agents (`sdlc-backend-dev` / `sdlc-frontend-dev` / `sdlc-test-dev`); for `apply --agents multi`, use the project-level install or the plugin.

### Claude Code plugin (personal)

```bash
/plugin marketplace add evan-e2438927/sdlc-workflow
/plugin install sdlc-full@sdlc-workflow
```

> Use one install per project. If a project has the npx install, disable the plugin there — otherwise the commands show up twice and the versions can differ (sdlc warns when it sees both).

After installing you can use the `sdlc-*` skills: `sdlc-init` / `sdlc-update` / `sdlc-proposal` / `sdlc-apply` / `sdlc-qa` / `sdlc-accept` / `sdlc-pr` / `sdlc-doit` / `sdlc-mini` / `sdlc-review` / `sdlc-worktree`.

> **Single entry point**: Claude Code and Codex **share one skill set** — there is no separate slash-command set. Trigger by stating intent (e.g. "run sdlc proposal: …") or, in Claude Code, `/sdlc-proposal`. `sdlc-workflow` is the overview/orchestration skill; each stage skill is a thin entry pointing at the same `references/`, single source of truth.

### Updating

- **npx, project-level**: `npx skills update -p -y` (or re-run the install command), then `/sdlc-update`; commit the result
- **npx, global**: `npx skills update -g -y`, then `/sdlc-update` in each project
- **Claude Code plugin**: `/plugin update sdlc-full@sdlc-workflow`, then `/sdlc-update` in each project

### Dependencies

| Tool | Purpose | Install |
|------|---------|---------|
| [Claude Code](https://claude.ai/code) / [Codex](https://github.com/openai/codex) | AI development agent | via official sites |
| [jq](https://jqlang.org/) | required by the sync and status scripts | `brew install jq` |
| [Node.js](https://nodejs.org/) | `npx skills` install, Playwright MCP | via official site |
| [Codex CLI](https://github.com/openai/codex) | Independent Gate 1/2 review (`--review`) | `npm i -g @openai/codex` |
| [GitHub CLI](https://cli.github.com/) | `pr` command creates the PR | `brew install gh` |
| [Playwright MCP](https://github.com/microsoft/playwright-mcp) | `qa` browser QA | preconfigured in `.agents/config.json`, generated for Claude Code / Codex / Cursor |
| [GitHub MCP](https://github.com/github/github-mcp-server) (optional) | PR enhancements | add it to `mcpServers` in `.agents/config.json`, then run `.agents/bin/sdlc-sync` |

> Gates are optional (enabled with `--review`); but once enabled, an unavailable Codex CLI aborts the run rather than being silently skipped.

---

## Quick start

```bash
# 1. Initialize / onboard a project (optional args: review=1 branch=feat/ test-framework=jest)
sdlc-init "review=1"

# 2. Break down the requirement (recommended flow; pauses for human review at the end)
sdlc-proposal Add a user login module supporting email and phone registration

# 3. Review the proposal artifacts → after confirming, build (build + unit tests + lint, no commit)
sdlc-apply

# 4. Browser QA (Playwright scripts + MCP execution)
sdlc-qa

# 5. QA passed → update docs + local commit
sdlc-accept

# 6. Local commit looks good → push and create the PR
sdlc-pr

# —— or all in one shot ——
sdlc-doit --qa Add a user login module      # fully automatic, includes browser QA, straight to a PR
sdlc-mini Change the button color to blue    # lightweight flow for tiny changes
```

**Recommended flow**: `proposal → human review → apply → qa → accept → pr`, ensuring the design is human-confirmed, the change is browser-verified, and you can review the commit locally before shipping.

---

## Your first full run

> Recommended for training: don't use `doit` one-shot the first time — step through it manually to feel each step's **artifacts** and **checkpoints**. Example: "add an export button to the orders page."

| Step | Command | What you'll see / do | Where artifacts land |
|------|---------|----------------------|----------------------|
| 0 | `sdlc-init` | Detects fresh / existing; existing runs a baseline intake first (**don't skip** — this prevents the AI from treating your existing directory as a new project) | `.agents/`, `.agents/.sdlc-config` |
| 1 | `sdlc-proposal add an export button to the orders page` | Generates requirements / design / tasks, then **auto-pauses** for your review | `docs/iterations/<date>/<seq>-<slug>-feature/` |
| ⏸ | 👀 **Human review** | Open `design.md` and `tasks.md` to check the plan; ask it to revise if unhappy, continue when satisfied | — (one of the two mandatory stops) |
| 2 | `sdlc-apply` | Implements code + unit tests + lint per tasks, **no commit** | code changes + `tests/unit/` |
| 3 | `sdlc-qa` | Generates Playwright scripts, runs them in a real browser, saves success screenshots locally | `tests/reports/<slug>-e2e-report.md` + screenshots (gitignored) |
| 4 | `sdlc-accept` | Updates docs + **local commit** (still no push); review with `git diff` first | one local commit |
| 5 | `sdlc-pr` | `git push` + create the PR; QA screenshots are embedded into the PR body via the isolated `pr-assets` branch | remote branch + PR URL |

**Only two places require you to stop**: the "human review" after step 1, and the "local diff review" after step 4; everything else is automatic. Once comfortable, one command does it all: `sdlc-doit --qa add an export button to the orders page`.

**Three common beginner pitfalls**:
- **Existing projects must let init run the baseline intake first**, otherwise the AI may rebuild your structure per default directory conventions.
- **`--review` needs Codex CLI installed locally**; if it isn't, leave it off and run local lint / unit only (the Gate aborts honestly rather than silently skipping).
- **qa needs Playwright MCP mounted**; if it isn't, qa reports the missing dependency rather than pretending to pass.

---

## Skills at a glance (single entry point)

Each stage is a skill, shared by Claude Code and Codex; trigger by stating intent or, in Claude Code, `/<skill>`.

| Skill | Args | Use case | phase |
|-------|------|----------|-------|
| `sdlc-init` | `[key=value …]` | onboard a project, generate config and baseline | — |
| `sdlc-update` | `[project dir]` | two-phase upgrade sync: phase 1 safely syncs the scaffold (idempotent, never overwrites user content); phase 2 drift-aware incremental refresh (baselines auto-refresh, user docs confirmed item by item) | — |
| `sdlc-proposal` | `<requirement> [--review]` | break down the requirement (①-④) → wait for human review | pending_review |
| `sdlc-apply` | `[--review] [--agents single\|multi] [iter dir]` | build + unit tests + lint (⑥-⑨, no commit) | applied |
| `sdlc-qa` | `[iter dir]` | Playwright browser QA (⑩); code defects → `qa_failed`, fixed by the next `apply` | qa_passed / qa_failed |
| `sdlc-accept` | `[iter dir]` | summarize changes → update docs → local commit (⑪⑫) | accepted |
| `sdlc-pr` | `[iter dir]` | push → create PR (⑬, the only remote action) | pr_created |
| `sdlc-doit` | `[--review] [--qa] [--agents single\|multi] <requirement>` | fully automatic, straight to a PR (①-⑬) | — |
| `sdlc-mini` | `[--review] [--qa] <tiny task>` | lightweight flow for tiny tasks | — |
| `sdlc-review` | `<proposal\|code> <iter dir>` | run Codex Gate 1 / Gate 2 standalone | — |
| `sdlc-worktree` | `create <slug> <type> \| list \| status \| remove <seq\|slug> \| gc` | parallel requirements / multiple agents | — |

### Argument notes

- Notation: `< >` required, `[ ]` optional, `|` one of.
- `--review`: enable the Codex review gates (proposal's Gate 1 design review + apply's Gate 2 code review); without it, Gates are skipped and only local lint/unit run.
- `--qa`: insert Playwright browser QA (step ⑩) into the doit / mini flow.
- `iter dir`: of the form `docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/`; **auto-located when omitted**, picking the most recent iteration matching the phase.
- `<requirement>` / `<tiny task>` input formats: plain text, `file:///local-path`, or a URL (body auto-extracted via Playwright MCP).
- `sdlc-init` `key=value` config (all optional): `review=<n>` (REVIEW_MAX_ROUNDS), `branch=<prefix>` (GIT_BRANCH_PREFIX), `test-framework=<jest|vitest|mocha>`, `lint=<eslint|biome>`.
- `sdlc-worktree` `<type>`: `feature | fix | refactor | docs | test | chore`.

**Why accept and pr are separate**: accept finalizes the change **locally** (update docs + commit) so you can review the local diff; once confirmed, `pr` pushes and ships. Decoupling local finalize from remote ship makes rollback easy.

**mini is not "skip the flow"**: browser QA is not trimmed and Gates are not skipped; it auto-upgrades to doit when it touches > 3 files or changes an API / data model.

**worktree is not "a separate flow"**: it only isolates the work tree and branch; the pipeline still runs proposal/apply/qa/accept/pr.

---

## Pipeline diagram

```mermaid
graph TD
    START["/sdlc-workflow"] --> CMD{command?}
    CMD -->|proposal| P1["①-④ break down [+Gate 1]"]
    P1 --> P_STOP["⏸ pause (pending_review)"]
    P_STOP -->|human review| APPLY

    CMD -->|apply| APPLY["⑥-⑨ build → unit → lint [+Gate 2]"]
    APPLY --> A_END["applied"]
    A_END --> QA

    CMD -->|qa| QA["⑩ Playwright browser QA"]
    QA --> Q_END["qa_passed"]
    QA -->|code defect| Q_FAIL["qa_failed"]
    Q_FAIL -->|apply repair mode| A_END
    Q_END --> ACCEPT

    CMD -->|accept| ACCEPT["⑪⑫ summarize → docs → local commit"]
    ACCEPT --> AC_END["accepted"]
    AC_END --> PR

    CMD -->|pr| PR["⑬ push → gh pr create"]
    PR --> END["✅ pr_created + PR"]

    CMD -->|doit| DOIT["①-⑬ fully automatic (no stops)"]
    DOIT --> END

    CMD -->|mini| MINI["mini lightweight flow"]
    MINI --> END
```

Each iteration's state is recorded in `docs/iterations/.../status.json`, so the next session can resume from it after an interruption. Phase changes go through an internal script that only allows legal transitions and appends to `history`; you never edit the phase by hand:

```json
{
  "phase": "pending_review | approved | applied | qa_failed | qa_passed | accepted | pr_created | rejected",
  "mode": "proposal | doit | mini",
  "flags": { "review": true, "qa": true, "agents": "auto" },
  "proposal_at": "2026-04-13T14:00:00+08:00",
  "reviewed_at": "2026-04-13T15:00:00+08:00",
  "pr_url": null,
  "iter_dir": "docs/iterations/2026-04-13/001-user-login-feature",
  "history": [{ "at": "2026-04-13T14:00:00+08:00", "from": null, "to": "pending_review", "by": "proposal" }]
}
```

- **Changing a proposal under review**: while it is `pending_review`, just tell the agent what to change in the conversation. It edits requirements / design / tasks together in place and pauses again.
- **QA finds a code defect**: qa writes `qa-failures.md` and moves to `qa_failed`; the next `apply` enters repair mode automatically (fix the listed defects, add regression unit tests where possible, run lint + unit), returns to `applied`, then you re-run qa.
- **Abandoning an iteration**: say so in the conversation and it is marked `rejected` (your working-tree code is not rolled back).
- **Interrupted doit / mini**: ask the agent to continue; it resumes with the original `--review` / `--qa` flags all the way to the PR.

---

## Unified context loading

Before running, every command loads conventions through a **single entry**, and the convention list is defined exactly once in [`references/context-loader.md`](sdlc-workflow/references/context-loader.md):

```
Load order (later overrides earlier):
  1. Global (legacy)  ~/.claude/           ← older cross-project conventions, still read
  2. Global           ~/.agents/           ← cross-project, cross-tool conventions
  3. Project          <project>/.agents/   ← project-specific conventions, override global
```

Each level loads `AGENTS.md` (`CLAUDE.md` in `~/.claude/`) / `ARCHITECTURE.md` / `SECURITY.md` / `CODING_GUIDELINES.md` / `rules/*.md`; existing projects additionally load the baseline trio; runtime config is read from `.agents/.sdlc-config`. Project skills are discovered in `.agents/skills/` (sdlc's own skills excluded). After loading, every command runs `sdlc-sync-agents.sh --check` and re-syncs automatically when generated files drifted, telling you what changed and what to commit.

---

## Single- / multi-agent mode

The build phase of apply (and doit) runs in one of two modes. The flow and the output are the same; only who does the work differs:

| Mode | How it runs | Good for |
|------|-------------|----------|
| `single` | the main agent plays backend → frontend → test in turn | Codex, one-sided changes, small requirements |
| `multi` | backend / frontend sub-agents build in parallel, then a test sub-agent audits coverage | requirements with both frontend and backend work (Claude Code) |

- Default `AGENT_MODE=auto`: `multi` when both frontend and backend have tasks and the runtime can spawn sub-agents, otherwise `single`; `mini` is always `single`.
- One-off override: `sdlc-apply --agents single|multi <iter dir>`.
- Frontend and backend work in parallel against the interface contract produced during proposal (a structured table in design.md; shared types in `packages/contracts` for TS monorepos; an existing OpenAPI file is reused).
- Only the main agent edits shared files (`package.json`, lockfiles, root config, the contract file). Each role edits only its own paths and writes a `tracks/<track>.md` report; the main agent checks for out-of-bounds edits when merging.
- Multi mode also has an **out-of-bounds guard** (a PreToolUse hook, `EDIT_GUARD=on`): at ⑥.0 the main agent writes an allow list per role, and a role sub-agent's write to any file outside it is refused before it happens and turned into a blocked report for the main agent.

See [flow-apply.md](sdlc-workflow/references/flow-apply.md) and [roles/](sdlc-workflow/references/roles/) (Chinese).

---

## Parallel development (Worktree mode)

Uses `git worktree` to keep multiple work trees for one repo at once, each running an independent pipeline.

```bash
# Create a parallel work tree (auto-allocates seq, branch, ports, copies .agents/.sdlc-config*)
sdlc-worktree create user-login feature
sdlc-worktree create payment-bug fix

# Enter the work tree and run the normal pipeline
cd ../wt-001-user-login-feature
sdlc-proposal "user login feature"

# Global overview / list / cleanup
sdlc-worktree status
sdlc-worktree list
sdlc-worktree remove 001
sdlc-worktree gc
```

| Resource | Isolation |
|----------|-----------|
| Work dir | `../wt-<seq>-<slug>-<type>/`, a sibling of the main repo |
| Branch | `{GIT_BRANCH_PREFIX}{slug}-{date}-wt{seq}`, git-enforced exclusive |
| Dev server ports | `PORT=3000+seq, API_PORT=4000+seq`, written to that worktree's `.agents/.sdlc-config` |
| Config | copied from the main repo's `.agents/.sdlc-config*` (gitignored, not carried over by git worktree) |
| Registry | `.worktrees/worktree-registry.json` (committed to main, serving as the multi-agent coordination bus) |

See [parallel-dev.md](sdlc-workflow/references/parallel-dev.md); the script is [sdlc-worktree.sh](sdlc-workflow/scripts/sdlc-worktree.sh).

---

## Directory structure

The repo itself is a **multi-runtime plugin**: Claude Code and Codex share one `skills/` set, with the single source of logic in `sdlc-workflow/references/`.

```
sdlc-workflow/ (repo root)
├── skills/                 # single entry: one skill per stage (shared by both runtimes)
│   ├── sdlc-workflow/      # → symlink to ../sdlc-workflow (overview/orchestration skill)
│   ├── sdlc-init/  sdlc-proposal/  sdlc-apply/  sdlc-qa/  sdlc-accept/
│   ├── sdlc-pr/  sdlc-doit/  sdlc-mini/  sdlc-review/  sdlc-update/  sdlc-worktree/
│   └──   each contains a SKILL.md (thin entry, pointing at references/)
├── .claude-plugin/         # Claude Code manifest (marketplace.json + plugin.json, auto-discovers skills/)
├── .codex-plugin/          # Codex manifest (plugin.json, skills: ./skills/)
├── agents/                 # → symlinks into sdlc-workflow/agents/ (Claude Code plugin)
├── tests/                  # repo tests: bash tests/run-all.sh
└── sdlc-workflow/          # core skill content (referenced by skills/sdlc-workflow)
```

```
sdlc-workflow/              # core skill
├── SKILL.md                # main-flow spec (orchestrator)
├── references/             # per-step detailed specs (workers)
│   ├── pipeline-overview.md
│   ├── context-loader.md     # unified context-loading entry
│   ├── flow-proposal.md      # requirement breakdown flow
│   ├── flow-apply.md         # build flow
│   ├── flow-qa.md            # browser QA flow
│   ├── flow-accept.md        # acceptance flow (docs + local commit)
│   ├── flow-mini.md          # lightweight tiny-task flow
│   ├── parallel-dev.md       # worktree parallel development
│   ├── 00-existing-project-intake.md
│   ├── 01-requirements-ingestion.md
│   ├── 02-requirements-clarifier.md
│   ├── 03-design-generator.md
│   ├── 04-task-generator.md
│   ├── 05-design-reviewer.md   # Gate 1
│   ├── 07-test-generator.md    # unit test generation
│   ├── 08-code-reviewer.md     # Gate 2
│   ├── 09-test-pipeline.md     # lint + unit
│   ├── 10-docs-updater.md
│   ├── 11-git-committer.md     # local commit + Conventional Commits spec
│   ├── 12-pr-creator.md        # push + PR
│   └── micro-change-mode.md
├── agents/                 # role sub-agents (sdlc-backend/frontend/test-dev), shipped with npx installs
├── scripts/                # init / update / sync / status / parallel-dev scripts
│   ├── init-project.sh
│   ├── update-project.sh         # sync latest scaffold, migrate the legacy .claude/ layout
│   ├── sdlc-sync-agents.sh       # generate platform files from .agents/ (--check / --check-paths)
│   ├── sdlc-migrate-lib.sh       # import existing platform configs (used by init / update)
│   ├── sdlc-status.sh            # phase state machine
│   ├── sdlc-worktree.sh
│   └── update-workflow-config.sh
└── templates/              # project templates
    ├── AGENTS.md.tpl          # → .agents/AGENTS.md
    ├── config.json.tpl        # → .agents/config.json
    ├── hooks/                 # → .agents/hooks/ (sdlc-managed)
    ├── workflow-rules.md.tpl
    ├── sdlc-config.tpl        # → generates .agents/.sdlc-config
    ├── ARCHITECTURE.md.tpl
    ├── SECURITY.md.tpl
    └── CODING_GUIDELINES.md.tpl
```

### Target project structure (generated after init)

`.agents/` is the single source of truth; platform directories only hold what differs per tool, and are generated or symlinked by `sdlc-sync-agents.sh`.

```
your-project/
├── AGENTS.md -> .agents/AGENTS.md      # committed symlink (Codex, Cursor, Gemini CLI … read AGENTS.md)
├── CLAUDE.md -> .agents/AGENTS.md      # committed symlink (Claude Code)
├── skills-lock.json                    # npx skills install only, committed
├── .agents/                            # committed
│   ├── AGENTS.md                       # project entry
│   ├── ARCHITECTURE.md / SECURITY.md / CODING_GUIDELINES.md
│   ├── PROJECT_BASELINE.md / EXISTING_STRUCTURE.md / TEST_BASELINE.md   # existing project
│   ├── rules/workflow-rules.md
│   ├── config.json                     # MCP servers + platform settings (single source)
│   ├── hooks/                          # sdlc-managed hook scripts (do not edit)
│   ├── bin/sdlc-sync                   # sync entry point for the terminal (sdlc-managed)
│   ├── skills/                         # sdlc itself (npx install) + your project skills
│   ├── .sdlc-config                    # runtime config (gitignored, per person)
│   └── .sdlc-active-iteration          # gitignored
├── .claude/
│   ├── skills/<name> -> ../../.agents/skills/<name>   # committed symlinks
│   ├── agents/sdlc-*-dev.md -> ../../.agents/skills/sdlc-workflow/agents/…   # npx install only, committed
│   └── settings.json                   # generated, gitignored
├── .codex/config.toml, .codex/hooks.json   # generated, gitignored
├── .mcp.json, .cursor/mcp.json         # generated, gitignored
├── web/AGENTS.md + web/CLAUDE.md -> AGENTS.md   # optional subdirectory rules, both committed
├── docs/iterations/YYYY-MM-DD/<seq>-<slug>-<type>/
│   ├── requirements.md / design.md / tasks.md
│   └── status.json             # phase: pending_review → approved → applied → qa_passed（or qa_failed → applied）→ accepted → pr_created
├── tests/ (unit/, e2e/, reports/)
└── .worktrees/                 # worktree registry (created once parallelism is enabled)
```

### What to commit, what is generated

Rule: **whatever must exist right after a clone, before any command runs, is committed; whatever can be regenerated from `.agents/` is ignored.**

| Committed | Generated and gitignored |
|-----------|--------------------------|
| `AGENTS.md`, `CLAUDE.md` and subdirectory `CLAUDE.md` symlinks | `.claude/settings.json` (from `config.claude.settings` + sdlc hooks) |
| `.agents/` (rules, `config.json`, `hooks/`, `bin/`, `skills/`) | `.mcp.json`, `.cursor/mcp.json`, `.codex/config.toml`, `.codex/hooks.json` |
| `.claude/skills/*`, `.claude/agents/*` symlinks, `skills-lock.json` | `.agents/.sdlc-config*`, `.agents/.sdlc-active-iteration`, `.agents/.backup/` |

The ignore entries live between `# >>> sdlc generated >>>` and `# <<< sdlc generated <<<` in `.gitignore`; that block is rewritten on every sync, so put your own rules outside it. To change MCP servers or tool settings, edit `.agents/config.json` — generated files are rewritten whole. `sdlc-init`, `sdlc-update` and `sdlc-worktree create` run the sync; every other command runs `--check` first and re-syncs if needed. **Syncing by hand**: after editing `.agents/config.json` (for example adding an MCP server), run this in a terminal before restarting your IDE / tools — the same command in every project, whatever the stack or install method:

```bash
.agents/bin/sdlc-sync            # regenerate platform files
.agents/bin/sdlc-sync --check    # only report drift
```

It finds the sdlc core on its own (the `SDLC_CORE` env var, then the in-project npx install, `~/.claude/skills/`, then the Claude Code plugin cache) and always syncs the project it lives in, wherever you run it from.

A real file sitting where a symlink belongs (for example your own `web/CLAUDE.md`) is never overwritten; `--check` reports it as a conflict.

**Windows**: Git may check symlinks out as plain text files. Enable Developer Mode and run `git config core.symlinks true` before cloning (or re-checkout afterwards). The sync check spots a symlink that became a text file and tells you so.

**Codex hooks**: Codex runs project hooks only after you trust them — open `/hooks` in Codex once and trust this project's `.codex/hooks.json`. Codex gets the post-edit lint check; the multi-agent out-of-bounds guard is Claude Code only, because Codex hook input carries no sub-agent identity.

### Migrating from the `.claude/` layout

Projects initialized by an older version keep their rules in `.claude/CLAUDE.md`, `.claude/ARCHITECTURE.md` and friends. Run `sdlc-update`: it backs the old files up to `.agents/.backup/<timestamp>/`, moves them (and custom skills under `.claude/skills/`) into `.agents/`, rewrites the `.claude/…` paths inside them, folds a real root `AGENTS.md` / `CLAUDE.md` into `.agents/AGENTS.md` under a "迁移自 …" heading for you to tidy up, imports `.claude/settings.json`, `.mcp.json`, `.cursor/mcp.json` and `.codex/config.toml` into `.agents/config.json`, then regenerates everything. If those platform files were committed, run `git rm --cached <file>` as the migration report says. Other commands stop on the old layout and ask you to run `sdlc-update` first.

---

## Configuration

Runtime settings live in `.agents/.sdlc-config` (`KEY=VALUE` format, generated by `sdlc-init` and gitignored). Global defaults can go in `~/.agents/.sdlc-config` (the legacy `~/.claude/.sdlc-config` is still read), with project-level overriding global. MCP servers and per-tool settings live in `.agents/config.json` (see "What to commit, what is generated"):

| Key | Default | Description |
|-----|---------|-------------|
| `TEST_FRAMEWORK` | `jest` | unit test framework (jest/vitest/mocha) |
| `LINT_TOOL` | `eslint` | lint tool (eslint/biome) |
| `E2E_FRAMEWORK` | `playwright` | browser QA framework (qa command) |
| `TEST_BOOTSTRAP_POLICY` | `report` | how to handle missing test infra (report/auto/never) |
| `REVIEW_MAX_ROUNDS` | `1` | max auto-fix rounds after a failure (`0` = no auto-fix). Applies to Gate 1/2 (only with `--review`), lint + unit, qa script fixes, and doit `--qa` defect loops |
| `AGENT_MODE` | `auto` | apply execution mode (auto/single/multi); the `--agents` flag overrides it |
| `EDIT_GUARD` | `on` | multi-mode out-of-bounds guard: blocks a role sub-agent from writing files outside its allow list |
| `GIT_BRANCH_PREFIX` | `feat/` | git branch prefix |
| `COMMIT_TYPE` | (empty) | Conventional Commits type; empty infers from iteration type |
| `COMMIT_SCOPE` | (empty) | Conventional Commits scope; empty auto-infers |
| `PR_TEMPLATE` | (empty) | path to a custom PR body template |

Commits follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/); the authoritative definition is in [11-git-committer.md](sdlc-workflow/references/11-git-committer.md).

---

## FAQ

**Q: Can I use it without Codex CLI?**
> Yes. Gates are optional (enabled only with `--review`). But once enabled, an unavailable Codex aborts rather than skips.

**Q: Why are accept and pr separate?**
> accept finalizes locally only (update docs + commit) so you can review the local diff; after confirming, use pr to push and ship. Decoupling local from remote makes rollback easy.

**Q: Does it support projects other than TypeScript?**
> Yes. Set `TEST_FRAMEWORK` and `LINT_TOOL`; the flow itself is language-agnostic.

**Q: How do I choose between proposal / doit / mini?**
> Need to review the design → proposal + apply (+ qa + accept + pr). Fully trust the AI → doit. CSS / copy / small UI tweak → mini.

**Q: What if the session is interrupted?**
> The next session reads `docs/iterations/` and the `status.json` phase to resume; all intermediate artifacts are persisted.

**Q: What if global and project conventions conflict?**
> Project-level `.agents/` overrides global `~/.agents/` (and the legacy `~/.claude/`); runtime command flags (`--review`/`--qa`) have the highest priority.

**Q: What if I need to develop multiple requirements in parallel?**
> Use `worktree create` to open an isolated work tree per requirement; branches, ports, and `.agents/.sdlc-config` are isolated automatically, sessions don't interfere, and `worktree gc` cleans up after merge.

---

## Real-world engineering cases
- https://github.com/evan-e2438927/btc-trade/pulls
- [Dream Cinema — ERC20](https://movie.coinbasis.org/) ｜ source: https://github.com/evan-e2438927/dream-castle-cinema

---

## License

[MIT](./sdlc-workflow/LICENSE)
