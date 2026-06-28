---
name: sdlc-doit
description: >-
  Fully automatic SDLC — run proposal → apply → [qa] → accept → pr without
  stopping, straight to a PR. Use when the user wants doit / 全自动 / 一路到 PR and
  fully trusts the agent. --review enables Codex Gate 1+2; --qa inserts browser
  acceptance before committing.
---

# SDLC · doit（全自动）

内部串联 `proposal + apply + [qa] + accept + pr` 不停顿（⓪→①…→⑬）。适用于完全信任 AI 处理的场景。

## 与分步命令的区别

- 不写 `pending_review` 暂停点，不等人工审核，直接需求到 PR。
- 低置信度需求**自动 assume**（无人值守），不发起询问，标注 `[⚠️ 假设: ...]`，provenance=never-asked。
- `--review` 启用 Gate 1 + Gate 2；`--qa` 在提交前插入步骤 ⑩ 浏览器功能验收。

## 步骤

⓪ 初始化 + 统一上下文加载 → ①②③④ 需求拆解（clarifier auto-assume）→ [⑤ Gate 1] → ⑥⑦ 开发 + 单测 → [⑧ Gate 2] → ⑨ lint+unit → [⑩ qa] → ⑪⑫ 文档 + 本地 commit → ⑬ push + PR。

完成输出 `✅ PR: <url> | 变更: N files | 测试: 全部通过`。

> 完整规范见 `sdlc-workflow` skill 的 `SKILL.md`（doit 模式）及各 `references/`。
