#!/bin/bash
set -euo pipefail

# 把最新版插件的脚手架能力安全同步到已初始化的项目：
#   - 补齐新目录结构（幂等）
#   - 迁移 .claude/.sdlc-config（保留用户值，补新键，删废弃键）
#   - 刷新插件托管的 workflow-rules.md（旧版备份）
#   - 缺失的用户文档从模板补齐，但绝不覆盖已存在的用户内容
# 可重复运行，安全幂等。

PROJECT_ROOT="${1:-.}"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="$PROJECT_ROOT/.claude"

if [ ! -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  echo "❌ 项目尚未初始化（缺少 .claude/CLAUDE.md），请先运行 /sdlc-workflow:init"
  exit 1
fi

echo "🔄 同步最新 SDLC 脚手架到项目: $PROJECT_ROOT"

# ── 1. 目录结构（幂等）────────────────────────────────────────
mkdir -p "$CLAUDE_DIR/rules"
mkdir -p "$PROJECT_ROOT/docs/iterations"
mkdir -p "$PROJECT_ROOT/tests/unit/web" "$PROJECT_ROOT/tests/unit/server" "$PROJECT_ROOT/tests/unit/packages"
mkdir -p "$PROJECT_ROOT/tests/e2e"
mkdir -p "$PROJECT_ROOT/tests/reports"
echo "  ✅ 目录结构已对齐"

# ── 2. 迁移 .claude/.sdlc-config ──────────────────────────────
CONFIG="$CLAUDE_DIR/.sdlc-config"
TEMPLATE="$SKILL_DIR/templates/sdlc-config.tpl"
# 已废弃、需主动删除的键
OBSOLETE_KEYS="TG_USERNAME PARALLEL_TESTS"

is_obsolete() {
  case " $OBSOLETE_KEYS " in *" $1 "*) return 0;; *) return 1;; esac
}

if [ ! -f "$CONFIG" ]; then
  cp "$TEMPLATE" "$CONFIG"
  echo "  ✅ .claude/.sdlc-config 不存在，已从模板生成"
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
  echo "  ✅ .claude/.sdlc-config 已迁移（旧版备份: .sdlc-config.bak）"
  if [ -n "$added" ];     then echo "     ＋ 新增键:$added"; fi
  if [ -n "$preserved" ]; then echo "     ⊙ 保留自定义键:$preserved"; fi
  # 报告被移除的废弃键
  removed=""
  for k in $OBSOLETE_KEYS; do
    if grep -qE "^$k=" "$CONFIG.bak"; then removed="$removed $k"; fi
  done
  if [ -n "$removed" ]; then echo "     － 移除废弃键:$removed"; fi
fi

# ── 3. 刷新插件托管文件：workflow-rules.md（旧版备份）──────────
RULES="$CLAUDE_DIR/rules/workflow-rules.md"
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
ensure_user_doc "$SKILL_DIR/templates/CLAUDE.md.tpl"            "$CLAUDE_DIR/CLAUDE.md"            ".claude/CLAUDE.md"
ensure_user_doc "$SKILL_DIR/templates/ARCHITECTURE.md.tpl"      "$CLAUDE_DIR/ARCHITECTURE.md"      ".claude/ARCHITECTURE.md"
ensure_user_doc "$SKILL_DIR/templates/SECURITY.md.tpl"         "$CLAUDE_DIR/SECURITY.md"         ".claude/SECURITY.md"
ensure_user_doc "$SKILL_DIR/templates/CODING_GUIDELINES.md.tpl" "$CLAUDE_DIR/CODING_GUIDELINES.md" ".claude/CODING_GUIDELINES.md"

# ── 5. .gitignore 兜底 ───────────────────────────────────────
ensure_gitignore() {
  local pattern="$1"
  if [ -f "$PROJECT_ROOT/.gitignore" ]; then
    grep -qxF "$pattern" "$PROJECT_ROOT/.gitignore" || echo "$pattern" >> "$PROJECT_ROOT/.gitignore"
  else
    echo "$pattern" > "$PROJECT_ROOT/.gitignore"
  fi
}
ensure_gitignore ".claude/.sdlc-config"
ensure_gitignore ".claude/.sdlc-config.local"

echo "✅ 同步完成。用户编辑的 CLAUDE.md / ARCHITECTURE.md / SECURITY.md / CODING_GUIDELINES.md 未被改动。"
echo "   如 workflow-rules.md / .sdlc-config 有自定义内容，请对照 .bak 备份回并。"
