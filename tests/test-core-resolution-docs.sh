#!/bin/bash
# 核心目录 SDLC_CORE：只在核心 SKILL.md 定义一次（同级 ../sdlc-workflow 优先，其次 ${CLAUDE_PLUGIN_ROOT}），
# 所有脚本调用经它并一律 `bash <path>`；缺少核心 skill 时有明确报错。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$HERE/.." && pwd)"; SKILL_DIR="$REPO_DIR/sdlc-workflow"
CORE_MD="$SKILL_DIR/SKILL.md"
ERR='缺少核心 skill sdlc-workflow，请执行 `npx skills add evan-e2438927/sdlc-workflow --skill sdlc-workflow`'
MARK="$(mktemp -d)"; trap 'rm -rf "$MARK"' EXIT
fail=0
SUBS="$(ls "$REPO_DIR"/skills/sdlc-*/SKILL.md | grep -v '/skills/sdlc-workflow/')"

# R1：每处 CLAUDE_PLUGIN_ROOT 都在同一行带同级目录回退
for f in $SUBS "$CORE_MD"; do
  grep -n 'CLAUDE_PLUGIN_ROOT' "$f" | grep -v '\.\./sdlc-workflow' | while IFS= read -r l; do
    echo "FAIL R1 ${f#"$REPO_DIR"/}:$l 缺少同级 ../sdlc-workflow 回退"; echo x >> "$MARK/r1"
  done
done
[ -f "$MARK/r1" ] && fail=1

# R2：核心 SKILL.md 恰好一处定义，含回退顺序与报错
n="$(grep -c 'SDLC_CORE="' "$CORE_MD")"
[ "$n" = "1" ] || { echo "FAIL R2 核心 SKILL.md 中 SDLC_CORE 只能在一行定义（同级 + 兜底在同一行），实际 $n 行"; fail=1; }
grep -q 'SDLC_CORE="\$SKILL_BASE/\.\./sdlc-workflow".*SDLC_CORE="\${CLAUDE_PLUGIN_ROOT' "$CORE_MD" \
  || { echo "FAIL R2 定义行应先同级 ../sdlc-workflow、再 \${CLAUDE_PLUGIN_ROOT}/sdlc-workflow"; fail=1; }
grep -qF "$ERR" "$CORE_MD" || { echo "FAIL R2 核心 SKILL.md 缺少报错文案"; fail=1; }
grep -q '^## 核心目录（SDLC_CORE）' "$CORE_MD" || { echo "FAIL R2 缺少「核心目录（SDLC_CORE）」小节"; fail=1; }

# R3：每个子 skill 都说明如何找核心，并在缺失时报错
for f in $SUBS; do
  grep -qF "$ERR" "$f" || { echo "FAIL R3 ${f#"$REPO_DIR"/} 缺少核心缺失报错"; fail=1; }
  grep -q '核心目录（SDLC_CORE）' "$f" || { echo "FAIL R3 ${f#"$REPO_DIR"/} 未引用核心目录定义"; fail=1; }
done

# R4：脚本调用一律 bash "$SDLC_CORE/scripts/…"；"$SDLC_STATUS" 调用前有 bash
for f in $SUBS "$CORE_MD" "$SKILL_DIR"/references/*.md; do
  grep -nE 'scripts/[a-z-]+\.sh' "$f" | grep -vF 'bash "$SDLC_CORE/scripts/' | grep -v 'SDLC_CORE="' \
    | grep -v 'SDLC_STATUS="$SDLC_CORE/scripts/sdlc-status.sh"' | grep -vE '(│|├|└)' | while IFS= read -r l; do
      echo "FAIL R4 ${f#"$REPO_DIR"/}:$l 脚本调用应为 bash \"\$SDLC_CORE/scripts/…\""; echo x >> "$MARK/r4"
    done
  grep -n '"\$SDLC_STATUS"' "$f" | grep -v 'bash "\$SDLC_STATUS"' | while IFS= read -r l; do
    echo "FAIL R4 ${f#"$REPO_DIR"/}:$l 应为 bash \"\$SDLC_STATUS\""; echo x >> "$MARK/r4"
  done
done
[ -f "$MARK/r4" ] && fail=1

[ "$fail" = "0" ] && echo PASS || exit 1
