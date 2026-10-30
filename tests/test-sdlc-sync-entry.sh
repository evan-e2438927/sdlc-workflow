#!/bin/bash
# 项目内同步入口 .agents/bin/sdlc-sync：找核心的顺序、参数与退出码透传、项目根与当前目录无关。
# 用假核心（只回显参数的 sdlc-sync-agents.sh）验证解析逻辑。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$HERE/.." && pwd)"; SKILL_DIR="$REPO_DIR/sdlc-workflow"
ENTRY_TPL="$SKILL_DIR/templates/bin/sdlc-sync"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0
ck() { [ "$1" = "$2" ] || { echo "FAIL $3（期望 $2，实际 $1）"; sed 's/^/    out: /' "$TMP/out" | head -5; fail=1; }; }

P="$TMP/proj"; H="$TMP/home"
mkdir -p "$P/.agents/bin" "$P/src/deep" "$H"
cp "$ENTRY_TPL" "$P/.agents/bin/sdlc-sync" 2>/dev/null; chmod +x "$P/.agents/bin/sdlc-sync" 2>/dev/null
ROOT_REAL="$(cd "$P" && pwd -P)"
# fake_core <dir> <label> [exit-code]：在 <dir>/scripts/ 放一个回显「label 参数…」的假同步脚本
fake_core() {
  mkdir -p "$1/scripts"
  printf '#!/bin/bash\necho "%s $*"\nexit %s\n' "$2" "${3:-0}" > "$1/scripts/sdlc-sync-agents.sh"
}
# run [args...]：在子目录里执行入口，隔离 HOME 与 SDLC_CORE；输出存 $TMP/out，回显退出码
run() { (cd "$P/src/deep" && env -u SDLC_CORE HOME="$H" "$P/.agents/bin/sdlc-sync" "$@" >"$TMP/out" 2>&1); echo $?; }

[ -x "$P/.agents/bin/sdlc-sync" ] || { echo "FAIL E0 缺少模板 templates/bin/sdlc-sync"; exit 1; }

ck "$(run)" 2 "E1 找不到核心时退出码"
grep -qF 'npx skills add evan-e2438927/sdlc-workflow --skill sdlc-workflow' "$TMP/out" || { echo "FAIL E1 应提示安装命令"; fail=1; }

C="$H/.claude/plugins/cache/sdlc-workflow/sdlc-full"
fake_core "$C/1.0.0/sdlc-workflow" plugin-1.0.0
fake_core "$C/1.1.0/sdlc-workflow" plugin-1.1.0
touch -t 202601010000 "$C/1.0.0/sdlc-workflow/scripts/sdlc-sync-agents.sh"
ck "$(run)" 0 "E2 插件缓存"
grep -q '^plugin-1.1.0 ' "$TMP/out" || { echo "FAIL E2 多个插件版本应取最近修改的"; fail=1; }

fake_core "$H/.claude/skills/sdlc-workflow" global
ck "$(run)" 0 "E3 全局手动安装"
grep -q '^global ' "$TMP/out" || { echo "FAIL E3 ~/.claude/skills/sdlc-workflow 应优先于插件缓存"; fail=1; }

fake_core "$P/.agents/skills/sdlc-workflow" project
ck "$(run --check)" 0 "E4 项目内安装"
grep -q '^project ' "$TMP/out" || { echo "FAIL E4 项目内 .agents/skills/sdlc-workflow 应优先"; fail=1; }

# E5：参数透传，项目根为入口所在项目（与当前目录无关）
line="$(head -1 "$TMP/out")"
ck "$line" "project --check $ROOT_REAL" "E5 参数与项目根透传"

fake_core "$TMP/explicit" explicit
rc="$( (cd "$P/src" && env HOME="$H" SDLC_CORE="$TMP/explicit" "$P/.agents/bin/sdlc-sync" --check-paths >"$TMP/out" 2>&1); echo $?)"
ck "$rc" 0 "E6 SDLC_CORE"
grep -q '^explicit --check-paths ' "$TMP/out" || { echo "FAIL E6 环境变量 SDLC_CORE 应最优先"; fail=1; }

fake_core "$P/.agents/skills/sdlc-workflow" project 1
ck "$(run)" 1 "E7 退出码透传"

[ "$fail" = "0" ] && echo PASS || exit 1
