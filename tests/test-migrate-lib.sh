#!/bin/bash
# sdlc-migrate-lib.sh：导入既有平台配置、吸收根目录 AGENTS.md / CLAUDE.md、备份。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$HERE/.." && pwd)"; SKILL_DIR="$REPO_DIR/sdlc-workflow"
LIB="$SKILL_DIR/scripts/sdlc-migrate-lib.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0
ck() { [ "$1" = "$2" ] || { echo "FAIL $3（期望 $2，实际 $1）"; fail=1; }; }
has_out() { grep -qF -- "$1" "$TMP/out" || { echo "FAIL $2：输出缺少「$1」"; sed 's/^/    out: /' "$TMP/out" | head -20; fail=1; }; }
mk() {
  P="$TMP/$1"; BAK="$P/.agents/.backup/20261030-000000"; rm -rf "$P"; mkdir -p "$P/.agents"
  git -C "$P" init -q
  printf '# rules\n' > "$P/.agents/AGENTS.md"
  cp "$SKILL_DIR/templates/config.json.tpl" "$P/.agents/config.json"
}
# imp：在子 shell 中引入库并导入，输出存 $TMP/out，回显退出码
imp() { ( . "$LIB" && sdlc_import_platform "$P" "$BAK" ) >"$TMP/out" 2>&1; echo $?; }
C() { jq -r "$1" "$P/.agents/config.json"; }

# M1：.mcp.json 自定义 server；同名 playwright 参数不同 → 以 .mcp.json 为准并列出
mk m1
mkdir -p "$P/.cursor"
jq -n '{mcpServers:{custom:{type:"stdio",command:"my-mcp",args:["--x"],env:{K:"v"}},playwright:{type:"stdio",command:"npx",args:["@playwright/mcp@1.0.0"]}}}' > "$P/.mcp.json"
jq -n '{mcpServers:{cur:{url:"https://c.example/mcp"},custom:{command:"cursor-version"}}}' > "$P/.cursor/mcp.json"
ck "$(imp)" 0 "M1 导入"
ck "$(C '.mcpServers.custom.transport')" stdio "M1 custom 转为中立格式"
ck "$(C '.mcpServers.custom.command')" my-mcp "M1 同名以 .mcp.json 为准"
ck "$(C '.mcpServers.custom | has("type")')" false "M1 去掉平台字段 type"
ck "$(C '.mcpServers.playwright.args[0]')" "@playwright/mcp@1.0.0" "M1 playwright 以 .mcp.json 为准"
ck "$(C '.mcpServers.cur.transport')" http "M1 cursor 的 url server 为 http"
has_out "playwright" "M1 报告同名冲突 playwright"
has_out "custom" "M1 报告同名冲突 custom"
[ -f "$BAK/.mcp.json" ] && [ -f "$BAK/.cursor/mcp.json" ] || { echo "FAIL M4 平台文件应备份"; fail=1; }

# M2：config.toml → mcp_servers.x 进 mcpServers；model 与无法转换的 y 原样进 extraToml
mk m2
mkdir -p "$P/.codex"
cat > "$P/.codex/config.toml" <<'EOF'
model = "o3"
approval_policy = "on-request"

[mcp_servers.x]
command = "x-server"
args = ["--port", "9"]
env = { TOKEN = "abc" }

[mcp_servers.y]
command = "y-server"
startup_timeout_sec = 20

[mcp_servers.z]
url = "https://z.example/mcp"

[mcp_servers.z.http_headers]
Authorization = "Bearer t"

[profiles.fast]
model = "o4-mini"
EOF
ck "$(imp)" 0 "M2 导入"
ck "$(C '.mcpServers.x.command')" x-server "M2 x command"
ck "$(C '.mcpServers.x.args | join(" ")')" "--port 9" "M2 x args"
ck "$(C '.mcpServers.x.env.TOKEN')" abc "M2 x env"
ck "$(C '.mcpServers.z.transport')" http "M2 z 为 http"
ck "$(C '.mcpServers.z.headers.Authorization')" "Bearer t" "M2 z 子表 http_headers → headers"
ck "$(C '.mcpServers | has("y")')" false "M2 y 含未知键，不转换"
X="$(C '.codex.extraToml')"
printf '%s\n' "$X" | grep -qx 'model = "o3"' || { echo "FAIL M2 model 应进 extraToml"; fail=1; }
printf '%s\n' "$X" | grep -qx '\[mcp_servers.y\]' && printf '%s\n' "$X" | grep -qx 'startup_timeout_sec = 20' || { echo "FAIL M2 y 应整段留在 extraToml"; fail=1; }
printf '%s\n' "$X" | grep -qx '\[profiles.fast\]' || { echo "FAIL M2 其他表应留在 extraToml"; fail=1; }
printf '%s\n' "$X" | grep -q 'mcp_servers.x' && { echo "FAIL M2 已转换的 x 不应留在 extraToml"; fail=1; }
has_out "mcp_servers.y" "M2 告警未转换的 y"
[ -f "$BAK/.codex/config.toml" ] || { echo "FAIL M4 config.toml 应备份"; fail=1; }

# M3：settings.json → 去掉 sdlc hooks，保留用户内容；被 git 跟踪时提示 git rm --cached
mk m3
mkdir -p "$P/.claude"
jq -n '{permissions:{allow:["Bash(ls:*)"]},hooks:{
  PreToolUse:[{matcher:"Edit|Write|MultiEdit",hooks:[{type:"command",command:"${CLAUDE_PROJECT_DIR}/.claude/hooks/sdlc-pre-edit-guard.sh"}]}],
  PostToolUse:[{matcher:"Edit|Write",hooks:[{type:"command",command:"${CLAUDE_PROJECT_DIR}/.claude/hooks/sdlc-post-edit-check.sh"},{type:"command",command:"echo mine"}]}]}}' > "$P/.claude/settings.json"
git -C "$P" add .claude/settings.json && git -C "$P" -c user.email=t@t -c user.name=t commit -qm init
ck "$(imp)" 0 "M3 导入"
ck "$(C '.claude.settings.permissions.allow[0]')" "Bash(ls:*)" "M3 permissions 保留"
ck "$(C '.claude.settings.hooks.PreToolUse // [] | length')" 0 "M3 sdlc 守卫被去掉、空组删除"
ck "$(C '[.claude.settings.hooks.PostToolUse[].hooks[].command] | join(",")')" "echo mine" "M3 只保留用户 hook"
has_out "git rm --cached .claude/settings.json" "M3 提示 git rm --cached"
[ -f "$BAK/.claude/settings.json" ] || { echo "FAIL M4 settings.json 应备份"; fail=1; }

# M5：吸收根 CLAUDE.md
mk m5
printf 'MY RULES\nline2\n' > "$P/CLAUDE.md"
( . "$LIB" && sdlc_absorb_root_doc "$P" "$BAK" CLAUDE.md ) >"$TMP/out" 2>&1
grep -qx '## 迁移自 CLAUDE.md' "$P/.agents/AGENTS.md" && grep -qx 'MY RULES' "$P/.agents/AGENTS.md" || { echo "FAIL M5 内容未并入"; fail=1; }
[ -e "$P/CLAUDE.md" ] && { echo "FAIL M5 原文件应删除（由同步重建为软链接）"; fail=1; }
ck "$(cat "$BAK/CLAUDE.md" 2>/dev/null)" "$(printf 'MY RULES\nline2')" "M5 备份"
has_out "整理" "M5 提示人工整理"
ln -s .agents/AGENTS.md "$P/AGENTS.md"
( . "$LIB" && sdlc_absorb_root_doc "$P" "$BAK" AGENTS.md ) >"$TMP/out" 2>&1
ck "$(grep -c '## 迁移自' "$P/.agents/AGENTS.md")" 1 "M5 软链接不被吸收"

[ "$fail" = "0" ] && echo PASS || exit 1
