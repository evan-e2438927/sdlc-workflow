#!/bin/bash
# update 把旧版（.claude/ 布局）项目迁移到 .agents/：内容不丢、平台配置导入、可重复执行。
# 旧项目用 $SDLC_LEGACY_REF（默认 feat/status-machine）版本的 init 生成；该 ref 不存在时跳过。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$HERE/.." && pwd)"; SKILL_DIR="$REPO_DIR/sdlc-workflow"
REF="${SDLC_LEGACY_REF:-feat/status-machine}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0
ck() { [ "$1" = "$2" ] || { echo "FAIL $3（期望 $2，实际 $1）"; fail=1; }; }
has_out() { grep -qF -- "$1" "$TMP/out" || { echo "FAIL $2：输出缺少「$1」"; fail=1; }; }

if ! git -C "$REPO_DIR" rev-parse --verify -q "$REF^{commit}" >/dev/null; then
  echo "SKIP: 找不到旧版 ref $REF"; exit 0
fi
mkdir -p "$TMP/legacy"
git -C "$REPO_DIR" archive "$REF" sdlc-workflow | tar -x -C "$TMP/legacy"

P="$TMP/proj"; mkdir -p "$P"; git -C "$P" init -q
bash "$TMP/legacy/sdlc-workflow/scripts/init-project.sh" "$P" >/dev/null 2>&1 || { echo "FAIL 旧版 init 失败"; exit 1; }
[ -f "$P/.claude/CLAUDE.md" ] || { echo "FAIL 旧版 init 未生成 .claude/CLAUDE.md"; exit 1; }
# 用户内容：改规则文件、自定义 skill、已提交的 settings.json（含 permissions）、手写 .mcp.json 与 .codex/config.toml
printf '\n## 团队约定\n- 见 `.claude/ARCHITECTURE.md` 与 `.claude/rules/workflow-rules.md`\n- 全局规范在 `~/.claude/CLAUDE.md`\n' >> "$P/.claude/CLAUDE.md"
printf '\n## 模块\n- billing\n' >> "$P/.claude/ARCHITECTURE.md"
printf '# baseline\n' > "$P/.claude/PROJECT_BASELINE.md"
mkdir -p "$P/.claude/skills/my-skill"
printf -- '---\nname: my-skill\ndescription: team skill, see .claude/CODING_GUIDELINES.md\n---\nbody\n' > "$P/.claude/skills/my-skill/SKILL.md"
perl -pi -e 's/^TEST_FRAMEWORK=.*/TEST_FRAMEWORK=vitest/' "$P/.claude/.sdlc-config"
jq '.permissions = {allow: ["Bash(npm test:*)"]}' "$P/.claude/settings.json" > "$TMP/s.json" && mv "$TMP/s.json" "$P/.claude/settings.json"
jq -n '{mcpServers: {custom: {type: "stdio", command: "custom-mcp", args: ["--stdio"]}}}' > "$P/.mcp.json"
mkdir -p "$P/.codex"
printf 'model = "o3"\n\n[mcp_servers.x]\ncommand = "x-server"\nargs = ["--x"]\n' > "$P/.codex/config.toml"
git -C "$P" add -A && git -C "$P" -c user.email=t@t -c user.name=t commit -qm legacy
mkdir -p "$TMP/before" && cp -R "$P/.claude/." "$TMP/before/"

bash "$SKILL_DIR/scripts/update-project.sh" "$P" >"$TMP/out" 2>&1; ck "$?" 0 "U0 update 退出码"

# U1：规则文件都在 .agents/，.claude/CLAUDE.md 不再是实体文件
for f in AGENTS.md ARCHITECTURE.md SECURITY.md CODING_GUIDELINES.md PROJECT_BASELINE.md rules/workflow-rules.md .sdlc-config; do
  [ -f "$P/.agents/$f" ] || { echo "FAIL U1 缺少 .agents/$f"; fail=1; }
done
[ -f "$P/.claude/CLAUDE.md" ] && [ ! -L "$P/.claude/CLAUDE.md" ] && { echo "FAIL U1 .claude/CLAUDE.md 仍是实体文件"; fail=1; }
for f in ARCHITECTURE.md SECURITY.md CODING_GUIDELINES.md PROJECT_BASELINE.md .sdlc-config; do
  [ -e "$P/.claude/$f" ] && { echo "FAIL U1 .claude/$f 未移走"; fail=1; }
done
ls "$P/.claude/hooks"/sdlc-*.sh >/dev/null 2>&1 && { echo "FAIL U1 旧 hooks 未清理"; fail=1; }
grep -qx 'TEST_FRAMEWORK=vitest' "$P/.agents/.sdlc-config" || { echo "FAIL U1 .sdlc-config 用户值丢失"; fail=1; }

# U2：用户内容逐文件一致（路径改写除外；workflow-rules.md 为 sdlc 托管文件，按模板刷新，不比较）
rewrite() { perl -pe 's#(?<!~/)\.claude/CLAUDE\.md#.agents/AGENTS.md#g; s#(?<!~/)\.claude/(ARCHITECTURE|SECURITY|CODING_GUIDELINES|PROJECT_BASELINE|EXISTING_STRUCTURE|TEST_BASELINE)\.md#.agents/$1.md#g; s#(?<!~/)\.claude/(rules|skills|hooks)/#.agents/$1/#g; s#(?<!~/)\.claude/\.sdlc-(config|active-iteration)#.agents/.sdlc-$1#g' "$1"; }
for pair in CLAUDE.md:AGENTS.md ARCHITECTURE.md:ARCHITECTURE.md SECURITY.md:SECURITY.md CODING_GUIDELINES.md:CODING_GUIDELINES.md \
            PROJECT_BASELINE.md:PROJECT_BASELINE.md skills/my-skill/SKILL.md:skills/my-skill/SKILL.md skills/README.md:skills/README.md; do
  old="${pair%%:*}"; new="${pair#*:}"
  if ! diff <(rewrite "$TMP/before/$old") "$P/.agents/$new" >"$TMP/diff"; then
    echo "FAIL U2 .claude/$old → .agents/$new 内容不一致："; sed 's/^/    /' "$TMP/diff" | head -10; fail=1
  fi
done
grep -qF '`~/.claude/CLAUDE.md`' "$P/.agents/AGENTS.md" || { echo "FAIL U2 全局 ~/.claude/ 路径不应被改写"; fail=1; }
BAK="$(ls -d "$P"/.agents/.backup/*/ 2>/dev/null | head -1)"
[ -n "$BAK" ] && [ -f "$BAK/.claude/CLAUDE.md" ] && [ -f "$BAK/.claude/ARCHITECTURE.md" ] || { echo "FAIL U2 原规则文件未备份到 .agents/.backup/"; fail=1; }

# U3：自定义 skill 移到 .agents/skills/，.claude/skills/ 下为软链接
[ -f "$P/.agents/skills/my-skill/SKILL.md" ] || { echo "FAIL U3 自定义 skill 未移动"; fail=1; }
[ -L "$P/.claude/skills/my-skill" ] && [ "$(readlink "$P/.claude/skills/my-skill")" = "../../.agents/skills/my-skill" ] || { echo "FAIL U3 .claude/skills/my-skill 应为软链接"; fail=1; }
[ -L "$P/CLAUDE.md" ] && [ -L "$P/AGENTS.md" ] || { echo "FAIL U3 根入口软链接缺失"; fail=1; }

# U4：同步一致
bash "$SKILL_DIR/scripts/sdlc-sync-agents.sh" --check "$P" >"$TMP/chk" 2>&1; ck "$?" 0 "U4 --check"

# U5：平台配置导入与重新生成
ck "$(jq -r '.mcpServers.custom.command' "$P/.agents/config.json")" custom-mcp "U5 custom 进入 config.json"
ck "$(jq -r '.mcpServers.custom.command' "$P/.mcp.json")" custom-mcp "U5 custom 在 .mcp.json"
ck "$(jq -r '.mcpServers.custom.command' "$P/.cursor/mcp.json")" custom-mcp "U5 custom 在 .cursor/mcp.json"
grep -qx '\[mcp_servers.custom\]' "$P/.codex/config.toml" || { echo "FAIL U5 custom 不在 .codex/config.toml"; fail=1; }
grep -qx '\[mcp_servers.x\]' "$P/.codex/config.toml" || { echo "FAIL U5 x 不在 .codex/config.toml"; fail=1; }
grep -qx 'model = "o3"' "$P/.codex/config.toml" || { echo "FAIL U5 model 不在 .codex/config.toml"; fail=1; }
for f in .mcp.json .codex/config.toml .claude/settings.json; do
  [ -f "$BAK/$f" ] || { echo "FAIL U5 $f 未备份"; fail=1; }
done
has_out "git rm --cached .claude/settings.json" "U5 提示 git rm --cached"
# U6：用户 settings 保留，sdlc hooks 指向 .agents/
ck "$(jq -r '.claude.settings.permissions.allow[0]' "$P/.agents/config.json")" "Bash(npm test:*)" "U6 permissions 进入 config.json"
ck "$(jq -r '.permissions.allow[0]' "$P/.claude/settings.json")" "Bash(npm test:*)" "U6 permissions 在生成的 settings.json"
grep -q '\.claude/hooks' "$P/.claude/settings.json" && { echo "FAIL U6 settings 仍引用 .claude/hooks"; fail=1; }

# U7：再次 update 只做同步与配置键迁移
extra1="$(jq -r '.codex.extraToml' "$P/.agents/config.json")"; st1="$(git -C "$P" status --porcelain)"
bash "$SKILL_DIR/scripts/update-project.sh" "$P" >"$TMP/out2" 2>&1; ck "$?" 0 "U7 再次 update"
ck "$(jq -r '.codex.extraToml' "$P/.agents/config.json")" "$extra1" "U7 extraToml 不叠加"
ck "$(git -C "$P" status --porcelain)" "$st1" "U7 工作区无新变化"
ck "$(ls -d "$P"/.agents/.backup/*/ | wc -l | tr -d ' ')" 1 "U7 新布局不再备份迁移"

[ "$fail" = "0" ] && echo PASS || exit 1
