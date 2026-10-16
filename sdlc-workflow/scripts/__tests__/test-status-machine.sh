#!/bin/bash
# sdlc-status.sh 行为测试：phase 迁移校验、history、旧格式兼容、标记文件清理、find-latest。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/../.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/sdlc-status.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0
P="$TMP/p"
ITER="docs/iterations/2026-10-16/001-demo-feature"
ISO='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:[0-9]{2}$'

setup() { rm -rf "$P"; mkdir -p "$P/.claude" "$P/$ITER"; }
# run <args...>：在项目根执行脚本，回显退出码，stdout 存 $TMP/out，stderr 存 $TMP/err
run() { ( cd "$P" && CLAUDE_PROJECT_DIR="$P" /bin/bash "$SCRIPT" "$@" >"$TMP/out" 2>"$TMP/err" ); echo $?; }
# run_path <PATH> <args...>
run_path() { local path="$1"; shift; ( cd "$P" && PATH="$path" CLAUDE_PROJECT_DIR="$P" /bin/bash "$SCRIPT" "$@" >"$TMP/out" 2>"$TMP/err" ); echo $?; }
st() { jq -r "$1" "$P/$ITER/status.json"; }
ck() { [ "$1" = "$2" ] || { echo "FAIL $3（期望 $2，实际 $1）"; [ -s "$TMP/err" ] && sed 's/^/    stderr: /' "$TMP/err"; fail=1; }; }
errhas() { grep -qF -- "$1" "$TMP/err" || { echo "FAIL $2：stderr 缺少「$1」"; sed 's/^/    stderr: /' "$TMP/err"; fail=1; }; }

# ── transition ──
setup
ck "$(run transition "$ITER" pending_review --by proposal)" 0 "T1 创建 pending_review"
ck "$(st .phase)" pending_review "T1 phase"
ck "$(st .mode)" proposal "T1 mode"
ck "$(st .iter_dir)" "$ITER" "T1 iter_dir"
ck "$(st '.history|length')" 1 "T1 history 长度"
ck "$(st '.history[0].from')" null "T1 history[0].from"
ck "$(st '.history[0].to')" pending_review "T1 history[0].to"
ck "$(st '.history[0].by')" proposal "T1 history[0].by"
st .proposal_at | grep -qE "$ISO" || { echo "FAIL T1 proposal_at 非 ISO8601: $(st .proposal_at)"; fail=1; }

setup
ck "$(run transition "$ITER" approved --by apply)" 1 "T2 无文件直接 approved 应拒绝"
errhas "当前 （无），不能迁移到 approved" "T2"
errhas "允许：pending_review" "T2"

setup
run transition "$ITER" pending_review --by proposal >/dev/null
for step in "approved apply" "applied apply" "qa_failed qa" "applied apply" "qa_passed qa" "accepted accept" "pr_created pr"; do
  set -- $step
  ck "$(run transition "$ITER" "$1" --by "$2")" 0 "T3 迁移到 $1"
done
ck "$(st '.history|length')" 8 "T3 history 长度"
ck "$(st '.history[1].from')" pending_review "T3 history[1].from"
for k in reviewed_at applied_at qa_failed_at qa_passed_at accepted_at pr_created_at; do
  st ".$k" | grep -qE "$ISO" || { echo "FAIL T3 $k 非 ISO8601: $(st ".$k")"; fail=1; }
done
ck "$(st .reviewer)" apply "T3 reviewer"
ck "$(st .phase)" pr_created "T3 终态"

# T4 跳过 qa；各 phase → rejected
setup
run transition "$ITER" pending_review --by proposal >/dev/null
run transition "$ITER" approved --by apply >/dev/null
run transition "$ITER" applied --by apply >/dev/null
ck "$(run transition "$ITER" accepted --by accept)" 0 "T4 applied→accepted（跳过 qa）"
for path in "approved" "approved applied" "approved applied qa_failed" "approved applied qa_passed"; do
  setup; run transition "$ITER" pending_review --by proposal >/dev/null
  for ph in $path; do run transition "$ITER" "$ph" --by x >/dev/null; done
  ck "$(run transition "$ITER" rejected --by user)" 0 "T4 ${path##* }→rejected"
done

# T5 非法迁移
setup; run transition "$ITER" pending_review --by proposal >/dev/null
ck "$(run transition "$ITER" accepted --by accept)" 1 "T5 pending_review→accepted 应拒绝"; errhas "允许：" "T5"
setup; printf '{"phase":"pr_created"}\n' > "$P/$ITER/status.json"
ck "$(run transition "$ITER" rejected --by user)" 1 "T5 pr_created→rejected 应拒绝"
setup; printf '{"phase":"rejected"}\n' > "$P/$ITER/status.json"
ck "$(run transition "$ITER" pending_review --by proposal)" 1 "T5 rejected→pending_review 应拒绝"

# T6 flags 只在创建时写入
setup
ck "$(run transition "$ITER" pending_review --by doit --flags '{"review":true,"qa":true,"agents":"auto"}')" 0 "T6 doit 创建"
ck "$(st .mode)" doit "T6 mode"
ck "$(st .flags.qa)" true "T6 flags.qa"
run transition "$ITER" approved --by doit --flags '{"qa":false}' >/dev/null
ck "$(st .flags.qa)" true "T6 非创建时 flags 不覆盖"

# T7 用法错误
setup
ck "$(run transition "$ITER" pending_review --by apply)" 2 "T7 创建时 --by 非 proposal/doit/mini"
ck "$(run transition "$ITER" pending_review --by doit --flags 'not-json')" 2 "T7 --flags 非法 JSON"
[ -f "$P/$ITER/status.json" ] && { echo "FAIL T7 用法错误时不应创建文件"; fail=1; }

# T8 旧格式兼容
setup
printf '{"phase":"approved","reviewed_at":1760000000,"tracks":{"backend":"done"}}\n' > "$P/$ITER/status.json"
ck "$(run transition "$ITER" applied --by apply)" 0 "T8 旧格式迁移"
ck "$(st '.history|length')" 1 "T8 history 从空开始"
ck "$(st .reviewed_at)" 1760000000 "T8 旧时间戳保留"
ck "$(st .tracks.backend)" done "T8 其余字段保留"
ck "$(st '.mode // "absent"')" absent "T8 不补 mode"

# T9 rejected 清理标记文件
setup; run transition "$ITER" pending_review --by proposal >/dev/null
printf '%s\n' "$ITER" > "$P/.claude/.sdlc-active-iteration"
ck "$(run transition "$ITER" rejected --by user)" 0 "T9 rejected"
[ -f "$P/.claude/.sdlc-active-iteration" ] && { echo "FAIL T9 指向本迭代的标记文件应删除"; fail=1; }
errhas "工作区代码未回滚" "T9"
setup; run transition "$ITER" pending_review --by proposal >/dev/null
printf '%s\n' "docs/iterations/2026-10-16/002-other-feature" > "$P/.claude/.sdlc-active-iteration"
run transition "$ITER" rejected --by user >/dev/null
[ -f "$P/.claude/.sdlc-active-iteration" ] || { echo "FAIL T9 指向其他迭代的标记文件不应删除"; fail=1; }

# T10 缺 jq
setup
mkdir -p "$TMP/bin"
for b in bash date mktemp mv rm cat dirname basename sed grep tr head sort find cp; do
  src="$(command -v "$b")" && ln -sf "$src" "$TMP/bin/$b"
done
ck "$(run_path "$TMP/bin" transition "$ITER" pending_review --by proposal)" 3 "T10 缺 jq"

# T11 note
setup; run transition "$ITER" pending_review --by proposal >/dev/null
run transition "$ITER" approved --by apply >/dev/null
run transition "$ITER" applied --by apply >/dev/null
run transition "$ITER" qa_failed --by qa >/dev/null
run transition "$ITER" applied --by apply --note qa-fix >/dev/null
ck "$(st '.history[-1].note')" qa-fix "T11 note"

# R1 尾部斜杠 / 绝对路径
setup
ck "$(run transition "$ITER/" pending_review --by proposal)" 0 "R1 尾部斜杠"
ck "$(st .iter_dir)" "$ITER" "R1 iter_dir 去掉尾部斜杠"
ck "$(run transition "$P/$ITER" approved --by apply)" 0 "R1 绝对路径"
printf '%s/\n' "$ITER" > "$P/.claude/.sdlc-active-iteration"
run transition "$ITER" rejected --by user >/dev/null
[ -f "$P/.claude/.sdlc-active-iteration" ] && { echo "FAIL R1 带斜杠的标记文件应删除"; fail=1; }

# R2 损坏的 status.json 不被覆盖
setup; printf '{bad' > "$P/$ITER/status.json"
ck "$(run transition "$ITER" approved --by apply)" 2 "R2 损坏文件"
ck "$(cat "$P/$ITER/status.json")" '{bad' "R2 原文件不变"

# R3 未知的当前 phase
setup; printf '{"phase":"in-dev"}\n' > "$P/$ITER/status.json"
ck "$(run transition "$ITER" approved --by apply)" 1 "R3 未知 phase"; errhas "in-dev" "R3"

# R4 目标 phase 拼错
setup; run transition "$ITER" pending_review --by proposal >/dev/null
ck "$(run transition "$ITER" qa_fail --by qa)" 1 "R4 目标拼错"; errhas "允许：approved rejected" "R4"

# R5 不留临时文件
setup; run transition "$ITER" pending_review --by proposal >/dev/null
run transition "$ITER" approved --by apply >/dev/null
ck "$(ls -A "$P/$ITER")" status.json "R5 迭代目录只有 status.json"

# ── find-latest ──
mkiter() { mkdir -p "$P/docs/iterations/$1"; printf '{"phase":"%s"}\n' "$2" > "$P/docs/iterations/$1/status.json"; }
setup; rm -rf "$P/docs"
mkiter 2026-10-15/003-a-feature applied
mkiter 2026-10-16/001-b-fix applied
mkiter 2026-10-16/002-c-feature pending_review
ck "$(run find-latest applied)" 0 "F1 find-latest applied"
ck "$(cat "$TMP/out")" docs/iterations/2026-10-16/001-b-fix "F1 最近的 applied"
run find-latest applied pending_review >/dev/null
ck "$(cat "$TMP/out")" docs/iterations/2026-10-16/002-c-feature "F1 多 phase"
ck "$(run find-latest accepted)" 1 "F2 无命中"
ck "$(cat "$TMP/out")" "" "F2 stdout 为空"
mkdir -p "$P/docs/iterations/2026-10-17/001-broken-fix"; printf '{bad' > "$P/docs/iterations/2026-10-17/001-broken-fix/status.json"
run find-latest applied >/dev/null
ck "$(cat "$TMP/out")" docs/iterations/2026-10-16/001-b-fix "F4 跳过损坏的 status.json"
rm -rf "$P/docs"
ck "$(run find-latest applied)" 1 "F3 无 docs/iterations"
ck "$(cat "$TMP/err")" "" "F3 stderr 为空"

# ── END ──
[ $fail -eq 0 ] && echo PASS; exit $fail
