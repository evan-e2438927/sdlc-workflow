#!/bin/bash
set -euo pipefail

# update-project.sh <项目根> — 把最新版 sdlc 的脚手架安全同步到已初始化的项目：
#   - 旧布局（.claude/CLAUDE.md 等为实体文件）→ 先迁移到 .agents/（原文件备份到 .agents/.backup/<时间戳>/，
#     路径改写为 .agents/，自定义 skill 移到 .agents/skills/，已有平台配置导入 .agents/config.json）
#   - 补齐新目录结构（幂等）
#   - 迁移 .agents/.sdlc-config（保留用户值，补新键，删废弃键）
#   - 刷新 sdlc 托管的 workflow-rules.md（旧版备份）
#   - 缺失的用户文档从模板补齐，但绝不覆盖已存在的用户内容
#   - 执行同步（软链接、hooks、平台文件、.gitignore 托管块）
# 可重复运行：已是新布局的项目只做同步和配置键迁移。

PROJECT_ROOT="${1:-.}"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SYNC="$SKILL_DIR/scripts/sdlc-sync-agents.sh"
# shellcheck source=sdlc-migrate-lib.sh
. "$SKILL_DIR/scripts/sdlc-migrate-lib.sh"

[ -d "$PROJECT_ROOT" ] || { echo "❌ 项目目录不存在: $PROJECT_ROOT"; exit 1; }
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
A="$PROJECT_ROOT/.agents"
C="$PROJECT_ROOT/.claude"
BAK="$A/.backup/$(date +%Y%m%d-%H%M%S)"

is_real() { [ -f "$1" ] && [ ! -L "$1" ]; }
LEGACY=0
if is_real "$C/CLAUDE.md" || is_real "$C/ARCHITECTURE.md"; then LEGACY=1; fi
if [ "$LEGACY" = 0 ] && [ ! -f "$A/AGENTS.md" ]; then
  echo "❌ 项目尚未初始化（缺少 .agents/AGENTS.md），请先运行 init（/sdlc-init）"
  exit 1
fi

echo "🔄 同步最新 SDLC 脚手架到项目: $PROJECT_ROOT"

# ── 0. 旧布局迁移：.claude/ → .agents/ ─────────────────────────
MOVED=""; KEPT=""
# 文件内容中指向 .claude/ 下规则文件的路径改写为 .agents/（全局 ~/.claude/ 不动）
rewrite_paths() {
  perl -pi -e 's#(?<!~/)\.claude/CLAUDE\.md#.agents/AGENTS.md#g;
    s#(?<!~/)\.claude/(ARCHITECTURE|SECURITY|CODING_GUIDELINES|PROJECT_BASELINE|EXISTING_STRUCTURE|TEST_BASELINE)\.md#.agents/$1.md#g;
    s#(?<!~/)\.claude/(rules|skills|hooks)/#.agents/$1/#g;
    s#(?<!~/)\.claude/\.sdlc-(config|active-iteration)#.agents/.sdlc-$1#g' "$@"
}
# move_item <.claude 下相对路径> <.agents 下相对路径>：备份后移动；目标已存在则不覆盖
move_item() {
  local src="$C/$1" dst="$A/$2" f
  [ -e "$src" ] || [ -L "$src" ] || return 0
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    KEPT="$KEPT .claude/$1"
    echo "  ⚠ 未移动 .claude/$1：.agents/$2 已存在（两者都保留，请人工核对）"
    return 0
  fi
  sdlc_backup "$PROJECT_ROOT" "$BAK" ".claude/$1"
  mkdir -p "$(dirname "$dst")"
  mv "$src" "$dst"
  if [ -d "$dst" ]; then
    find "$dst" -type f -name '*.md' | while IFS= read -r f; do rewrite_paths "$f"; done
  else
    case "$dst" in *.md) rewrite_paths "$dst" ;; esac
  fi
  MOVED="$MOVED"$'\n'"     .claude/$1 → .agents/$2"
}

if [ "$LEGACY" = 1 ]; then
  echo "  🚚 检测到旧布局（.claude/），迁移到 .agents/（原文件备份: ${BAK#"$PROJECT_ROOT"/}/）"
  mkdir -p "$A/rules" "$A/skills"
  move_item CLAUDE.md AGENTS.md
  for f in ARCHITECTURE SECURITY CODING_GUIDELINES PROJECT_BASELINE EXISTING_STRUCTURE TEST_BASELINE; do
    move_item "$f.md" "$f.md"
  done
  for f in "$C"/rules/*; do
    [ -e "$f" ] || continue
    move_item "rules/$(basename "$f")" "rules/$(basename "$f")"
  done
  rmdir "$C/rules" 2>/dev/null || true
  for f in .sdlc-config .sdlc-config.local .sdlc-active-iteration; do move_item "$f" "$f"; done
  # sdlc 托管 hooks：备份后删除，由同步重建到 .agents/hooks/
  for f in "$C"/hooks/sdlc-*.sh; do
    [ -f "$f" ] || continue
    sdlc_backup "$PROJECT_ROOT" "$BAK" ".claude/hooks/$(basename "$f")"
    rm -f "$f"
  done
  rmdir "$C/hooks" 2>/dev/null || true
  # 项目自定义 skill（实体目录）与占位 README 移到 .agents/skills/，原位置由同步改为软链接
  for f in "$C"/skills/*; do
    [ -e "$f" ] && [ ! -L "$f" ] || continue
    n="$(basename "$f")"
    if [ -d "$f" ] || [ "$n" = README.md ]; then move_item "skills/$n" "skills/$n"; fi
  done
  sdlc_absorb_root_doc "$PROJECT_ROOT" "$BAK" AGENTS.md
  sdlc_absorb_root_doc "$PROJECT_ROOT" "$BAK" CLAUDE.md
  [ -f "$A/config.json" ] || cp "$SKILL_DIR/templates/config.json.tpl" "$A/config.json"
  sdlc_import_platform "$PROJECT_ROOT" "$BAK"
  echo "  ✅ 规则文件已迁移到 .agents/"
fi
[ -f "$A/config.json" ] || { cp "$SKILL_DIR/templates/config.json.tpl" "$A/config.json"; echo "  ＋ 补齐 .agents/config.json"; }

# ── 1. 目录结构（幂等）────────────────────────────────────────
mkdir -p "$A/rules" "$A/skills"
mkdir -p "$PROJECT_ROOT/docs/iterations"
mkdir -p "$PROJECT_ROOT/tests/unit/web" "$PROJECT_ROOT/tests/unit/server" "$PROJECT_ROOT/tests/unit/packages"
mkdir -p "$PROJECT_ROOT/tests/e2e" "$PROJECT_ROOT/tests/reports"
echo "  ✅ 目录结构已对齐"

# ── 2. 迁移 .agents/.sdlc-config ──────────────────────────────
CONFIG="$A/.sdlc-config"
TEMPLATE="$SKILL_DIR/templates/sdlc-config.tpl"
# 已废弃、需主动删除的键
OBSOLETE_KEYS="TG_USERNAME PARALLEL_TESTS"

is_obsolete() {
  case " $OBSOLETE_KEYS " in *" $1 "*) return 0;; *) return 1;; esac
}

if [ ! -f "$CONFIG" ]; then
  cp "$TEMPLATE" "$CONFIG"
  echo "  ✅ .agents/.sdlc-config 不存在，已从模板生成"
else
  cp "$CONFIG" "$CONFIG.bak"
  tmp="$(mktemp)"

  added=""; kept=""
  # 2a. 以模板为骨架（最新注释 + 新键），用用户已有值覆盖匹配键
  while IFS= read -r line || [ -n "$line" ]; do
    if printf '%s' "$line" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*='; then
      key="${line%%=*}"
      if grep -qE "^$key=" "$CONFIG"; then
        uv="$(grep -E "^$key=" "$CONFIG" | head -1 | cut -d= -f2-)"
        printf '%s=%s\n' "$key" "$uv" >> "$tmp"
        kept="$kept $key"
      else
        printf '%s\n' "$line" >> "$tmp"   # 模板默认（新键）
        added="$added $key"
      fi
    else
      printf '%s\n' "$line" >> "$tmp"      # 注释/空行
    fi
  done < "$TEMPLATE"

  # 2b. 保留用户自定义的、非废弃、且不在模板里的键（如 worktree 注入的 PORT/API_PORT）
  preserved=""
  while IFS= read -r line || [ -n "$line" ]; do
    printf '%s' "$line" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*=' || continue
    key="${line%%=*}"
    if ! grep -qE "^$key=" "$TEMPLATE" && ! is_obsolete "$key"; then
      printf '%s\n' "$line" >> "$tmp"
      preserved="$preserved $key"
    fi
  done < "$CONFIG"

  mv "$tmp" "$CONFIG"
  echo "  ✅ .agents/.sdlc-config 已迁移（旧版备份: .sdlc-config.bak）"
  if [ -n "$added" ];     then echo "     ＋ 新增键:$added"; fi
  if [ -n "$preserved" ]; then echo "     ⊙ 保留自定义键:$preserved"; fi
  # 报告被移除的废弃键
  removed=""
  for k in $OBSOLETE_KEYS; do
    if grep -qE "^$k=" "$CONFIG.bak"; then removed="$removed $k"; fi
  done
  if [ -n "$removed" ]; then echo "     － 移除废弃键:$removed"; fi
fi

# ── 3. 刷新 sdlc 托管文件：workflow-rules.md（旧版备份）──────────
RULES="$A/rules/workflow-rules.md"
RULES_TPL="$SKILL_DIR/templates/workflow-rules.md.tpl"
if [ -f "$RULES" ]; then
  if cmp -s "$RULES" "$RULES_TPL"; then
    echo "  ✅ workflow-rules.md 已是最新"
  else
    cp "$RULES" "$RULES.bak"
    cp "$RULES_TPL" "$RULES"
    echo "  ✅ workflow-rules.md 已刷新（旧版备份: workflow-rules.md.bak，如有自定义请回并）"
  fi
else
  cp "$RULES_TPL" "$RULES"
  echo "  ✅ workflow-rules.md 已补齐"
fi

# ── 4. 用户文档：缺失才补，已存在绝不覆盖 ─────────────────────
ensure_user_doc() {
  local tpl="$1" dst="$2" name="$3"
  if [ ! -f "$dst" ]; then
    cp "$tpl" "$dst"
    echo "  ＋ 补齐缺失文档: $name"
  fi
}
ensure_user_doc "$SKILL_DIR/templates/AGENTS.md.tpl"            "$A/AGENTS.md"            ".agents/AGENTS.md"
ensure_user_doc "$SKILL_DIR/templates/ARCHITECTURE.md.tpl"      "$A/ARCHITECTURE.md"      ".agents/ARCHITECTURE.md"
ensure_user_doc "$SKILL_DIR/templates/SECURITY.md.tpl"          "$A/SECURITY.md"          ".agents/SECURITY.md"
ensure_user_doc "$SKILL_DIR/templates/CODING_GUIDELINES.md.tpl" "$A/CODING_GUIDELINES.md" ".agents/CODING_GUIDELINES.md"

# ── 5. 自定义 skills 脚手架（占位说明 + AGENTS.md 小节，幂等）──
if [ ! -f "$A/skills/README.md" ]; then
  cat > "$A/skills/README.md" <<'EOF'
# 自定义 Skills

把项目专属 skill 放到本目录：`.agents/skills/<name>/SKILL.md`
（frontmatter 需含 `name` 与 `description`）。

SDLC pipeline 会自动发现并在与当前阶段相关时优先调用；Claude Code 通过同步生成的
`.claude/skills/<name>` 软链接发现它们。详见 `.agents/AGENTS.md` 的「自定义 Skills」小节。
EOF
  echo "  ＋ 补齐 .agents/skills/README.md"
fi
AGENTSMD="$A/AGENTS.md"
# AGENTS.md 若缺「自定义 Skills」小节则追加（不覆盖已有内容）
if ! grep -q '^## 自定义 Skills' "$AGENTSMD"; then
  cp "$AGENTSMD" "$AGENTSMD.bak"
  cat >> "$AGENTSMD" <<'EOF'

## 自定义 Skills
把项目专属 skill 放到 `.agents/skills/<name>/SKILL.md`（frontmatter 需含 `name` 与 `description`）。SDLC pipeline 会自动发现它们，并在 `description` 与当前阶段相关时**优先调用**（先 skill、后自造）。
- Claude Code：同步脚本自动生成 `.claude/skills/<name>` 软链接，harness 原生发现（软链接需提交）。
- Codex：原生读取 `.agents/skills/`，并由统一上下文加载入口建立索引。
- 想让某 skill 只在特定阶段用，在其 `description` 里点明阶段即可，无需额外配置。
EOF
  echo "  ＋ AGENTS.md 追加「自定义 Skills」小节（旧版备份: AGENTS.md.bak）"
fi

# ── 5.1 迁移历史迭代深度指令（用户 AGENTS.md 不被整体覆盖，做定向替换）──
if grep -q '务必先阅读 `docs/iterations/` 下的历史迭代' "$AGENTSMD"; then
  [ -f "$AGENTSMD.bak" ] || cp "$AGENTSMD" "$AGENTSMD.bak"
  # 用 perl 做整行替换，避免 sed 在不同平台对中文/反引号的转义差异
  perl -i -pe 's/\*\*在处理新需求时，务必先阅读 `docs\/iterations\/` 下的历史迭代\*\*/**在处理新需求时，先阅读 `docs\/iterations\/` 下最近 `HISTORY_ITER_DEPTH` 个迭代**（默认 2，`0`=全部；见 `.agents\/.sdlc-config`）的 requirements.md 与 design.md/g' "$AGENTSMD"
  echo "  ✅ AGENTS.md 历史迭代指令已迁移为 HISTORY_ITER_DEPTH（旧版备份: AGENTS.md.bak）"
fi

# ── 6. .gitignore：qa 产物（sdlc 生成文件由同步脚本的托管块维护）──
ensure_gitignore() {
  local pattern="$1"
  if [ -f "$PROJECT_ROOT/.gitignore" ]; then
    grep -qxF "$pattern" "$PROJECT_ROOT/.gitignore" || echo "$pattern" >> "$PROJECT_ROOT/.gitignore"
  else
    echo "$pattern" > "$PROJECT_ROOT/.gitignore"
  fi
}
ensure_gitignore "# SDLC qa 二进制产物（保留 tests/reports/*.md）"
ensure_gitignore "tests/reports/**/screenshots/"
ensure_gitignore "tests/reports/playwright/"
ensure_gitignore "tests/reports/**/*.png"

# ── 7. 同步：软链接、hooks、平台文件、.gitignore 托管块 ─────────
rc=0
bash "$SYNC" "$PROJECT_ROOT" || rc=$?
case "$rc" in
  0) ;;
  1) echo "  ⚠ 同步有冲突未解决（见上方 ⚠），请处理后重新执行 update" ;;
  *) echo "❌ 同步失败（退出码 $rc）" >&2; exit 2 ;;
esac

echo "✅ 同步完成。用户编辑的 ARCHITECTURE.md / SECURITY.md / CODING_GUIDELINES.md 未被改动；"
echo "   AGENTS.md 仅在缺少「自定义 Skills」小节时追加（不改动既有内容，旧版见 AGENTS.md.bak）。"
echo "   如 workflow-rules.md / .sdlc-config 有自定义内容，请对照 .bak 备份回并。"
if [ "$LEGACY" = 1 ]; then
  echo ""
  echo "📋 迁移报告"
  echo "   移动:${MOVED:- 无}"
  [ -n "$KEPT" ] && echo "   未移动（目标已存在，需人工核对）:$KEPT"
  echo "   备份: ${BAK#"$PROJECT_ROOT"/}/"
  echo "   平台配置已并入 .agents/config.json；.claude/settings.json、.mcp.json、.codex/、.cursor/mcp.json 改为生成文件（已 gitignore）"
  echo "   请提交: AGENTS.md、CLAUDE.md（软链接）、.agents/（除 gitignore 项）、.claude/skills/ 与 .claude/agents/ 下的软链接，以及 .claude/ 下旧文件的删除"
  echo "   Codex 用户: 首次使用需在 /hooks 中信任本项目的 hooks"
fi
