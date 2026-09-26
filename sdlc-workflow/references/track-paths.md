# Track 路径规则（唯一来源）

本文件下方的 JSON 是 Track 路径、公共文件、测试文件命名模式的**唯一来源**。

- `04-task-generator.md` §2.0（Track 归属）、`05-design-reviewer.md` §2.2（Gate 1 `TRACK_PATH_RULES`）、
  `roles/*.md`（single 模式可写范围）、`flow-apply.md`「越界守卫」（允许清单生成）都引用这里。
- `08-code-reviewer.md` 的三份 Codex 指令（Codex 看不到插件目录）与 `templates/workflow-rules.md.tpl`
  （安装到用户项目）保留**内联副本**；`scripts/__tests__/test-track-paths-consistency.sh` 负责核对副本与本文件一致。
  **改这里就要同步改那两处，否则测试失败。**
- existing project：`.claude/EXISTING_STRUCTURE.md` 的实际目录映射优先于 `tracks` 默认前缀。
- `public_files` 只允许主 agent 修改；每个迭代还要追加 design.md「契约文件」登记的路径。
- 路径均相对项目根；`<root-config-files>` 是占位，指根目录下的配置文件（由 infra 任务处理）。

```json
{
  "tracks": {
    "frontend":  ["apps/web/", "apps/native/", "packages/ui/", "tests/unit/web/", "tests/unit/packages/ui/"],
    "backend":   ["apps/server/", "packages/api/", "packages/db/", "tests/unit/server/", "tests/unit/packages/api/", "tests/unit/packages/db/"],
    "shared":    ["packages/config/", "packages/env/", "packages/auth/", "packages/contracts/", "tests/unit/packages/config/", "tests/unit/packages/env/", "tests/unit/packages/auth/", "tests/unit/packages/contracts/"],
    "infra":     ["db/migrations/", ".github/workflows/", "<root-config-files>"],
    "unit-test": ["tests/unit/"],
    "qa":        ["tests/e2e/"]
  },
  "public_files": ["package.json", "**/package.json", "pnpm-lock.yaml", "package-lock.json", "yarn.lock", "bun.lockb", "tsconfig*.json", "**/tsconfig*.json", "turbo.json", "pnpm-workspace.yaml", "packages/contracts/**"],
  "test_file_patterns": ["*.test.*", "*.spec.*"]
}
```
