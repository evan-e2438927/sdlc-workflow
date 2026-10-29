#!/bin/bash
# 运行 tests/ 下全部 test-*.sh；任一失败 exit 1。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# 用户机器（macOS）通常是 UTF-8 locale；bash 3.2 在 UTF-8 下会把 `${var}（` 之类当成更长的变量名，测试也在 UTF-8 下跑
LOCALES="$(locale -a 2>/dev/null)"   # 先取全量再 grep：pipefail 下 grep -q 提前退出会让 locale 收到 SIGPIPE
for loc in en_US.UTF-8 C.UTF-8 zh_CN.UTF-8; do
  if grep -qix -e "$loc" -e "${loc%.UTF-8}.utf8" <<<"$LOCALES"; then export LC_ALL="$loc"; break; fi
done
LOG="$(mktemp -d)"; trap 'rm -rf "$LOG"' EXIT
pass=0; failed=""
for t in "$HERE"/test-*.sh; do
  name="$(basename "$t")"
  if bash "$t" >"$LOG/$name.out" 2>&1; then
    echo "PASS $name"; pass=$((pass + 1))
  else
    echo "FAIL $name"; sed 's/^/    /' "$LOG/$name.out" | tail -40
    failed="$failed $name"
  fi
done
if [ -n "$failed" ]; then
  echo "失败:${failed}（通过 $pass 个）"; exit 1
fi
echo "全部通过：$pass 个测试（LC_ALL=${LC_ALL:-未设置}）"
