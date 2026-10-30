#!/bin/bash
# sdlc-migrate-lib.sh — init / update 共用的迁移函数（以 source 方式引入）
#
#   sdlc_backup <root> <bak> <rel>                 备份 <root>/<rel> 到 <bak>/<rel>（保留目录层级）
#   sdlc_absorb_root_doc <root> <bak> <名称>        根目录实体 AGENTS.md / CLAUDE.md → 备份，内容并入
#                                                  .agents/AGENTS.md 的「## 迁移自 <名称>」小节，删除原文件
#                                                  （随后由同步脚本重建为软链接）
#   sdlc_import_platform <root> <bak>              把已有平台配置导入 .agents/config.json（先备份）：
#       .codex/config.toml  [mcp_servers.*] → mcpServers；其余（含无法安全转换的 server）→ codex.extraToml
#       .cursor/mcp.json、.mcp.json  mcpServers 合并（优先级 config < toml < cursor < .mcp.json，同名不同内容列出）
#       .claude/settings.json  去掉 sdlc hooks 后合并进 claude.settings
#     被 git 跟踪的平台文件只提示 `git rm --cached`，不替用户改索引。
# <bak> 约定为 <root>/.agents/.backup/<YYYYmmdd-HHMMSS>。依赖 jq。

sdlc_backup() {
  local root="$1" bak="$2" rel="$3"
  [ -e "$root/$rel" ] || [ -L "$root/$rel" ] || return 0
  mkdir -p "$bak/$(dirname "$rel")" && cp -R "$root/$rel" "$bak/$rel"
}

sdlc_absorb_root_doc() {
  local root="$1" bak="$2" name="$3" f="$1/$3"
  [ -f "$f" ] && [ ! -L "$f" ] || return 0
  sdlc_backup "$root" "$bak" "$name"
  { printf '\n## 迁移自 %s\n\n' "$name"; cat "$f"; } >> "$root/.agents/AGENTS.md"
  rm -f "$f"
  echo "  ⚠ 根目录 $name 的内容已并入 .agents/AGENTS.md「## 迁移自 ${name}」小节（备份: ${bak#"$root"/}/${name}），可能与已有规则重复，请人工整理"
}

# _sdlc_toml_value <toml 值>：单行 TOML 值 → JSON；无法安全转换时返回 1
_sdlc_toml_value() {
  local v="$1" j
  v="$(printf '%s' "$v" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  case "$v" in
    "'"*"'") jq -cn --arg s "${v:1:${#v}-2}" '$s'; return $? ;;
  esac
  for cand in "$v" "$(printf '%s' "$v" | sed -E 's/[[:space:]]+#.*$//')"; do
    case "$cand" in
      '{'*'}') j="$(printf '%s' "$cand" | sed -E 's/([{,][[:space:]]*)([A-Za-z0-9_-]+)[[:space:]]*=/\1"\2":/g')" ;;
      '['*']') j="$(printf '%s' "$cand" | sed -E 's/,[[:space:]]*]$/]/')" ;;
      *) j="$cand" ;;
    esac
    printf '%s' "$j" | jq -ce . 2>/dev/null && return 0
  done
  return 1
}

# _sdlc_import_toml <root> <out-servers.json> <out-extra.toml>
_sdlc_import_toml() {
  local root="$1" out_servers="$2" out_extra="$3" tagged names name ok obj line key val sub j
  tagged="$(mktemp)"
  # 每行加标签：S<TAB>name<TAB>sub<TAB>原文 或 X<TAB><TAB><TAB>原文
  awk '
    function unq(s) { if (s ~ /^".*"$/) return substr(s, 2, length(s) - 2); return s }
    /^[[:space:]]*\[/ {
      h = $0; sub(/[[:space:]]*(#.*)?$/, "", h); sub(/^[[:space:]]*/, "", h)
      name = ""; subt = ""
      if (h ~ /^\[mcp_servers\.("[^"]+"|[A-Za-z0-9_-]+)(\.(env|http_headers))?\]$/) {
        body = substr(h, 14, length(h) - 14)
        if (body ~ /^"/) { i = index(substr(body, 2), "\""); name = substr(body, 2, i - 1); rest = substr(body, i + 2) }
        else { i = index(body, "."); if (i) { name = substr(body, 1, i - 1); rest = substr(body, i) } else { name = body; rest = "" } }
        if (rest == ".env") subt = "env"; else if (rest == ".http_headers") subt = "http_headers"
      } else if (h ~ /^\[mcp_servers\./) { name = "\001raw"; }
      cur = name; cursub = subt
    }
    /# 由 sdlc-sync-agents\.sh 根据/ { next }
    { if (cur != "" && cur != "\001raw") printf "S\t%s\t%s\t%s\n", cur, cursub, $0; else printf "X\t\t\t%s\n", $0 }
  ' "$root/.codex/config.toml" > "$tagged"
  : > "$out_extra"; echo '{}' > "$out_servers"
  awk -F'\t' '$1 == "X" { sub(/^X\t\t\t/, ""); print }' "$tagged" > "$out_extra"
  names="$(awk -F'\t' '$1 == "S" && !seen[$2]++ { print $2 }' "$tagged")"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    ok=1; obj='{}'
    while IFS= read -r line; do
      sub="$(printf '%s' "$line" | cut -f3)"; line="$(printf '%s' "$line" | cut -f4-)"
      case "$line" in ''|'#'*|'['*) continue ;; esac
      printf '%s' "$line" | grep -qE '^[[:space:]]*([A-Za-z0-9_-]+)[[:space:]]*=' || { ok=0; break; }
      key="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*([A-Za-z0-9_-]+)[[:space:]]*=.*/\1/')"
      val="$(printf '%s' "$line" | sed -E 's/^[^=]*=//')"
      j="$(_sdlc_toml_value "$val")" || { ok=0; break; }
      if [ -n "$sub" ]; then
        printf '%s' "$j" | jq -e 'type == "string"' >/dev/null || { ok=0; break; }
        obj="$(jq -c --arg s "$sub" --arg k "$key" --argjson v "$j" '.[$s][$k] = $v' <<<"$obj")"
      else
        case "$key" in command|args|env|url|http_headers) ;; *) ok=0; break ;; esac
        obj="$(jq -c --arg k "$key" --argjson v "$j" '.[$k] = (if $k == "env" or $k == "http_headers" then ((.[$k] // {}) + $v) else $v end)' <<<"$obj")"
      fi
    done <<EOF
$(awk -F'\t' -v n="$name" '$1 == "S" && $2 == n' "$tagged")
EOF
    if [ "$ok" = 1 ]; then
      obj="$(jq -c 'if .url then ({transport: "http", url} + (if .http_headers then {headers: .http_headers} else {} end))
                    elif .command then ({transport: "stdio", command} + (if .args then {args} else {} end) + (if .env then {env} else {} end))
                    else empty end' <<<"$obj")"
      [ -n "$obj" ] || ok=0
    fi
    if [ "$ok" = 1 ]; then
      jq --arg n "$name" --argjson v "$obj" '.[$n] = $v' "$out_servers" > "$out_servers.tmp" && mv "$out_servers.tmp" "$out_servers"
    else
      echo "  ⚠ .codex/config.toml 的 [mcp_servers.$name] 含无法安全转换的内容，已原样保留在 config.json 的 codex.extraToml"
      { echo; awk -F'\t' -v n="$name" '$1 == "S" && $2 == n { sub(/^S\t[^\t]*\t[^\t]*\t/, ""); print }' "$tagged"; } >> "$out_extra"
    fi
  done <<EOF
$names
EOF
  # 去掉首尾空行
  awk 'NF { for (i = 0; i < blank; i++) print ""; blank = 0; print; seen = 1; next } seen { blank++ }' "$out_extra" > "$out_extra.tmp" && mv "$out_extra.tmp" "$out_extra"
  rm -f "$tagged"
}

sdlc_import_platform() {
  local root="$1" bak="$2" cfg="$1/.agents/config.json" tmpd rel src conflicts
  tmpd="$(mktemp -d)"
  [ -f "$cfg" ] || { echo "  ❌ 缺少 .agents/config.json，无法导入平台配置" >&2; rm -rf "$tmpd"; return 1; }
  cp "$cfg" "$tmpd/cfg.json"
  for rel in .codex/config.toml .cursor/mcp.json .mcp.json .claude/settings.json; do
    [ -f "$root/$rel" ] && [ ! -L "$root/$rel" ] || continue
    sdlc_backup "$root" "$bak" "$rel"
    if git -C "$root" ls-files --error-unmatch "$rel" >/dev/null 2>&1; then
      echo "  ⚠ $rel 已被 git 跟踪，它现在是生成文件，请执行：git rm --cached $rel"
    fi
  done

  # 1) .codex/config.toml
  if [ -f "$root/.codex/config.toml" ]; then
    _sdlc_import_toml "$root" "$tmpd/toml-servers.json" "$tmpd/extra.toml"
    echo '{}' > "$tmpd/conflicts.json"
    jq --slurpfile s "$tmpd/toml-servers.json" --rawfile x "$tmpd/extra.toml" '
      .mcpServers = ((.mcpServers // {}) + $s[0])
      | .codex = (.codex // {})
      | .codex.extraToml = (if ($x | length) == 0 then (.codex.extraToml // "")
                            elif ((.codex.extraToml // "") | length) == 0 then $x
                            else (.codex.extraToml + "\n" + $x) end)
    ' "$tmpd/cfg.json" > "$tmpd/next.json" || { rm -rf "$tmpd"; return 1; }
    jq -r --slurpfile s "$tmpd/toml-servers.json" '(.mcpServers // {}) as $m | $s[0] | to_entries[]
      | select($m[.key] != null and $m[.key] != .value) | .key' "$tmpd/cfg.json" >> "$tmpd/conflicts.txt"
    mv "$tmpd/next.json" "$tmpd/cfg.json"
    echo "  ✔ 已导入 .codex/config.toml"
  fi

  # 2) .cursor/mcp.json，3) .mcp.json（后者优先）
  for rel in .cursor/mcp.json .mcp.json; do
    src="$root/$rel"
    [ -f "$src" ] || continue
    jq -e 'type == "object"' "$src" >/dev/null 2>&1 || { echo "  ⚠ $rel 不是合法 JSON，跳过导入（已备份）"; continue; }
    jq '(.mcpServers // {}) | map_values(
          ({transport: (if (.type // "") != "" then .type elif .url then "http" else "stdio" end)}) + del(.type))' \
      "$src" > "$tmpd/servers.json"
    jq -r --slurpfile s "$tmpd/servers.json" '(.mcpServers // {}) as $m | $s[0] | to_entries[]
      | select($m[.key] != null and $m[.key] != .value) | .key' "$tmpd/cfg.json" >> "$tmpd/conflicts.txt"
    jq --slurpfile s "$tmpd/servers.json" '.mcpServers = ((.mcpServers // {}) + $s[0])' "$tmpd/cfg.json" > "$tmpd/next.json" \
      && mv "$tmpd/next.json" "$tmpd/cfg.json"
    echo "  ✔ 已导入 $rel"
  done

  # 4) .claude/settings.json：去掉 sdlc hooks
  if [ -f "$root/.claude/settings.json" ]; then
    if jq -e 'type == "object"' "$root/.claude/settings.json" >/dev/null 2>&1; then
      jq '
        if .hooks then
          .hooks |= (with_entries(.value |= (map(.hooks |= map(select((.command // "") | test("sdlc-(pre-edit-guard|post-edit-check)") | not)))
                                             | map(select((.hooks | length) > 0))))
                     | with_entries(select((.value | length) > 0)))
          | if .hooks == {} then del(.hooks) else . end
        else . end' "$root/.claude/settings.json" > "$tmpd/settings.json"
      jq --slurpfile s "$tmpd/settings.json" '.claude = (.claude // {}) | .claude.settings = ((.claude.settings // {}) * $s[0])' \
        "$tmpd/cfg.json" > "$tmpd/next.json" && mv "$tmpd/next.json" "$tmpd/cfg.json"
      echo "  ✔ 已导入 .claude/settings.json（sdlc hooks 由同步脚本注入，不写入 config.json）"
    else
      echo "  ⚠ .claude/settings.json 不是合法 JSON，跳过导入（已备份）"
    fi
  fi

  if [ -s "$tmpd/conflicts.txt" ]; then
    conflicts="$(sort -u "$tmpd/conflicts.txt" | tr '\n' ' ')"
    echo "  ⚠ 同名 MCP 服务器内容不同，已按 .mcp.json > .cursor/mcp.json > .codex/config.toml > 默认 取值: $conflicts"
  fi
  cp "$tmpd/cfg.json" "$cfg"
  rm -rf "$tmpd"
}
