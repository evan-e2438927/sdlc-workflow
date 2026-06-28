---
description: 全自动模式，proposal + apply + accept + pr 不停顿直接出 PR
argument-hint: [--review] [--qa] <需求描述> | file:///path | https://url
---

执行 `sdlc-workflow doit`，参数：$ARGUMENTS

读取并遵循 `${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/SKILL.md` 中的完整规范。当前执行 **doit** 全自动模式（proposal + apply + [qa] + accept + pr 不停顿，步骤 ⓪→①→②→③→④→[⑤]→⑥→⑦→[⑧]→⑨→[⑩]→⑪→⑫→⑬）。

## 与分步命令的区别

- 不写 `pending_review` 暂停点，不等待人工审核，直接从需求跑到 PR
- 低置信度需求自动 assume，不询问用户（标注 [⚠️ 假设: ...]）
- `--review` 启用 Gate 1 + Gate 2；`--qa` 在提交前插入浏览器功能验收（步骤 ⑩）

## 执行步骤

**⓪** 初始化（fresh/existing 检测，统一上下文加载读 `.claude/.sdlc-config`，创建迭代目录）

**①②③④** requirements-ingestion → clarifier（auto-assume）→ design-generator → task-generator（按 track 拆分）

**[⑤ Gate 1]** 仅 `--review`：Codex 设计审查

**⑥⑦** 开发（frontend/backend/unit-test track）+ 单元测试生成

**[⑧ Gate 2]** 仅 `--review`：Codex 代码审查

**⑨ test-pipeline** lint → unit（两阶段）

**[⑩ qa]** 仅 `--qa`：编写并执行 Playwright 浏览器功能验收（qa track）

**⑪⑫** docs-updater → git-committer（本地 commit）

**⑬** pr-creator：push → gh pr create

完成输出：`✅ PR: <url> | 变更: N files | 测试: 全部通过`
