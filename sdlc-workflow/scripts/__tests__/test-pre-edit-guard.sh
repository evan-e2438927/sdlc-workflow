#!/bin/bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/../.." && pwd)"
HOOK="$SKILL_DIR/templates/hooks/sdlc-pre-edit-guard.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0

ITER="docs/iterations/2026-09-24/001-demo-feature"
setup() { # 重建一个处于 dev 阶段、守卫开启的项目
  rm -rf "$TMP/p"; mkdir -p "$TMP/p/.claude" "$TMP/p/$ITER/tracks" "$TMP/p/apps/server/src/api" "$TMP/p/apps/web/src"
  printf 'EDIT_GUARD=on\n' > "$TMP/p/.claude/.sdlc-config"
  printf '%s\n' "$ITER" > "$TMP/p/.claude/.sdlc-active-iteration"
  printf '{\n  "phase": "approved",\n  "pipeline_stage": "dev"\n}\n' > "$TMP/p/$ITER/status.json"
  cat > "$TMP/p/$ITER/tracks/.allow-backend" <<EOF
# backend allow list
apps/server/src/api/system.ts
apps/server/src/api/system.test.ts
apps/server/src/lib/*
apps/server/src/my file.ts
$ITER/tracks/backend.md
EOF
  printf 'apps/web/src/version-info.tsx\n' > "$TMP/p/$ITER/tracks/.allow-frontend"
}
# run <agent_type|-> <file_path> [PATH override] ；echo 退出码，stderr 存 $TMP/err
run() {
  local at="$1" fp="$2" json
  if [ "$at" = "-" ]; then json=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$fp")
  else json=$(printf '{"agent_type":"%s","tool_name":"Write","tool_input":{"file_path":"%s"}}' "$at" "$fp"); fi
  ( cd "$TMP/p" && printf '%s' "$json" | env ${3:+PATH="$3"} CLAUDE_PROJECT_DIR="$TMP/p" /bin/bash "$HOOK" 2>"$TMP/err" ); echo $?
}
BE="sdlc-backend-dev"; P="$TMP/p"

setup
[ "$(run - "$P/apps/web/src/x.ts")" = "0" ] || { echo "FAIL 1 主 agent 应放行"; fail=1; }
printf 'EDIT_GUARD=off\n' > "$P/.claude/.sdlc-config"
[ "$(run $BE "$P/apps/web/src/x.ts")" = "0" ] || { echo "FAIL 2 EDIT_GUARD=off 应放行"; fail=1; }
setup
[ "$(run general-purpose "$P/apps/web/src/x.ts")" = "0" ] || { echo "FAIL 3 general-purpose 应放行"; fail=1; }
rm "$P/.claude/.sdlc-active-iteration"
[ "$(run $BE "$P/apps/web/src/x.ts")" = "0" ] || { echo "FAIL 4 无标记文件应放行"; fail=1; }
setup; printf '{"pipeline_stage": "merge"}\n' > "$P/$ITER/status.json"
[ "$(run $BE "$P/apps/web/src/x.ts")" = "0" ] || { echo "FAIL 5 非 dev/test-audit 阶段应放行"; fail=1; }
setup; rm "$P/$ITER/tracks/.allow-backend"
[ "$(run $BE "$P/apps/web/src/x.ts")" = "0" ] || { echo "FAIL 6 清单缺失应放行"; fail=1; }
setup
[ "$(run $BE "$P/apps/server/src/api/system.ts")" = "0" ] || { echo "FAIL 7 清单内应放行"; fail=1; }
[ "$(run $BE "$P/apps/web/src/x.ts")" = "2" ] || { echo "FAIL 8 清单外应拒绝"; fail=1; }
grep -q '^\[sdlc guard\] backend 不能写 apps/web/src/x.ts' "$TMP/err" || { echo "FAIL 8 stderr 缺 [sdlc guard] 提示"; cat "$TMP/err"; fail=1; }
[ "$(run sdlc-workflow:sdlc-frontend-dev "$P/apps/server/src/api/system.ts")" = "2" ] || { echo "FAIL 9 带前缀的 frontend 角色应被识别并拒绝"; fail=1; }
[ "$(run sdlc-workflow:sdlc-frontend-dev "$P/apps/web/src/version-info.tsx")" = "0" ] || { echo "FAIL 9b 带前缀角色写清单内应放行"; fail=1; }
[ "$(run $BE "apps/server/src/api/system.test.ts")" = "0" ] || { echo "FAIL 10 相对路径应按项目根解析"; fail=1; }
[ "$(run $BE "$P/apps/server/src/lib/deep/util.ts")" = "0" ] || { echo "FAIL 11 glob 行（* 跨 /）应匹配"; fail=1; }
[ "$(run $BE "$TMP/outside/scratch.txt")" = "0" ] || { echo "FAIL 12 项目根之外应放行"; fail=1; }
[ "$(run $BE "$P/apps/server/src/lib/new-dir/a.ts")" = "0" ] || { echo "FAIL 13a 父目录不存在的新文件（清单内）应放行"; fail=1; }
[ "$(run $BE "$P/apps/web/src/new-dir/a.ts")" = "2" ] || { echo "FAIL 13b 父目录不存在的新文件（清单外）应拒绝"; fail=1; }
[ "$(run $BE "$P/apps/server/src/my file.ts")" = "0" ] || { echo "FAIL 14 含空格的路径应匹配"; fail=1; }
printf 'apps/server/src/api/system.ts\r\n' > "$P/$ITER/tracks/.allow-backend"
[ "$(run $BE "$P/apps/server/src/api/system.ts")" = "0" ] || { echo "FAIL 15 CRLF 清单应匹配"; fail=1; }

# 16/17：无 jq 时走 grep 回退
setup
NOJQ="$TMP/nojq-bin"; mkdir -p "$NOJQ"
for t in bash cat grep sed head tr cut dirname basename env; do ln -sf "$(command -v $t)" "$NOJQ/$t"; done
[ "$(run $BE "$P/apps/server/src/api/system.ts" "$NOJQ")" = "0" ] || { echo "FAIL 16 无 jq 清单内应放行"; fail=1; }
[ "$(run $BE "$P/apps/web/src/x.ts" "$NOJQ")" = "2" ] || { echo "FAIL 17 无 jq 清单外应拒绝"; fail=1; }

# 18/18b：清单里的 [ ] 只按字面匹配，不当作字符类（Next.js/Expo Router 动态路由段，如 [slug]）
setup
mkdir -p "$P/apps/web/app/blog/[slug]" "$P/apps/web/app/blog/s"
printf 'apps/web/app/blog/[slug]/page.tsx\n' > "$P/$ITER/tracks/.allow-frontend"
[ "$(run sdlc-workflow:sdlc-frontend-dev "$P/apps/web/app/blog/[slug]/page.tsx")" = "0" ] || { echo "FAIL 18 [ ] 应按字面匹配，清单内确切路径应放行"; fail=1; }
[ "$(run sdlc-workflow:sdlc-frontend-dev "$P/apps/web/app/blog/s/page.tsx")" = "2" ] || { echo "FAIL 18b [ ] 不应被当作字符类，不应放行其他目录"; fail=1; }

# 19/19b：[slug] 段仍字面匹配，末尾 * 通配符照常生效
printf 'apps/web/app/blog/[slug]/*\n' > "$P/$ITER/tracks/.allow-frontend"
[ "$(run sdlc-workflow:sdlc-frontend-dev "$P/apps/web/app/blog/[slug]/page.tsx")" = "0" ] || { echo "FAIL 19 [slug]/* 应匹配清单内文件"; fail=1; }
[ "$(run sdlc-workflow:sdlc-frontend-dev "$P/apps/web/app/blog/s/page.tsx")" = "2" ] || { echo "FAIL 19b [slug]/* 不应匹配其他目录（[slug] 非字符类）"; fail=1; }

# 20：相对路径应按项目根（而非 hook 运行时的 cwd）解析
setup
json='{"agent_type":"sdlc-backend-dev","tool_name":"Write","tool_input":{"file_path":"apps/server/src/api/system.ts"}}'
rc=$(cd "$P/apps" && printf '%s' "$json" | CLAUDE_PROJECT_DIR="$P" /bin/bash "$HOOK" 2>"$TMP/err"; echo $?)
[ "$rc" = "0" ] || { echo "FAIL 20 相对路径应按项目根（而非 cwd）解析"; fail=1; }

[ "$fail" = "0" ] && echo PASS || exit 1
