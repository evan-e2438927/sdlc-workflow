#!/bin/bash
# init-project.sh <项目根> — 初始化 SDLC 工作流（.agents/ 布局）
#   - 旧布局（.claude/CLAUDE.md 等为实体文件）→ 提示执行 update 迁移，不做任何改动
#   - 已初始化 → 只执行同步
#   - 否则：放模板到 .agents/ → 首次生成 config.json 时导入已有平台配置 → 根目录实体
#     AGENTS.md / CLAUDE.md 并入 .agents/AGENTS.md → 执行同步（生成软链接与平台文件）
set -euo pipefail

PROJECT_ROOT="${1:-.}"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SYNC="$SKILL_DIR/scripts/sdlc-sync-agents.sh"
# shellcheck source=sdlc-migrate-lib.sh
. "$SKILL_DIR/scripts/sdlc-migrate-lib.sh"

mkdir -p "$PROJECT_ROOT"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
A="$PROJECT_ROOT/.agents"

run_sync() {
  local rc=0
  bash "$SYNC" "$PROJECT_ROOT" || rc=$?
  case "$rc" in
    0) ;;
    1) echo "⚠ 同步完成但有冲突未解决（见上方 ⚠），请按提示处理后重新执行任意 sdlc 命令" ;;
    *) echo "❌ 同步失败（退出码 ${rc}）" >&2; exit 2 ;;
  esac
}

for f in CLAUDE.md ARCHITECTURE.md; do
  if [ -f "$PROJECT_ROOT/.claude/$f" ] && [ ! -L "$PROJECT_ROOT/.claude/$f" ]; then
    echo "❌ 检测到旧布局（.claude/$f 是实体文件）。请执行 update（/sdlc-update）迁移到 .agents/，init 不做改动。" >&2
    exit 1
  fi
done

if [ -f "$A/AGENTS.md" ] && [ -f "$A/ARCHITECTURE.md" ]; then
  echo "✅ 项目已初始化，执行同步"
  run_sync
  exit 0
fi

echo "🔧 初始化 SDLC Workflow 项目结构（.agents/）..."

# 目录（测试目录按 workspace 镜像，避免把测试写回源码目录）
mkdir -p "$A/rules" "$A/skills"
mkdir -p "$PROJECT_ROOT/docs/iterations"
mkdir -p "$PROJECT_ROOT/tests/unit/web" "$PROJECT_ROOT/tests/unit/server" "$PROJECT_ROOT/tests/unit/packages"
mkdir -p "$PROJECT_ROOT/tests/e2e" "$PROJECT_ROOT/tests/reports/playwright"

# 复制模板（不覆盖已存在的文件）
copy_if_not_exists() { [ -f "$2" ] || cp "$1" "$2"; }
copy_if_not_exists "$SKILL_DIR/templates/AGENTS.md.tpl"              "$A/AGENTS.md"
copy_if_not_exists "$SKILL_DIR/templates/workflow-rules.md.tpl"      "$A/rules/workflow-rules.md"
copy_if_not_exists "$SKILL_DIR/templates/ARCHITECTURE.md.tpl"        "$A/ARCHITECTURE.md"
copy_if_not_exists "$SKILL_DIR/templates/SECURITY.md.tpl"            "$A/SECURITY.md"
copy_if_not_exists "$SKILL_DIR/templates/CODING_GUIDELINES.md.tpl"   "$A/CODING_GUIDELINES.md"
copy_if_not_exists "$SKILL_DIR/templates/sdlc-config.tpl"            "$A/.sdlc-config"

BAK="$A/.backup/$(date +%Y%m%d-%H%M%S)"
# 平台配置的单一来源：首次生成时把已存在的 .claude/settings.json、.mcp.json 等导入（先备份）
if [ ! -f "$A/config.json" ]; then
  cp "$SKILL_DIR/templates/config.json.tpl" "$A/config.json"
  sdlc_import_platform "$PROJECT_ROOT" "$BAK"
fi
# 根目录已有实体 AGENTS.md / CLAUDE.md：备份后并入 .agents/AGENTS.md，由同步改为软链接
sdlc_absorb_root_doc "$PROJECT_ROOT" "$BAK" AGENTS.md
sdlc_absorb_root_doc "$PROJECT_ROOT" "$BAK" CLAUDE.md

if [ ! -f "$A/skills/README.md" ]; then
  cat > "$A/skills/README.md" <<'EOF'
# 自定义 Skills

把项目专属 skill 放到本目录：`.agents/skills/<name>/SKILL.md`
（frontmatter 需含 `name` 与 `description`）。

SDLC pipeline 会自动发现并在与当前阶段相关时优先调用；Claude Code 通过同步生成的
`.claude/skills/<name>` 软链接发现它们。详见 `.agents/AGENTS.md` 的「自定义 Skills」小节。
EOF
fi

# qa 二进制产物不入库（保留 tests/reports/*.md 验收报告）；sdlc 生成文件由同步脚本的托管块维护
ensure_gitignore() {
  local pattern="$1"
  if [ -f "$PROJECT_ROOT/.gitignore" ]; then
    grep -qxF "$pattern" "$PROJECT_ROOT/.gitignore" || echo "$pattern" >> "$PROJECT_ROOT/.gitignore"
  else
    echo "$pattern" > "$PROJECT_ROOT/.gitignore"
  fi
}
ensure_gitignore "# SDLC qa 二进制产物（保留 tests/reports/*.md）"
ensure_gitignore "tests/reports/**/screenshots/"
ensure_gitignore "tests/reports/playwright/"
ensure_gitignore "tests/reports/**/*.png"

run_sync

echo "✅ SDLC Workflow 项目初始化完成"
echo "📝 请编辑 .agents/AGENTS.md 填写项目信息；运行配置在 .agents/.sdlc-config（已 gitignore）"
echo "📝 MCP 与平台设置统一改 .agents/config.json（.claude/settings.json、.mcp.json、.codex/ 等由同步生成，不要手改）"
echo "📌 请提交：AGENTS.md、CLAUDE.md（软链接）、.agents/（除 gitignore 项）、.claude/skills/ 与 .claude/agents/ 下的软链接"
echo "📌 Codex 用户：首次使用需在 Codex 的 /hooks 中信任本项目的 hooks（.codex/hooks.json），编辑后检查才会运行"
