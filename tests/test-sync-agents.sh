#!/bin/bash
# sdlc-sync-agents.sh 行为测试。各任务在文件末尾 END 前追加自己的断言段。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$HERE/.." && pwd)"; SKILL_DIR="$REPO_DIR/sdlc-workflow"
SYNC="$SKILL_DIR/scripts/sdlc-sync-agents.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0
ck() { [ "$1" = "$2" ] || { echo "FAIL $3（期望 $2，实际 $1）"; [ -s "$TMP/out" ] && sed 's/^/    out: /' "$TMP/out" | head -20; fail=1; }; }
has_out() { grep -qF -- "$1" "$TMP/out" || { echo "FAIL $2：输出缺少「$1」"; sed 's/^/    out: /' "$TMP/out" | head -20; fail=1; }; }
# run [args...]：执行同步脚本，输出存 $TMP/out，回显退出码
run() { bash "$SYNC" "$@" >"$TMP/out" 2>&1; echo $?; }
link_is() { [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ] || { echo "FAIL $3：$1 应为指向 $2 的软链接（实际 $(readlink "$1" 2>/dev/null || echo 非链接)）"; fail=1; }; }
# mk <name>：新建一个已初始化（最小）的临时 git 项目，设置 $P
mk() {
  P="$TMP/$1"; rm -rf "$P"; mkdir -p "$P/.agents/skills/alpha" "$P/.agents/skills/beta" "$P/.agents/skills/notes"
  git -C "$P" init -q
  printf '# rules\n' > "$P/.agents/AGENTS.md"
  printf '{}\n' > "$P/.agents/config.json"
  printf -- '---\nname: alpha\ndescription: a\n---\n' > "$P/.agents/skills/alpha/SKILL.md"
  printf -- '---\nname: beta\ndescription: b\n---\n' > "$P/.agents/skills/beta/SKILL.md"
  printf 'node_modules/\n' > "$P/.gitignore"
}
snapshot() { (cd "$P" && find . -path ./.git -prune -o \( -type f -o -type l \) -print | sort | while IFS= read -r f; do
  if [ -L "$f" ]; then echo "$f -> $(readlink "$f")"; else echo "$f $(cksum < "$f")"; fi; done); }

# ── Task 4：软链接 / hooks / .gitignore 托管块 / --check ──
ck "$(run)" 2 "S1 缺少项目根参数"
ck "$(run --bogus "$TMP")" 2 "S1b 未知参数"
mkdir -p "$TMP/bare"
ck "$(run "$TMP/bare")" 2 "S2 未初始化项目"

mk s3
ck "$(run "$P")" 0 "S3 写模式"
link_is "$P/AGENTS.md" ".agents/AGENTS.md" "S3 根 AGENTS.md"
link_is "$P/CLAUDE.md" ".agents/AGENTS.md" "S3 根 CLAUDE.md"
link_is "$P/.claude/skills/alpha" "../../.agents/skills/alpha" "S3 skill alpha"
link_is "$P/.claude/skills/beta" "../../.agents/skills/beta" "S3 skill beta"
[ -e "$P/.claude/skills/notes" ] && { echo "FAIL S3 无 SKILL.md 的目录不应建链接"; fail=1; }
for h in sdlc-hook-lib.sh sdlc-pre-edit-guard.sh sdlc-post-edit-check.sh; do
  cmp -s "$P/.agents/hooks/$h" "$SKILL_DIR/templates/hooks/$h" || { echo "FAIL S3 hooks/$h 未同步"; fail=1; }
done
grep -qx '# >>> sdlc generated >>>' "$P/.gitignore" && grep -qx '# <<< sdlc generated <<<' "$P/.gitignore" || { echo "FAIL S3 缺托管块标记"; fail=1; }
for e in .claude/settings.json .mcp.json .cursor/mcp.json .codex/config.toml .codex/hooks.json .agents/.sdlc-config .agents/.sdlc-config.local .agents/.sdlc-active-iteration .agents/.backup/; do
  grep -qxF "$e" "$P/.gitignore" || { echo "FAIL S3 托管块缺 $e"; fail=1; }
done
for f in AGENTS.md CLAUDE.md .claude/skills/alpha .agents/hooks/sdlc-pre-edit-guard.sh .agents/config.json; do
  git -C "$P" check-ignore -q "$f" && { echo "FAIL S3 $f 不应被 gitignore"; fail=1; }
done
git -C "$P" check-ignore -q .agents/.sdlc-config || { echo "FAIL S3 .agents/.sdlc-config 应被忽略"; fail=1; }

before="$(snapshot)"
ck "$(run "$P")" 0 "S4 第二次同步"
grep -q '✔' "$TMP/out" && { echo "FAIL S4 第二次同步不应有变更"; cat "$TMP/out"; fail=1; }
ck "$(snapshot)" "$before" "S4 第二次同步后文件不变"
ck "$(run --check "$P")" 0 "S4 --check 干净"

rm "$P/.claude/skills/alpha"; echo '# hacked' >> "$P/.agents/hooks/sdlc-post-edit-check.sh"
perl -0pi -e 's/\.mcp\.json\n//' "$P/.gitignore"
ck "$(run --check "$P")" 1 "S5 --check 发现漂移"
has_out ".claude/skills/alpha" "S5 列出缺失链接"
has_out ".agents/hooks/sdlc-post-edit-check.sh" "S5 列出过期 hook"
has_out ".gitignore" "S5 列出托管块漂移"
[ -L "$P/.claude/skills/alpha" ] && { echo "FAIL S5 --check 不应写入"; fail=1; }
ck "$(run "$P")" 0 "S5 写模式修复"
ck "$(run --check "$P")" 0 "S5 修复后 --check 干净"

mk s6
mkdir -p "$P/web" "$P/api" "$P/node_modules/pkg" "$P/.hidden"
printf '# web\n' > "$P/web/AGENTS.md"; printf '# api\n' > "$P/api/AGENTS.md"; printf 'MINE\n' > "$P/api/CLAUDE.md"
printf '# dep\n' > "$P/node_modules/pkg/AGENTS.md"; printf '# h\n' > "$P/.hidden/AGENTS.md"
ck "$(run "$P")" 1 "S6 有冲突时写模式退出 1"
link_is "$P/web/CLAUDE.md" "AGENTS.md" "S6 子目录 CLAUDE.md"
ck "$(cat "$P/api/CLAUDE.md")" "MINE" "S6 实体 CLAUDE.md 不被覆盖"
has_out "api/CLAUDE.md" "S6 写模式提示冲突"
[ -e "$P/node_modules/pkg/CLAUDE.md" ] && { echo "FAIL S6 node_modules 不应处理"; fail=1; }
[ -e "$P/.hidden/CLAUDE.md" ] && { echo "FAIL S6 . 开头目录不应处理"; fail=1; }
ck "$(run --check "$P")" 1 "S6 --check 报冲突"
has_out "conflict" "S6 --check 标为 conflict"

mk s7
mkdir -p "$P/.claude/skills/own"; printf 'x\n' > "$P/.claude/skills/own/SKILL.md"
ln -s ../../.agents/skills/gone "$P/.claude/skills/gone"
ln -s /elsewhere/thing "$P/.claude/skills/foreign"
ck "$(run "$P")" 0 "S7 写模式"
[ -L "$P/.claude/skills/gone" ] && { echo "FAIL S7 悬空 skill 链接应删除"; fail=1; }
[ -f "$P/.claude/skills/own/SKILL.md" ] || { echo "FAIL S7 用户自有 skill 目录被动"; fail=1; }
[ -L "$P/.claude/skills/foreign" ] || { echo "FAIL S7 非 .agents 链接不应动"; fail=1; }

mk s8
mkdir -p "$P/.agents/skills/sdlc-workflow/agents"
printf -- '---\nname: sdlc-workflow\n---\n' > "$P/.agents/skills/sdlc-workflow/SKILL.md"
for r in backend frontend test; do printf -- '---\nname: sdlc-%s-dev\n---\n' "$r" > "$P/.agents/skills/sdlc-workflow/agents/sdlc-$r-dev.md"; done
ck "$(run "$P")" 0 "S8 写模式"
for r in backend frontend test; do
  link_is "$P/.claude/agents/sdlc-$r-dev.md" "../../.agents/skills/sdlc-workflow/agents/sdlc-$r-dev.md" "S8 agent $r"
  grep -q "name: sdlc-$r-dev" "$P/.claude/agents/sdlc-$r-dev.md" || { echo "FAIL S8 agent $r 不可读"; fail=1; }
done
mk s8b
ck "$(run "$P")" 0 "S8b 无项目内核心"
[ -e "$P/.claude/agents" ] && { echo "FAIL S8b 无项目内核心时不应生成 agents"; fail=1; }

mk s9
printf '.agents/AGENTS.md' > "$P/CLAUDE.md"
ck "$(run --check "$P")" 1 "S9 软链接被检出为文本文件"
has_out "core.symlinks" "S9 给出 Windows 软链接提示"

mk s10
printf 'node_modules/\n# >>> sdlc generated >>>\nold-entry\n# <<< sdlc generated <<<\ndist/\n' > "$P/.gitignore"
ck "$(run "$P")" 0 "S10 写模式"
grep -qx 'node_modules/' "$P/.gitignore" && grep -qx 'dist/' "$P/.gitignore" || { echo "FAIL S10 块外用户行丢失"; fail=1; }
grep -qx 'old-entry' "$P/.gitignore" && { echo "FAIL S10 托管块未整块重写"; fail=1; }
ck "$(grep -c '^# >>> sdlc generated >>>$' "$P/.gitignore")" 1 "S10 托管块只出现一次"

# ── Task 5：config.json → 平台文件 ──
mk p1
cp "$SKILL_DIR/templates/config.json.tpl" "$P/.agents/config.json"
ck "$(run "$P")" 0 "P1 写模式"
for f in .claude/settings.json .mcp.json .cursor/mcp.json .codex/config.toml .codex/hooks.json; do
  [ -f "$P/$f" ] || { echo "FAIL P1 缺少 $f"; fail=1; }
done
ck "$(jq -r '[.hooks.PreToolUse[].hooks[].command] | map(select(test("sdlc-pre-edit-guard"))) | length' "$P/.claude/settings.json")" 1 "P1 settings 有越界守卫"
ck "$(jq -r '[.hooks.PostToolUse[].hooks[].command] | map(select(test("sdlc-post-edit-check"))) | length' "$P/.claude/settings.json")" 1 "P1 settings 有编辑后检查"
ck "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$P/.claude/settings.json")" 'bash "${CLAUDE_PROJECT_DIR}/.agents/hooks/sdlc-pre-edit-guard.sh"' "P1 守卫命令"
ck "$(jq -r '.hooks | keys | join(",")' "$P/.codex/hooks.json")" "PostToolUse" "P1 codex hooks 只有编辑后检查"
ck "$(jq -r '.hooks.PostToolUse[0].matcher' "$P/.codex/hooks.json")" "apply_patch|Edit|Write" "P1 codex matcher"
jq -r '.hooks.PostToolUse[0].hooks[0].command' "$P/.codex/hooks.json" | grep -q 'git rev-parse --show-toplevel.*/.agents/hooks/sdlc-post-edit-check.sh' || { echo "FAIL P1 codex hook 命令应定位项目根"; fail=1; }
ck "$(jq -r '.mcpServers.playwright.type' "$P/.mcp.json")" stdio "P1 .mcp.json type"
ck "$(jq -r '.mcpServers.playwright.args[0]' "$P/.mcp.json")" "@playwright/mcp@latest" "P1 .mcp.json args"
ck "$(jq -r '.mcpServers.playwright | has("transport")' "$P/.cursor/mcp.json")" false "P1 cursor 无 transport"
grep -qx '\[mcp_servers.playwright\]' "$P/.codex/config.toml" || { echo "FAIL P1 toml 缺 playwright 表"; fail=1; }
grep -qx 'command = "npx"' "$P/.codex/config.toml" || { echo "FAIL P1 toml command"; fail=1; }
grep -qx 'args = \["@playwright/mcp@latest"\]' "$P/.codex/config.toml" || { echo "FAIL P1 toml args"; fail=1; }

mk p2
jq -n '{mcpServers:{
  docs:{transport:"http",url:"https://example.com/mcp",headers:{Authorization:"Bearer x"}},
  "my.tool":{transport:"stdio",command:"node",args:["s.js","--flag"],env:{API_KEY:"k\"q"}}},
  claude:{settings:{permissions:{allow:["Bash(ls:*)"]},hooks:{PostToolUse:[{matcher:"Write",hooks:[{type:"command",command:"echo mine"}]}]}}},
  codex:{extraToml:"model = \"o3\"\napproval_policy = \"on-request\"\n"}, cursor:{}}' > "$P/.agents/config.json"
ck "$(run "$P")" 0 "P2 写模式"
ck "$(jq -r '.permissions.allow[0]' "$P/.claude/settings.json")" "Bash(ls:*)" "P2 用户 permissions 保留"
ck "$(jq -r '.hooks.PostToolUse | length' "$P/.claude/settings.json")" 2 "P2 用户 hook 在前、sdlc hook 追加"
ck "$(jq -r '.hooks.PostToolUse[0].hooks[0].command' "$P/.claude/settings.json")" "echo mine" "P2 用户 hook 顺序"
ck "$(jq -r '.mcpServers.docs.type' "$P/.mcp.json")" http "P3 http type"
ck "$(jq -r '.mcpServers.docs.headers.Authorization' "$P/.cursor/mcp.json")" "Bearer x" "P3 cursor headers"
ck "$(jq -r '.mcpServers.docs | has("transport")' "$P/.cursor/mcp.json")" false "P3 cursor 无 transport"
T="$P/.codex/config.toml"
grep -qx 'url = "https://example.com/mcp"' "$T" || { echo "FAIL P3 toml url"; fail=1; }
grep -qx 'http_headers = { Authorization = "Bearer x" }' "$T" || { echo "FAIL P3 toml http_headers"; fail=1; }
grep -qx '\[mcp_servers."my.tool"\]' "$T" || { echo "FAIL P3 特殊名需加引号"; fail=1; }
grep -qx 'env = { API_KEY = "k\\"q" }' "$T" || { echo "FAIL P3 toml env 转义"; cat "$T"; fail=1; }
m="$(grep -n '^model = "o3"$' "$T" | cut -d: -f1)"; t="$(grep -n '^\[mcp_servers\.' "$T" | head -1 | cut -d: -f1)"
[ -n "$m" ] && [ -n "$t" ] && [ "$m" -lt "$t" ] || { echo "FAIL P4 extraToml 应位于 mcp_servers 表之前（model 行 $m，首表 $t）"; fail=1; }

jq '.mcpServers.extra = {transport:"stdio",command:"x"} | .codex.extraToml += "[mcp_servers.extra]\ncommand = \"keep\"\n"' "$P/.agents/config.json" > "$TMP/c.json" && mv "$TMP/c.json" "$P/.agents/config.json"
ck "$(run "$P")" 0 "P4b 写模式"
ck "$(grep -c '^\[mcp_servers.extra\]$' "$T")" 1 "P4b extraToml 中已定义的 server 不重复输出"
grep -qx 'command = "keep"' "$T" || { echo "FAIL P4b 应保留 extraToml 中的定义"; fail=1; }

echo '{"mcpServers":{}}' > "$P/.mcp.json"
ck "$(run --check "$P")" 1 "P5 手改生成文件被发现"
has_out ".mcp.json" "P5 列出 .mcp.json"
ck "$(run "$P")" 0 "P5 写模式恢复"
ck "$(jq -r '.mcpServers.docs.type' "$P/.mcp.json")" http "P5 恢复内容"
before="$(snapshot)"
ck "$(run "$P")" 0 "P6 再次同步"
ck "$(snapshot)" "$before" "P6 无变化"
grep -q '✔' "$TMP/out" && { echo "FAIL P6 不应有变更"; fail=1; }
rm "$P/.agents/config.json"
ck "$(run "$P")" 2 "P7 缺 config.json"
has_out "config.json" "P7 报错指出 config.json"

# ── Task 6：--check-paths ──
mk c1
mkdir -p "$P/docs/iterations" "$P/web/src"; printf 'x\n' > "$P/docs/ok.md"; printf 'x\n' > "$P/web/src/app.ts"
cat > "$P/.agents/AGENTS.md" <<'EOF'
# rules
- see [ok](../docs/ok.md) and [bad](../docs/missing.md)
- dirs: `docs/iterations/` and `docs/gone/`
- skip: [web](https://example.com/a.md) [anchor](#top) `apps/web/src` `.agents/skills/<name>/SKILL.md` `packages/env|api` `src/*.ts` `npm run build` `a b/c.md` `README`
EOF
ck "$(run "$P")" 0 "C0 先同步"
ck "$(run --check-paths "$P")" 1 "C1 失效路径"
has_out "docs/missing.md" "C1 列出失效链接"
has_out "docs/gone/" "C1 列出失效反引号路径"
for ok in docs/ok.md docs/iterations/ example.com '#top' apps/web/src '<name>' 'env|api' 'src/*.ts' 'a b/c.md'; do
  grep -F -- "$ok" "$TMP/out" | grep -q '✗' && { echo "FAIL C2 不应报告 $ok"; fail=1; }
done
printf '# web\nsee [app](src/app.ts) and [nope](src/nope.ts)\n' > "$P/web/AGENTS.md"
ck "$(run "$P")" 0 "C3 子目录同步"
ck "$(run --check-paths "$P")" 1 "C3 子目录失效路径"
has_out "web/AGENTS.md" "C3 指出所在文件"
has_out "src/nope.ts" "C3 列出子目录失效链接"
grep -F 'src/app.ts' "$TMP/out" | grep -q '✗' && { echo "FAIL C3 子目录链接应相对其所在目录解析"; fail=1; }
printf '# rules\n- [ok](../docs/ok.md)\n' > "$P/.agents/AGENTS.md"; printf '# web\n[app](src/app.ts)\n' > "$P/web/AGENTS.md"
ck "$(run --check-paths "$P")" 0 "C4 路径全部有效"

# ── END ──
[ "$fail" = "0" ] && echo PASS || exit 1
