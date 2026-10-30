#!/bin/bash
# skill 文档与模板改用 .agents/ 布局；context-loader 定义加载层级、skill 排除、同步检查；文档只在迁移说明里提 .claude/CLAUDE.md。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$HERE/.." && pwd)"; SKILL_DIR="$REPO_DIR/sdlc-workflow"
R="$SKILL_DIR/references"
fail=0
has()   { grep -qF -- "$2" "$1" 2>/dev/null || { echo "FAIL: ${1#"$REPO_DIR"/} 缺少: $2"; fail=1; }; }

# D1：skill 文档 / 模板中的 .claude/ 只允许：全局 ~/.claude/、Claude 平台目录（skills / agents / settings）、
#     以及旧布局说明行中的 .claude/CLAUDE.md 等（行内含「旧布局」或「迁移」）
SCOPE="$SKILL_DIR/SKILL.md $R $SKILL_DIR/templates $(ls "$REPO_DIR"/skills/sdlc-*/SKILL.md | grep -v '/skills/sdlc-workflow/')"
# shellcheck disable=SC2086
bad="$(grep -rn '\.claude/' $SCOPE \
  | sed -E 's#~/\.claude/##g; s#\.claude/(skills|agents|plugins|settings\.json|settings\.local\.json)##g' \
  | grep '\.claude/' | grep -vE '旧布局|迁移|legacy')"
[ -z "$bad" ] || { echo "FAIL D1 仍有旧 .claude/ 项目路径："; echo "$bad" | sed "s#$REPO_DIR/#    #" | head -20; fail=1; }

# D2：context-loader
C="$R/context-loader.md"
has "$C" '| 1. 全局（旧） | `~/.claude/` |'
has "$C" '| 2. 全局 | `~/.agents/` |'
has "$C" '| 3. 项目 | `<project>/.agents/` |'
has "$C" '<level>/AGENTS.md'
has "$C" '<project>/.agents/skills/*/SKILL.md'
has "$C" 'sdlc-workflow、sdlc-init、sdlc-update、sdlc-proposal、sdlc-apply、sdlc-qa、sdlc-accept、sdlc-pr、sdlc-review、sdlc-doit、sdlc-mini、sdlc-worktree'
has "$C" '提示先执行 update'
has "$C" 'bash "$SDLC_CORE/scripts/sdlc-sync-agents.sh" --check .'
has "$C" '提醒用户提交'
has "$C" '建议在此项目停用插件'
has "$SKILL_DIR/SKILL.md" '| 2. 全局 | `~/.agents/` |'

# D3：accept 执行 --check-paths，只提示不阻断
has "$R/flow-accept.md" 'bash "$SDLC_CORE/scripts/sdlc-sync-agents.sh" --check-paths .'
has "$R/flow-accept.md" '不阻断'

# D4：两份 README 有 npx skills 安装说明、新目录结构、提交/忽略、Windows 软链接、Codex hooks 信任、升级方式
for f in "$REPO_DIR/README.md" "$REPO_DIR/README.zh-CN.md"; do
  has "$f" "npx skills add evan-e2438927/sdlc-workflow --skill '*' -a claude-code -a codex -y"
  has "$f" 'AGENTS.md -> .agents/AGENTS.md'
  has "$f" '.agents/config.json'
  has "$f" 'core.symlinks'
  has "$f" '/hooks'
  has "$f" 'npx skills update'
  has "$f" 'git rm --cached'
  has "$f" '.agents/bin/sdlc-sync'
done
has "$R/context-loader.md" '.agents/bin/sdlc-sync'
has "$SKILL_DIR/templates/AGENTS.md.tpl" '.agents/bin/sdlc-sync'

# D5：文档中的 .claude/CLAUDE.md 只出现在迁移说明小节（最近的上级标题含「迁移」或 Migrat）
for f in README.md README.zh-CN.md docs/workflow-overview.md DESIGN-PROMO.md DESIGN-PROMO.zh-CN.md examples/30-second-demo.md docs/git-worktree-guide.md; do
  awk -v f="$f" '/^#+ / && !/^#+ *[0-9]+\./ { h = $0 } /\.claude\/CLAUDE\.md/ && h !~ /迁移|Migrat/ { printf "FAIL D5 %s:%d 不在迁移小节（标题: %s）\n", f, NR, h; bad = 1 } END { exit bad }' "$REPO_DIR/$f" || fail=1
done

# D6–D10：推广前的文档一致性
lacks() { ! grep -qF -- "$2" "$1" 2>/dev/null || { echo "FAIL: ${1#"$REPO_DIR"/} 不应包含: $2"; fail=1; }; }
for f in "$REPO_DIR/README.md" "$REPO_DIR/README.zh-CN.md"; do
  has   "$f" '`.claude/skills/<name>` → `../../.agents/skills/<name>`'
  lacks "$f" '`.agents/skills/<name>` → `../../.agents/skills/<name>`'
  has   "$f" '[jq](https://jqlang.org/)'
  has   "$f" "npx skills add evan-e2438927/sdlc-workflow -g --skill '*' -a claude-code -a codex -y"
  has   "$f" 'npx skills update -p -y'
  lacks "$f" '.claude/sdlc-workflow-repo'
done
for f in "$REPO_DIR/README.md" "$REPO_DIR/DESIGN-PROMO.md"; do
  lacks "$f" '(plugin marketplace, recommended)'
  has   "$f" '### npx skills, project-level (recommended)'
done
for f in "$REPO_DIR/README.zh-CN.md" "$REPO_DIR/DESIGN-PROMO.zh-CN.md"; do
  lacks "$f" '（plugin marketplace，推荐）'
  has   "$f" '### npx skills 项目级安装（推荐）'
done
lacks "$REPO_DIR/README.md" 'global `~/.claude/` + project `.agents/`'
lacks "$REPO_DIR/README.zh-CN.md" '全局 `~/.claude/` + 项目 `.agents/`'
lacks "$REPO_DIR/DESIGN-PROMO.md" 'global defaults can go in `~/.claude/.sdlc-config`'
lacks "$REPO_DIR/DESIGN-PROMO.zh-CN.md" '全局默认可放 `~/.claude/.sdlc-config`'
for f in README.md README.zh-CN.md DESIGN-PROMO.md DESIGN-PROMO.zh-CN.md docs/workflow-overview.md examples/30-second-demo.md; do
  bad="$(grep -nE '/sdlc-workflow (init|update|proposal|apply|qa|accept|pr|doit|mini|review|worktree)|\btg=' "$REPO_DIR/$f")"
  [ -z "$bad" ] || { echo "FAIL D9 $f 仍用旧命令写法："; echo "$bad" | sed 's/^/    /'; fail=1; }
done

# D11：examples/30-second-demo.md 含全流程使用教程（安装 → init → 配置 → 五阶段 → 并行 / 升级 → 速查）
T="$REPO_DIR/examples/30-second-demo.md"
for k in "npx skills add evan-e2438927/sdlc-workflow --skill '*' -a claude-code -a codex -y" \
         '/sdlc-init' '/sdlc-proposal' '/sdlc-apply' '/sdlc-qa' '/sdlc-accept' '/sdlc-pr' '/sdlc-doit' '/sdlc-mini' \
         '/sdlc-worktree create' '/sdlc-update' 'npx skills update -p -y' '.agents/bin/sdlc-sync' '.agents/config.json' \
         '.agents/.sdlc-config' 'qa_failed' '/hooks' '## 全流程使用教程' '## 30 秒版本' '## 速查表'; do
  has "$T" "$k"
done
for f in "$REPO_DIR/README.md" "$REPO_DIR/README.zh-CN.md"; do lacks "$f" '30-second start</a>'; lacks "$f" '30 秒上手</a>'; done

# ── END ──
[ "$fail" = "0" ] && echo PASS || exit 1
