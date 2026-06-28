#!/bin/bash
set -euo pipefail

# ============================================================
# sdlc-worktree.sh — SDLC Workflow 并行开发 Worktree 管理器
# ============================================================
#
# Usage:
#   sdlc-worktree.sh create <slug> <type>    创建 worktree
#   sdlc-worktree.sh list                    列出所有 worktree
#   sdlc-worktree.sh status                  全局状态总览
#   sdlc-worktree.sh remove <seq|slug>       移除 worktree
#   sdlc-worktree.sh gc                      清理已合并的 worktree
#
# 环境变量:
#   GIT_BRANCH_PREFIX  分支前缀 (默认 feat/)
#   PROJECT_ROOT       主仓库根目录 (默认 当前目录)

COMMAND="${1:-help}"
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
REGISTRY_DIR="$PROJECT_ROOT/.worktrees"
REGISTRY_FILE="$REGISTRY_DIR/worktree-registry.json"

# ---- helpers ----

ensure_registry() {
  mkdir -p "$REGISTRY_DIR"
  if [ ! -f "$REGISTRY_FILE" ]; then
    cat > "$REGISTRY_FILE" <<'EOF'
{
  "version": 1,
  "worktrees": []
}
EOF
    echo "📋 创建 worktree 注册表: $REGISTRY_FILE"
  fi
}

next_seq() {
  if [ ! -f "$REGISTRY_FILE" ]; then
    echo "001"
    return
  fi
  local last
  last=$(python3 -c "
import json, sys
with open('$REGISTRY_FILE') as f:
    data = json.load(f)
wts = data.get('worktrees', [])
if not wts:
    print('000')
else:
    print(max(w['seq'] for w in wts))
" 2>/dev/null || echo "000")
  printf "%03d" $(( 10#$last + 1 ))
}

# 检查 worktree 路径是否已存在
check_worktree_exists() {
  local wt_path="$1"
  if [ -d "$wt_path" ]; then
    echo "❌ Worktree 目录已存在: $wt_path"
    exit 1
  fi
}

# 读取 .claude/.sdlc-config 中的变量
read_config_var() {
  local key="$1"
  local default="$2"
  local cfg="$PROJECT_ROOT/.claude/.sdlc-config"
  if [ -f "$cfg" ]; then
    local val
    val=$(grep "^${key}=" "$cfg" 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d "'")
    echo "${val:-$default}"
  else
    echo "$default"
  fi
}

# ---- create ----

cmd_create() {
  local slug="${2:?Usage: sdlc-worktree.sh create <slug> <type>}"
  local type="${3:-feature}"
  local date
  date=$(date +%Y-%m-%d)

  # 验证 type
  case "$type" in
    feature|fix|refactor|docs|test|chore) ;;
    *) echo "❌ 无效的 type: $type (允许: feature|fix|refactor|docs|test|chore)"; exit 1 ;;
  esac

  ensure_registry

  local seq
  seq=$(next_seq)

  local branch_prefix
  branch_prefix=$(read_config_var "GIT_BRANCH_PREFIX" "feat/")

  # type → branch prefix 映射
  case "$type" in
    feature) branch_prefix="feat/" ;;
    fix)     branch_prefix="fix/" ;;
    refactor) branch_prefix="refactor/" ;;
    docs)    branch_prefix="docs/" ;;
    test)    branch_prefix="test/" ;;
    chore)   branch_prefix="chore/" ;;
  esac

  local branch_name="${branch_prefix}${slug}-${date}-wt${seq}"
  local wt_dir_name="wt-${seq}-${slug}-${type}"
  local wt_path
  wt_path="$(dirname "$PROJECT_ROOT")/$wt_dir_name"
  local iter_dir="docs/iterations/${date}/${seq}-${slug}-${type}"

  check_worktree_exists "$wt_path"

  echo "🌿 创建并行工作区..."
  echo "   序号:     $seq"
  echo "   Slug:     $slug"
  echo "   Type:     $type"
  echo "   分支:     $branch_name"
  echo "   路径:     $wt_path"
  echo "   迭代目录: $iter_dir"
  echo ""

  # 创建 worktree
  cd "$PROJECT_ROOT"
  git worktree add -b "$branch_name" "$wt_path" HEAD

  # 在 worktree 中创建迭代目录
  mkdir -p "$wt_path/$iter_dir"

  # 复制本地 SDLC 配置（.claude/.sdlc-config* 在 .gitignore 中，git worktree 不会带过去）
  local cfg_copied=0
  mkdir -p "$wt_path/.claude"
  for cfg_file in "$PROJECT_ROOT"/.claude/.sdlc-config*; do
    [ -f "$cfg_file" ] || continue
    cp "$cfg_file" "$wt_path/.claude/$(basename "$cfg_file")"
    cfg_copied=$((cfg_copied + 1))
  done
  echo "   📄 已复制 $cfg_copied 个 .sdlc-config* 文件到 worktree"

  # 端口隔离：覆写 .claude/.sdlc-config 中的 PORT/API_PORT
  local seq_num=$((10#$seq))
  local port=$((3000 + seq_num))
  local api_port=$((4000 + seq_num))

  local wt_cfg="$wt_path/.claude/.sdlc-config"
  if [ -f "$wt_cfg" ]; then
    grep -v "^PORT=" "$wt_cfg" | grep -v "^API_PORT=" > "$wt_cfg.tmp" || true
    mv "$wt_cfg.tmp" "$wt_cfg"
    echo "PORT=$port" >> "$wt_cfg"
    echo "API_PORT=$api_port" >> "$wt_cfg"
  fi

  # 更新注册表
  python3 -c "
import json, sys
from datetime import datetime, timezone

with open('$REGISTRY_FILE', 'r') as f:
    data = json.load(f)

data['worktrees'].append({
    'seq': '$seq',
    'slug': '$slug',
    'type': '$type',
    'branch': '$branch_name',
    'path': '../$wt_dir_name',
    'iter_dir': '$iter_dir',
    'phase': 'created',
    'created_at': datetime.now(timezone.utc).isoformat(),
    'pipeline_stage': None,
    'pr_url': None
})

with open('$REGISTRY_FILE', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
"

  echo ""
  echo "✅ Worktree 创建成功"
  echo ""
  echo "📌 后续操作："
  echo "   cd $wt_path"
  echo "   pnpm install           # 安装依赖 (若项目需要)"
  echo "   /sdlc-workflow proposal \"<你的需求>\""
  echo ""
  echo "   Dev server 端口: $port (API: $api_port)"
}

# ---- list ----

cmd_list() {
  ensure_registry

  echo ""
  echo "📋 SDLC Worktree 注册表"
  echo ""

  python3 -c "
import json

with open('$REGISTRY_FILE') as f:
    data = json.load(f)

wts = data.get('worktrees', [])
if not wts:
    print('  (空 — 尚未创建并行工作区)')
else:
    # Header
    print(f\"{'SEQ':<6} {'SLUG':<25} {'BRANCH':<35} {'PHASE':<15} {'STAGE':<20} {'CREATED':<12}\")
    print('-' * 113)
    for w in wts:
        seq = w.get('seq', '?')
        slug = w.get('slug', '?')
        branch = w.get('branch', '?')
        if len(branch) > 33:
            branch = branch[:30] + '...'
        phase = w.get('phase', '?')
        stage = w.get('pipeline_stage') or '-'
        created = w.get('created_at', '?')[:10]
        print(f'{seq:<6} {slug:<25} {branch:<35} {phase:<15} {stage:<20} {created:<12}')
"
  echo ""

  # 也显示 git worktree list 的原生信息
  echo "📂 Git Worktree 原生视图:"
  cd "$PROJECT_ROOT"
  git worktree list
  echo ""
}

# ---- status ----

cmd_status() {
  ensure_registry

  echo ""
  echo "📊 SDLC 并行开发全局状态"
  echo ""

  python3 -c "
import json, os

with open('$REGISTRY_FILE') as f:
    data = json.load(f)

wts = data.get('worktrees', [])
if not wts:
    print('  (无活跃的并行工作区)')
else:
    for w in wts:
        seq = w.get('seq', '?')
        slug = w.get('slug', '?')
        phase = w.get('phase', '?')
        stage = w.get('pipeline_stage') or '-'
        pr = w.get('pr_url') or '(无)'
        branch = w.get('branch', '?')
        wt_path = os.path.join('$PROJECT_ROOT', '..', w.get('path', '').lstrip('../'))
        iter_dir = w.get('iter_dir', '?')

        # 尝试读取 worktree 内的 status.json
        status_file = os.path.join(wt_path, iter_dir, 'status.json')
        local_phase = phase
        local_stage = stage
        if os.path.isfile(status_file):
            try:
                with open(status_file) as sf:
                    sdata = json.load(sf)
                local_phase = sdata.get('phase', phase)
                local_stage = sdata.get('pipeline_stage', stage) or stage
            except:
                pass

        emoji = {'created': '🆕', 'pending_review': '⏸️', 'approved': '✅',
                 'in-dev': '🔨', 'applied': '🚀', 'rejected': '❌'}.get(local_phase, '❓')

        print(f'{emoji} [{seq}] {slug}')
        print(f'   分支:   {branch}')
        print(f'   阶段:   {local_phase} / {local_stage}')
        print(f'   PR:     {pr}')
        print(f'   迭代:   {iter_dir}')
        print()
"
}

# ---- remove ----

cmd_remove() {
  local target="${2:?Usage: sdlc-worktree.sh remove <seq|slug|--all-merged>}"

  ensure_registry

  if [ "$target" = "--all-merged" ]; then
    cmd_gc_merged
    return
  fi

  # 查找匹配的 worktree
  local wt_info
  wt_info=$(python3 -c "
import json, sys

with open('$REGISTRY_FILE') as f:
    data = json.load(f)

target = '$target'
for i, w in enumerate(data['worktrees']):
    if w['seq'] == target or w['slug'] == target:
        print(json.dumps({'index': i, **w}))
        sys.exit(0)
print('NOT_FOUND')
")

  if [ "$wt_info" = "NOT_FOUND" ]; then
    echo "❌ 未找到匹配的 worktree: $target"
    exit 1
  fi

  local wt_path wt_branch
  wt_path=$(echo "$wt_info" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['path'])")
  wt_branch=$(echo "$wt_info" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['branch'])")
  local wt_slug
  wt_slug=$(echo "$wt_info" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['slug'])")

  local abs_path
  abs_path="$(dirname "$PROJECT_ROOT")/$(echo "$wt_path" | sed 's|^\.\./||')"

  echo "🗑️  移除 worktree: $wt_slug"
  echo "   路径:  $abs_path"
  echo "   分支:  $wt_branch"
  echo ""

  # 移除 worktree
  cd "$PROJECT_ROOT"
  if [ -d "$abs_path" ]; then
    git worktree remove "$abs_path" --force 2>/dev/null || true
  fi
  git worktree prune

  # 删除本地分支（仅当完全合并后）
  if git branch --merged main | grep -q "$wt_branch"; then
    git branch -d "$wt_branch" 2>/dev/null || true
    echo "   ✅ 本地分支已删除 (已合并)"
  else
    echo "   ⚠️  本地分支保留 (未合并到 main)"
  fi

  # 从注册表移除
  python3 -c "
import json

with open('$REGISTRY_FILE', 'r') as f:
    data = json.load(f)

data['worktrees'] = [w for w in data['worktrees'] if w['slug'] != '$wt_slug']

with open('$REGISTRY_FILE', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
"

  echo "✅ Worktree 已移除"
}

# ---- gc ----

cmd_gc() {
  ensure_registry

  echo "🧹 检查可清理的 worktree..."
  echo ""

  cd "$PROJECT_ROOT"
  git worktree prune

  python3 -c "
import json, os, subprocess

with open('$REGISTRY_FILE') as f:
    data = json.load(f)

to_remove = []
for w in data['worktrees']:
    abs_path = os.path.join('$(dirname "$PROJECT_ROOT")', w['path'].lstrip('../'))
    exists = os.path.isdir(abs_path)

    if not exists:
        print(f\"  🗑️  {w['slug']} — 目录不存在，可清理注册表\")
        to_remove.append(w['slug'])
        continue

    # 检查 PR 是否已合并
    if w.get('pr_url'):
        result = subprocess.run(
            ['gh', 'pr', 'view', w['pr_url'], '--json', 'state', '--jq', '.state'],
            capture_output=True, text=True
        )
        if result.returncode == 0 and result.stdout.strip() == 'MERGED':
            print(f\"  ✅ {w['slug']} — PR 已合并，建议移除\")
            to_remove.append(w['slug'])
            continue

    if w.get('phase') == 'applied':
        print(f\"  📦 {w['slug']} — 已 applied，可考虑移除\")
    else:
        print(f\"  ⏳ {w['slug']} — 进行中 ({w.get('phase', '?')})\")

if not to_remove:
    print()
    print('  没有需要清理的 worktree')
else:
    print()
    print(f'  可清理: {len(to_remove)} 个')
    print(f'  运行: sdlc-worktree.sh remove <slug> 逐个清理')
"
  echo ""
}

cmd_gc_merged() {
  ensure_registry

  echo "🧹 批量移除已合并的 worktree..."

  cd "$PROJECT_ROOT"

  python3 -c "
import json, os, subprocess

with open('$REGISTRY_FILE') as f:
    data = json.load(f)

to_remove = []
for w in data['worktrees']:
    if w.get('pr_url'):
        result = subprocess.run(
            ['gh', 'pr', 'view', w['pr_url'], '--json', 'state', '--jq', '.state'],
            capture_output=True, text=True
        )
        if result.returncode == 0 and result.stdout.strip() == 'MERGED':
            to_remove.append(w['slug'])

for slug in to_remove:
    print(f'slug:{slug}')
" | while IFS= read -r line; do
    slug="${line#slug:}"
    if [ -n "$slug" ]; then
      cmd_remove "remove" "$slug"
    fi
  done

  echo "✅ 批量清理完成"
}

# ---- help ----

cmd_help() {
  cat <<'USAGE'

SDLC Worktree 管理器 — 并行开发支持

Usage:
  sdlc-worktree.sh create <slug> <type>    创建并行工作区
  sdlc-worktree.sh list                    列出所有 worktree
  sdlc-worktree.sh status                  全局状态总览
  sdlc-worktree.sh remove <seq|slug>       移除 worktree
  sdlc-worktree.sh remove --all-merged     移除所有 PR 已合并的 worktree
  sdlc-worktree.sh gc                      检查可清理的 worktree
  sdlc-worktree.sh help                    显示此帮助

Type 枚举: feature | fix | refactor | docs | test | chore

示例:
  sdlc-worktree.sh create user-login feature
  sdlc-worktree.sh create password-reset fix
  sdlc-worktree.sh list
  sdlc-worktree.sh remove 001
  sdlc-worktree.sh gc

USAGE
}

# ---- dispatch ----

case "$COMMAND" in
  create)  cmd_create "$@" ;;
  list)    cmd_list ;;
  status)  cmd_status ;;
  remove)  cmd_remove "$@" ;;
  gc)      cmd_gc ;;
  help|--help|-h) cmd_help ;;
  *)
    echo "❌ 未知命令: $COMMAND"
    cmd_help
    exit 1
    ;;
esac
