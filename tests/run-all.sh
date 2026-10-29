#!/bin/bash
# 运行 tests/ 下全部 test-*.sh；任一失败 exit 1。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
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
  echo "失败:$failed（通过 $pass 个）"; exit 1
fi
echo "全部通过：$pass 个测试"
