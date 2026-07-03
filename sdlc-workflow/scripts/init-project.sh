#!/bin/bash
set -euo pipefail

PROJECT_ROOT="${1:-.}"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 检查是否已初始化
if [ -f "$PROJECT_ROOT/.claude/CLAUDE.md" ] && [ -f "$PROJECT_ROOT/.claude/ARCHITECTURE.md" ]; then
  echo "✅ 项目已初始化，跳过"
  exit 0
fi

echo "🔧 初始化 SDLC Workflow 项目结构..."

# 创建目录（测试目录按 workspace 镜像，避免把测试写回源码目录）
mkdir -p "$PROJECT_ROOT/.claude/rules"
mkdir -p "$PROJECT_ROOT/.claude/skills"
mkdir -p "$PROJECT_ROOT/docs/iterations"
mkdir -p "$PROJECT_ROOT/tests/unit/web"
mkdir -p "$PROJECT_ROOT/tests/unit/server"
mkdir -p "$PROJECT_ROOT/tests/unit/packages"
mkdir -p "$PROJECT_ROOT/tests/e2e"
mkdir -p "$PROJECT_ROOT/tests/reports"
mkdir -p "$PROJECT_ROOT/tests/reports/playwright"

# 复制模板（不覆盖已存在的文件）
copy_if_not_exists() {
  [ -f "$2" ] || cp "$1" "$2"
}

copy_if_not_exists "$SKILL_DIR/templates/CLAUDE.md.tpl"              "$PROJECT_ROOT/.claude/CLAUDE.md"
copy_if_not_exists "$SKILL_DIR/templates/workflow-rules.md.tpl"      "$PROJECT_ROOT/.claude/rules/workflow-rules.md"
copy_if_not_exists "$SKILL_DIR/templates/ARCHITECTURE.md.tpl"        "$PROJECT_ROOT/.claude/ARCHITECTURE.md"
copy_if_not_exists "$SKILL_DIR/templates/SECURITY.md.tpl"            "$PROJECT_ROOT/.claude/SECURITY.md"
copy_if_not_exists "$SKILL_DIR/templates/CODING_GUIDELINES.md.tpl"   "$PROJECT_ROOT/.claude/CODING_GUIDELINES.md"
# SDLC 配置统一放到 .claude/.sdlc-config（替代旧的项目根 .env）
copy_if_not_exists "$SKILL_DIR/templates/sdlc-config.tpl"            "$PROJECT_ROOT/.claude/.sdlc-config"

sync_config_var() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp
  tmp="$(mktemp)"

  if [ -f "$file" ] && grep -q "^${key}=" "$file"; then
    awk -v key="$key" -v value="$value" '
      BEGIN { replaced = 0 }
      $0 ~ ("^" key "=") {
        print key "=" value
        replaced = 1
        next
      }
      { print }
      END {
        if (!replaced) {
          print key "=" value
        }
      }
    ' "$file" > "$tmp"
  else
    if [ -f "$file" ]; then
      cat "$file" > "$tmp"
      printf '\n%s=%s\n' "$key" "$value" >> "$tmp"
    else
      printf '%s=%s\n' "$key" "$value" > "$tmp"
    fi
  fi

  mv "$tmp" "$file"
}

# 将本地 SDLC 配置加入 .gitignore（含 worktree 注入端口的本地副本）
ensure_gitignore() {
  local pattern="$1"
  if [ -f "$PROJECT_ROOT/.gitignore" ]; then
    grep -qxF "$pattern" "$PROJECT_ROOT/.gitignore" || echo "$pattern" >> "$PROJECT_ROOT/.gitignore"
  else
    echo "$pattern" > "$PROJECT_ROOT/.gitignore"
  fi
}
ensure_gitignore ".claude/.sdlc-config"
ensure_gitignore ".claude/.sdlc-config.local"
# qa 二进制产物不入库（保留 tests/reports/*.md 验收报告）
ensure_gitignore "# SDLC qa 二进制产物（保留 tests/reports/*.md）"
ensure_gitignore "tests/reports/**/screenshots/"
ensure_gitignore "tests/reports/playwright/"
ensure_gitignore "tests/reports/**/*.png"

echo "✅ SDLC Workflow 项目初始化完成"
echo "📝 已生成 .claude/.sdlc-config，请按需编辑配置项"
# 自定义 skills 目录占位说明（不覆盖已存在的）
if [ ! -f "$PROJECT_ROOT/.claude/skills/README.md" ]; then
  cat > "$PROJECT_ROOT/.claude/skills/README.md" <<'EOF'
# 自定义 Skills

把项目专属 skill 放到本目录：`.claude/skills/<name>/SKILL.md`
（frontmatter 需含 `name` 与 `description`）。

SDLC pipeline 会自动发现并在与当前阶段相关时优先调用。
详见项目根 `.claude/CLAUDE.md` 的「自定义 Skills」小节。
EOF
fi

echo "📝 请编辑 .claude/CLAUDE.md 填写项目信息"
