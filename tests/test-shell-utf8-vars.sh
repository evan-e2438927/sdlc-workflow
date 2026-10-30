#!/bin/bash
# 静态检查：随 skill 分发的 shell 脚本里，变量展开后面不能直接跟非 ASCII 字符（如 `${name}）`）。
# macOS 自带 bash 3.2 在 UTF-8 locale 下会把多字节字符当作变量名的一部分，配合 set -u 直接退出。写成 `${name}）`。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$HERE/.." && pwd)"; SKILL_DIR="$REPO_DIR/sdlc-workflow"
out="$(LC_ALL=C grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^ -~[:cntrl:]]' "$SKILL_DIR"/scripts/*.sh "$SKILL_DIR"/templates/hooks/*.sh "$SKILL_DIR"/templates/bin/* "$REPO_DIR"/tests/*.sh | grep -v "test-shell-utf8-vars.sh")"
if [ -n "$out" ]; then
  echo "FAIL: 变量后直接跟非 ASCII 字符（请改成 \${var}）："; echo "$out" | sed "s#$REPO_DIR/#    #"; exit 1
fi
echo PASS
