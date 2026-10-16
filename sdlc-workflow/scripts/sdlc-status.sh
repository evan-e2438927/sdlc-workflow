#!/bin/bash
# SDLC 迭代状态机：phase 迁移的唯一写入口，只给 agent 调用。
#   sdlc-status.sh transition <迭代目录> <目标phase> --by <命令> [--note <说明>] [--flags '<json>']
#   sdlc-status.sh find-latest <phase> [<phase>...]   → 输出最近一个命中的迭代目录（相对项目根）
# 迁移表：同目录 state-machine.json。项目根：${CLAUDE_PROJECT_DIR:-$PWD}。
# 退出码：0 成功；1 非法迁移 / 未知 phase / find-latest 无命中；2 用法或输入错误；3 缺少 jq。
set -uo pipefail

SM="$(cd "$(dirname "$0")" && pwd)/state-machine.json"

die() { echo "[sdlc-status] $2" >&2; exit "$1"; }
command -v jq >/dev/null 2>&1 || die 3 "缺少 jq，请先安装（macOS: brew install jq；Debian/Ubuntu: apt install jq）"

ROOT="$(cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null && pwd -P)" || die 2 "项目根不存在: ${CLAUDE_PROJECT_DIR:-$PWD}"

# 迭代目录 → 项目根下的相对路径（无尾部 /）；目录不存在时报错
rel_iter() {
  local arg="${1%/}" abs
  case "$arg" in /*) abs="$arg" ;; *) abs="$ROOT/$arg" ;; esac
  abs="$(cd "$abs" 2>/dev/null && pwd -P)" || return 1
  case "$abs" in "$ROOT"/*) printf '%s' "${abs#"$ROOT"/}" ;; *) return 1 ;; esac
}

now_iso() { date +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/'; }

cmd_transition() {
  [ $# -ge 2 ] || die 2 "用法: transition <迭代目录> <目标phase> --by <命令> [--note <说明>] [--flags '<json>']"
  local iter="$1" to="$2" by="" note="" flags=""
  shift 2
  while [ $# -gt 0 ]; do
    case "$1" in
      --by)    [ $# -ge 2 ] || die 2 "--by 缺少值";    by="$2";    shift 2 ;;
      --note)  [ $# -ge 2 ] || die 2 "--note 缺少值";  note="$2";  shift 2 ;;
      --flags) [ $# -ge 2 ] || die 2 "--flags 缺少值"; flags="$2"; shift 2 ;;
      *) die 2 "未知参数: $1" ;;
    esac
  done
  [ -n "$by" ] || die 2 "缺少 --by <命令>"

  local rel
  rel="$(rel_iter "$iter")" || die 2 "迭代目录不存在或不在项目内: $iter"
  local dir="$ROOT/$rel" file="$ROOT/$rel/status.json" from=""
  if [ -f "$file" ]; then
    jq empty "$file" >/dev/null 2>&1 || die 2 "status.json 不是合法 JSON，未做任何修改: $rel/status.json"
    from="$(jq -r '.phase // ""' "$file")"
  fi

  local known allowed
  known="$(jq -r --arg f "$from" '.transitions | has($f)' "$SM")"
  [ "$known" = "true" ] || die 1 "当前 phase \"$from\" 不在迁移表中（$rel/status.json），请人工确认"
  allowed="$(jq -r --arg f "$from" '.transitions[$f] | join(" ")' "$SM")"
  if ! jq -e --arg f "$from" --arg t "$to" '.transitions[$f] | index($t) != null' "$SM" >/dev/null; then
    die 1 "当前 ${from:-（无）}，不能迁移到 $to；允许：${allowed:-（无，终态）}"
  fi

  local create=false
  if [ -z "$from" ]; then
    create=true
    case "$by" in proposal|doit|mini) ;; *) die 2 "创建迭代状态时 --by 必须是 proposal / doit / mini，实际: $by" ;; esac
    if [ -n "$flags" ]; then
      printf '%s' "$flags" | jq -e 'type == "object"' >/dev/null 2>&1 || die 2 "--flags 不是合法的 JSON 对象: $flags"
    fi
  fi
  [ "$create" = true ] && [ -n "$flags" ] || flags="null"

  local key
  case "$to" in
    pending_review) key="proposal_at" ;;
    approved)       key="reviewed_at" ;;
    *)              key="${to}_at" ;;
  esac

  local tmp
  tmp="$(mktemp "$dir/.status.XXXXXX")" || die 2 "无法在 $rel 下创建临时文件"
  trap 'rm -f "$tmp"' EXIT
  { if [ -f "$file" ]; then cat "$file"; else echo '{}'; fi; } | jq \
    --arg to "$to" --arg from "$from" --arg at "$(now_iso)" --arg by "$by" \
    --arg key "$key" --arg note "$note" --arg rel "$rel" \
    --argjson create "$create" --argjson flags "$flags" '
      .phase = $to
      | .[$key] = $at
      | (if $to == "approved" then .reviewer = $by else . end)
      | (if $create then .mode = $by | .iter_dir = $rel
           | (if $flags != null then .flags = $flags else . end)
         else . end)
      | .history = ((.history // []) + [
          {at: $at, from: (if $from == "" then null else $from end), to: $to, by: $by}
          + (if $note != "" then {note: $note} else {} end)
        ])
    ' > "$tmp" || die 2 "写入 status.json 失败，原文件未改动"
  mv "$tmp" "$file" || die 2 "写入 status.json 失败，原文件未改动"
  trap - EXIT

  if [ "$to" = "rejected" ]; then
    local marker="$ROOT/.claude/.sdlc-active-iteration" m mrel
    if [ -f "$marker" ]; then
      m="$(head -1 "$marker" | tr -d '\r')"
      mrel="$(rel_iter "$m" 2>/dev/null)" || mrel="${m%/}"
      [ "$mrel" = "$rel" ] && rm -f "$marker"
    fi
    echo "[sdlc-status] 已标记为 rejected（工作区代码未回滚）" >&2
  fi
  echo "phase: ${from:-（无）} → $to ($rel)"
}

# 按「日期目录/序号」逆序（字典序即时间序）取第一个 phase 命中的迭代；损坏的 status.json 跳过
cmd_find_latest() {
  [ $# -ge 1 ] || die 2 "用法: find-latest <phase> [<phase>...]"
  local base="$ROOT/docs/iterations" f ph want
  [ -d "$base" ] || exit 1
  while IFS= read -r f; do
    ph="$(jq -r '.phase // ""' "$f" 2>/dev/null)" || continue
    for want in "$@"; do
      if [ "$ph" = "$want" ]; then
        f="${f%/status.json}"; printf '%s\n' "${f#"$ROOT"/}"; exit 0
      fi
    done
  done < <(find "$base" -mindepth 3 -maxdepth 3 -name status.json -type f 2>/dev/null | sort -r)
  exit 1
}

case "${1:-}" in
  transition)  shift; cmd_transition "$@" ;;
  find-latest) shift; cmd_find_latest "$@" ;;
  *) die 2 "用法: sdlc-status.sh transition <迭代目录> <目标phase> --by <命令> [--note <说明>] [--flags '<json>'] | find-latest <phase>..." ;;
esac
