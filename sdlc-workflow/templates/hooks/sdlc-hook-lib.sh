#!/bin/bash
# SDLC hooks 共用函数（由 sdlc-pre-edit-guard.sh / sdlc-post-edit-check.sh 引入）。
# sdlc 托管文件：由 sdlc-sync-agents.sh 从核心 templates/hooks/ 刷新，不要手改。
# 同时兼容两种输入：
#   - Claude Code：tool_input.file_path
#   - Codex：tool_name 为 apply_patch / Edit / Write 时，路径在 tool_input.command 的补丁头里（可能多个文件）

# 项目根：$CLAUDE_PROJECT_DIR → git 仓库根 → 当前目录
sdlc_project_root() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then printf '%s\n' "$CLAUDE_PROJECT_DIR"; return 0; fi
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

# sdlc_json_str <jq-filter> <key> <json>：有 jq 用 jq，否则对扁平字符串键用 grep 回退
sdlc_json_str() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$3" | jq -r "$1 // empty" 2>/dev/null
  else
    printf '%s' "$3" | grep -oE "\"$2\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 \
      | sed -E "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/"
  fi
}

# sdlc_patch_text <json>：取 tool_input.command（字符串，或数组按换行拼接）
sdlc_patch_text() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" | jq -r '.tool_input.command // empty | if type == "array" then join("\n") else tostring end' 2>/dev/null
  else
    printf '%s' "$1" | grep -oE '"command"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' | head -1 \
      | sed -E 's/^"command"[[:space:]]*:[[:space:]]*"//; s/"$//' \
      | awk '{ gsub(/\\n/, "\n"); gsub(/\\"/, "\""); gsub(/\\\\/, "\\"); print }'
  fi
}

# sdlc_edited_paths <json> <root>：每行输出一个被编辑文件的绝对路径。
# file_path 的相对路径按项目根解析；补丁里的相对路径按 payload.cwd（没有则项目根）解析。
sdlc_edited_paths() {
  local payload="$1" root="$2" fp tool base p
  fp="$(sdlc_json_str '.tool_input.file_path' file_path "$payload")"
  if [ -n "$fp" ]; then
    case "$fp" in /*) printf '%s\n' "$fp" ;; *) printf '%s/%s\n' "$root" "$fp" ;; esac
    return 0
  fi
  tool="$(sdlc_json_str '.tool_name' tool_name "$payload")"
  case "$tool" in apply_patch|Edit|Write) ;; *) return 0 ;; esac
  base="$(sdlc_json_str '.cwd' cwd "$payload")"; [ -n "$base" ] || base="$root"
  sdlc_patch_text "$payload" \
    | grep -E '^\*\*\* (Add File|Update File|Delete File|Move to): ' \
    | sed -E 's/^\*\*\* (Add File|Update File|Delete File|Move to): //' \
    | while IFS= read -r p || [ -n "$p" ]; do
        p="${p%$'\r'}"
        [ -n "$p" ] || continue
        case "$p" in /*) printf '%s\n' "$p" ;; *) printf '%s/%s\n' "$base" "$p" ;; esac
      done
}
