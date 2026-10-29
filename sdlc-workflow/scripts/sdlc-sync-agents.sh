#!/bin/bash
# sdlc-sync-agents.sh — 由 .agents/ 生成各平台文件（.agents/ 是唯一事实来源）
#
# 用法：sdlc-sync-agents.sh [--check] [--check-paths] <项目根>
#   （默认）     写入，幂等：连续运行两次，第二次没有任何变化
#   --check       只检查不写入：缺失、内容不一致、软链接错误或冲突时列出并退出 1
#   --check-paths 在 --check 基础上，检查各级 AGENTS.md 引用的仓库内路径是否存在
# 退出码：0 = 正常；1 = 有漂移（含未解决的冲突）；2 = 出错
#
# 输出（详见 references/context-loader.md「同步」）：
#   软链接  AGENTS.md / CLAUDE.md → .agents/AGENTS.md；X/CLAUDE.md → AGENTS.md（子目录）
#           .claude/skills/<n> → ../../.agents/skills/<n>
#           .claude/agents/sdlc-*-dev.md → 项目内核心的 agents/（仅 npx 安装在项目里时）
#   文件    .agents/hooks/*（核心 templates/hooks/ 的副本）
#           .claude/settings.json、.mcp.json、.cursor/mcp.json、.codex/config.toml、.codex/hooks.json
#   .gitignore 中 "# >>> sdlc generated >>>" … "# <<< sdlc generated <<<" 托管块（整块重写）
# 冲突规则：目标位置是实体文件或目录时绝不覆盖，只告警（计为漂移）。
set -uo pipefail

usage() { sed -n '3,7p' "$0" | sed 's/^# \{0,1\}//' >&2; }
die() { echo "❌ $*" >&2; exit 2; }

MODE=write; CHECK_PATHS=0; ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE=check ;;
    --check-paths) MODE=check; CHECK_PATHS=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) usage; die "未知参数: $1" ;;
    *) [ -z "$ROOT" ] || die "只能指定一个项目根"; ROOT="$1" ;;
  esac
  shift
done
[ -n "$ROOT" ] || { usage; die "缺少项目根参数"; }
[ -d "$ROOT" ] || die "项目根不存在: $ROOT"
ROOT="$(cd "$ROOT" && pwd)"
CORE="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$ROOT/.agents/AGENTS.md" ] || die "项目未初始化（缺少 .agents/AGENTS.md），请先执行 init；旧布局项目请执行 update"
command -v jq >/dev/null 2>&1 || die "缺少 jq（同步脚本依赖 jq）"

TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
DRIFT=0; CHANGED=0; ERRORS=0

changed() { echo "  ✔ $1"; CHANGED=$((CHANGED + 1)); }
drift()   { echo "  ✗ $1: $2"; DRIFT=$((DRIFT + 1)); }
# write_failed <rel> <动作>：写入失败（如文件系统不支持软链接、目录不可写），最终以退出码 2 结束
write_failed() { echo "  ❌ ${1}: ${2}失败"; ERRORS=$((ERRORS + 1)); }
# conflict <rel> [hint]：实体文件/目录占位，不覆盖
conflict() {
  if [ "$MODE" = check ]; then echo "  ✗ $1: conflict（实体文件或目录，未覆盖）"
  else echo "  ⚠ 冲突: $1 是实体文件或目录，未覆盖，请自行处理"; fi
  [ -n "${2:-}" ] && echo "    提示: $2"
  DRIFT=$((DRIFT + 1))
}

# want_link <rel> <target>：确保 <rel> 是指向 <target> 的软链接
want_link() {
  local rel="$1" target="$2" p="$ROOT/$1"
  if [ -L "$p" ]; then
    [ "$(readlink "$p")" = "$target" ] && return 0
    if [ "$MODE" = check ]; then drift "$rel" "wrong-link（指向 $(readlink "$p")，应为 ${target}）"; return 0; fi
    if rm -f "$p" && ln -s "$target" "$p"; then changed "$rel → $target"; else write_failed "$rel" "替换软链接"; fi
  elif [ -e "$p" ]; then
    if [ -f "$p" ] && [ "$(cat "$p")" = "$target" ]; then
      conflict "$rel" "该文件内容就是链接目标，像是软链接被检出成了文本文件：Windows 请开启开发者模式并执行 git config core.symlinks true 后重新检出"
    else
      conflict "$rel"
    fi
  else
    if [ "$MODE" = check ]; then drift "$rel" "missing（应为 → ${target}）"; return 0; fi
    if mkdir -p "$(dirname "$p")" && ln -s "$target" "$p"; then changed "$rel → $target"; else write_failed "$rel" "创建软链接"; fi
  fi
}

# want_file <rel> <src> [exec]：确保 <rel> 的内容与 <src> 一致（整份重写）
want_file() {
  local rel="$1" src="$2" p="$ROOT/$1"
  if [ -d "$p" ] && [ ! -L "$p" ]; then conflict "$rel"; return 0; fi
  if [ -f "$p" ] && [ ! -L "$p" ] && cmp -s "$src" "$p"; then return 0; fi
  if [ "$MODE" = check ]; then
    if [ -e "$p" ] || [ -L "$p" ]; then drift "$rel" "differs（生成文件被改动或已过期）"; else drift "$rel" "missing"; fi
    return 0
  fi
  mkdir -p "$(dirname "$p")" && rm -f "$p" && cp "$src" "$p" || die "写入失败: $rel"
  [ "${3:-}" = exec ] && chmod +x "$p"
  changed "$rel"
}

# ── 1. 根入口软链接 ─────────────────────────────────────────────
want_link AGENTS.md .agents/AGENTS.md
want_link CLAUDE.md .agents/AGENTS.md

# ── 2. 子目录 AGENTS.md 旁的 CLAUDE.md ─────────────────────────
# 跳过 . 开头的目录、node_modules、.gitignore 忽略的路径（非 git 项目用 find）
list_agents_md() {
  if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$ROOT" ls-files -co --exclude-standard 2>/dev/null | grep -E '(^|/)AGENTS\.md$' | sort -u
  else
    (cd "$ROOT" && find . \( -name node_modules -o -name '.?*' \) -prune -o -name AGENTS.md -print | sed 's#^\./##' | sort)
  fi
}
while IFS= read -r rel; do
  [ -n "$rel" ] && [ "$rel" != AGENTS.md ] || continue
  case "/$rel" in */.*|*/node_modules/*) continue ;; esac
  [ -e "$ROOT/$rel" ] || continue
  want_link "$(dirname "$rel")/CLAUDE.md" AGENTS.md
done <<EOF
$(list_agents_md)
EOF

# ── 3. .claude/skills 与 .claude/agents ────────────────────────
for d in "$ROOT"/.agents/skills/*/; do
  [ -f "$d/SKILL.md" ] || continue
  n="$(basename "$d")"
  want_link ".claude/skills/$n" "../../.agents/skills/$n"
done
for l in "$ROOT"/.claude/skills/* "$ROOT"/.claude/agents/*; do
  [ -L "$l" ] || continue
  case "$(readlink "$l")" in ../../.agents/skills/*) ;; *) continue ;; esac
  [ -e "$l" ] && continue
  rel="${l#"$ROOT"/}"
  if [ "$MODE" = check ]; then drift "$rel" "dangling（目标已不存在）"
  elif rm -f "$l"; then changed "删除悬空链接 $rel"
  else write_failed "$rel" "删除悬空链接"; fi
done
AGENTS_SRC="$ROOT/.agents/skills/sdlc-workflow/agents"
if [ -d "$AGENTS_SRC" ]; then
  for r in backend frontend test; do
    [ -f "$AGENTS_SRC/sdlc-$r-dev.md" ] || continue
    want_link ".claude/agents/sdlc-$r-dev.md" "../../.agents/skills/sdlc-workflow/agents/sdlc-$r-dev.md"
  done
fi

# ── 4. sdlc 托管 hooks ─────────────────────────────────────────
for f in "$CORE"/templates/hooks/*.sh; do
  [ -f "$f" ] || continue
  want_file ".agents/hooks/$(basename "$f")" "$f" exec
done

# ── 5. 平台配置：由 .agents/config.json 整份生成（用户要改就改 config.json）──
CFG="$ROOT/.agents/config.json"
[ -f "$CFG" ] || die "缺少 .agents/config.json，请执行 update（会从模板补齐）"
jq -e 'type == "object"' "$CFG" >/dev/null 2>&1 || die ".agents/config.json 不是合法的 JSON 对象"

# 中立的 mcpServers 写法：transport 为 stdio 或 http（缺省时有 url 视为 http）
JQ_DEFS='
  def transport: (.transport // (if .url then "http" else "stdio" end));
  def servers: (.mcpServers // {});
'
GUARD_CMD='bash "${CLAUDE_PROJECT_DIR}/.agents/hooks/sdlc-pre-edit-guard.sh"'
CHECK_CMD='bash "${CLAUDE_PROJECT_DIR}/.agents/hooks/sdlc-post-edit-check.sh"'
CODEX_CHECK_CMD='bash "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.agents/hooks/sdlc-post-edit-check.sh"'

# .claude/settings.json：config.claude.settings + sdlc hooks（追加在用户 hooks 之后）
jq --arg g "$GUARD_CMD" --arg c "$CHECK_CMD" '
  (.claude.settings // {}) as $s
  | $s | .hooks = ($s.hooks // {})
  | .hooks.PreToolUse  = ((.hooks.PreToolUse  // []) + [{matcher: "Edit|Write|MultiEdit", hooks: [{type: "command", command: $g}]}])
  | .hooks.PostToolUse = ((.hooks.PostToolUse // []) + [{matcher: "Edit|Write", hooks: [{type: "command", command: $c}]}])
' "$CFG" > "$TMPD/settings.json" || die "生成 .claude/settings.json 失败（检查 config.claude.settings）"
want_file .claude/settings.json "$TMPD/settings.json"

# .mcp.json（Claude Code）与 .cursor/mcp.json
jq "$JQ_DEFS"'{mcpServers: (servers | map_values({type: transport} + del(.transport)))}' "$CFG" > "$TMPD/mcp.json" \
  || die "生成 .mcp.json 失败（检查 config.mcpServers）"
want_file .mcp.json "$TMPD/mcp.json"
jq "$JQ_DEFS"'{mcpServers: (servers | map_values(del(.transport)))}' "$CFG" > "$TMPD/cursor-mcp.json" \
  || die "生成 .cursor/mcp.json 失败"
want_file .cursor/mcp.json "$TMPD/cursor-mcp.json"

# .codex/config.toml：头注释 → codex.extraToml 原文（放在前面，顶层键才不会落进 mcp 表）→ [mcp_servers.*]
# extraToml 中已定义的 [mcp_servers.<name>] 以它为准，不再重复输出。
jq -j "$JQ_DEFS"'
  def tkey: if test("^[A-Za-z0-9_-]+$") then . else tojson end;
  def tval: if type == "string" then tojson
    elif type == "array" then "[" + (map(tval) | join(", ")) + "]"
    elif type == "object" then "{ " + (to_entries | map((.key | tkey) + " = " + (.value | tval)) | join(", ")) + " }"
    else tostring end;
  (.codex.extraToml // "") as $extra
  | [ $extra | scan("(?m)^\\[mcp_servers\\.(\"[^\"]+\"|[A-Za-z0-9_-]+)\\]") | .[0]
      | if startswith("\"") then fromjson else . end ] as $defined
  | "# 由 sdlc-sync-agents.sh 根据 .agents/config.json 生成，请勿手改（改 config.json 后重新同步）\n"
  + (if $extra == "" then "" else "\n" + $extra + (if ($extra | endswith("\n")) then "" else "\n" end) end)
  + ( servers | to_entries
      | map(select(.key as $k | $defined | any(. == $k) | not))
      | map(.value as $v
          | "\n[mcp_servers." + (.key | tkey) + "]\n"
          + (if ($v | transport) == "stdio" then
               "command = " + ($v.command | tval) + "\n"
               + (if $v.args then "args = " + ($v.args | tval) + "\n" else "" end)
               + (if $v.env then "env = " + ($v.env | tval) + "\n" else "" end)
             else
               "url = " + ($v.url | tval) + "\n"
               + (if $v.headers then "http_headers = " + ($v.headers | tval) + "\n" else "" end)
             end))
      | join(""))
' "$CFG" > "$TMPD/config.toml" || die "生成 .codex/config.toml 失败（检查 config.mcpServers / codex.extraToml）"
want_file .codex/config.toml "$TMPD/config.toml"

# .codex/hooks.json：只注册编辑后检查（Codex 输入没有子 agent 身份，越界守卫无法判断角色）
jq -n --arg c "$CODEX_CHECK_CMD" \
  '{hooks: {PostToolUse: [{matcher: "apply_patch|Edit|Write", hooks: [{type: "command", command: $c}]}]}}' \
  > "$TMPD/codex-hooks.json"
want_file .codex/hooks.json "$TMPD/codex-hooks.json"

# ── 6. .gitignore 托管块 ───────────────────────────────────────
BEGIN_MARK='# >>> sdlc generated >>>'
END_MARK='# <<< sdlc generated <<<'
cat > "$TMPD/block" <<EOF
$BEGIN_MARK
# 由 sdlc-sync-agents.sh 维护，每次整块重写；自己的规则请写在块外
.claude/settings.json
.claude/settings.local.json
.mcp.json
.cursor/mcp.json
.codex/config.toml
.codex/hooks.json
.agents/.sdlc-config
.agents/.sdlc-config.local
.agents/.sdlc-active-iteration
.agents/.backup/
.agents/**/*.bak
$END_MARK
EOF
GI="$ROOT/.gitignore"
if [ -f "$GI" ] && grep -qxF "$BEGIN_MARK" "$GI"; then
  grep -qxF "$END_MARK" "$GI" || die ".gitignore 中托管块缺少结束标记「${END_MARK}」，请手动修复"
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" -v blk="$TMPD/block" '
    $0 == b { while ((getline l < blk) > 0) print l; skip = 1; next }
    skip && $0 == e { skip = 0; next }
    !skip { print }
  ' "$GI" > "$TMPD/gitignore"
elif [ -f "$GI" ] && [ -s "$GI" ]; then
  { cat "$GI"; [ -n "$(tail -c1 "$GI")" ] && echo; echo; cat "$TMPD/block"; } > "$TMPD/gitignore"
else
  cp "$TMPD/block" "$TMPD/gitignore"
fi
want_file .gitignore "$TMPD/gitignore"

# ── 7. --check-paths：AGENTS.md 中引用的仓库内路径是否存在 ─────
# Markdown 链接目标（去掉 #锚点，跳过 scheme:// 与 mailto:）与反引号中的路径
# （只含 [A-Za-z0-9_.@/-]、含 /、以 / 结尾或末段带扩展名）；代码块内不检查。
# 相对该 AGENTS.md 所在目录或项目根，任一存在即视为有效。
check_paths_in() {
  local rel="$1" fdir tok
  fdir="$(dirname "$ROOT/$rel")"
  awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$ROOT/$rel" > "$TMPD/md"
  {
    grep -oE '\]\([^)]+\)' "$TMPD/md" | sed -E 's/^\]\(//; s/\)$//; s/[[:space:]]+".*"$//; s/#.*$//' \
      | grep -vE '^$|^[A-Za-z][A-Za-z0-9+.-]*:'
    grep -oE '`[^`]+`' "$TMPD/md" | sed -E 's/^`//; s/`$//' \
      | grep -E '^[A-Za-z0-9_.@/-]+$' | grep '/' | grep -vE '^[/~]' | grep -E '/$|/[^/]*\.[^/]+$|^[^/]*\.[^/]+$'
  } | sort -u > "$TMPD/paths"
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    [ -e "$fdir/$tok" ] || [ -e "$ROOT/$tok" ] || drift "$rel" "broken-path ${tok}（引用的路径不存在）"
  done < "$TMPD/paths"
}
if [ "$CHECK_PATHS" = 1 ]; then
  check_paths_in .agents/AGENTS.md
  while IFS= read -r rel; do
    [ -n "$rel" ] && [ "$rel" != AGENTS.md ] || continue
    case "/$rel" in */.*|*/node_modules/*) continue ;; esac
    [ -f "$ROOT/$rel" ] && check_paths_in "$rel"
  done <<EOF
$(list_agents_md)
EOF
fi

# ── 结果 ───────────────────────────────────────────────────────
if [ "$ERRORS" -gt 0 ]; then
  echo "❌ 同步未完成：${ERRORS} 处写入失败（见上方 ❌）；Windows 请开启开发者模式并设置 git config core.symlinks true" >&2
  exit 2
fi
if [ "$DRIFT" -gt 0 ]; then
  if [ "$MODE" = check ]; then echo "发现 $DRIFT 处与 .agents/ 不一致（执行不带 --check 的同步可修复；冲突需手动处理）"
  else echo "同步完成，但有 $DRIFT 处冲突未解决（见上方 ⚠）"; fi
  exit 1
fi
if [ "$MODE" = check ]; then echo "✓ 平台文件与 .agents/ 一致"
elif [ "$CHANGED" -gt 0 ]; then echo "同步完成：$CHANGED 处更新"
else echo "已是最新，无需同步"; fi
exit 0
