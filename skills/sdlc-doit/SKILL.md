---
name: sdlc-doit
description: >-
  Fully automatic SDLC — run proposal → apply → [qa] → accept → pr without
  stopping, straight to a PR. Use when the user wants doit / 全自动 / 一路到 PR and
  fully trusts the agent. --review enables Codex Gate 1+2; --qa inserts browser
  acceptance before committing.
---

# SDLC · doit（全自动）

> 核心目录 `SDLC_CORE`：按核心 skill 的 SKILL.md「核心目录（SDLC_CORE）」解析——核心 SKILL.md 在本 skill 同级的 `../sdlc-workflow/SKILL.md`，其次 `${CLAUDE_PLUGIN_ROOT}/sdlc-workflow/SKILL.md`；两处都不存在 → 报错「缺少核心 skill sdlc-workflow，请执行 `npx skills add evan-e2438927/sdlc-workflow --skill sdlc-workflow`」并停止。

内部串联 `proposal + apply + [qa] + accept + pr` 不停顿（⓪→①…→⑬）。适用于完全信任 AI 处理的场景。

## 与分步命令的区别

- 不在 `pending_review` 停顿：④ 后经状态脚本写入 `pending_review`（`--by doit --flags '{"review":…,"qa":…,"agents":…}'`）并立即转 `approved`，不等人工审核，直接需求到 PR。
- 中断后（token 耗尽 / 会话关闭）用户要求继续：按 status.json 的 flags 续跑剩余步骤直到 `pr_created`。
- `--qa` 时 qa 发现代码缺陷 → `qa_failed` → 自动进入 apply 修复模式再重跑 qa，按「修复轮数（唯一定义）」计数，超限停下转人工。
- 低置信度需求**自动 assume**（无人值守），不发起询问，标注 `[⚠️ 假设: ...]`，provenance=never-asked。
- `--review` 启用 Gate 1 + Gate 2；`--qa` 在提交前插入步骤 ⑩ 浏览器功能验收。
- `--agents single|multi` 同 apply，决定开发阶段（⑥ ⑦）的执行模式；未指定时读 `AGENT_MODE`（默认 auto）。

## 步骤

⓪ 初始化 + 统一上下文加载 → ①②③④ 需求拆解（clarifier auto-assume）→ [⑤ Gate 1] → ⑥ 开发（打地基 → 前后端角色 → 汇总）→ ⑦ 查漏 → [⑧ Gate 2] → ⑨ lint+unit → [⑩ qa] → ⑪⑫ 文档 + 本地 commit → ⑬ push + PR。

完成输出 `✅ PR: <url> | 变更: N files | 测试: 全部通过`。

> 完整规范见 `sdlc-workflow` skill 的 `SKILL.md`（doit 模式）及各 `references/`。
