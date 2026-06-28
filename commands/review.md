---
description: 单独运行 Codex 审查，不触发其他流程
argument-hint: proposal|code <迭代目录>
---

执行 `sdlc-workflow review`，参数：$ARGUMENTS

解析参数格式：`review <proposal|code> <迭代目录>`

## Gate 1：设计审查（`review proposal <迭代目录>`）

使用 Codex CLI 审查 `<迭代目录>/design.md` + `tasks.md`：
- 需求覆盖度：requirements.md 每个 AC-ID 是否在 tasks.md 被引用
- tasks.md AC 是否保留 Given-When-Then + 场景维度
- 是否存在模糊不可验证的 AC
- 每个 Requirement 是否至少覆盖 happy-path + error

```bash
codex exec --full-auto "审查 <迭代目录>/design.md 和 tasks.md ..."
```

结果：PASS 输出 `✅ 设计 Review PASS`；FAIL 输出具体问题，建议修订后重跑。

## Gate 2：代码审查（`review code <迭代目录>`）

使用 Codex CLI 审查代码变更 + tasks.md 完成状态：
- 代码是否符合 design.md 设计
- tasks.md 勾选状态是否与实现一致
- 安全、性能、规范问题

```bash
codex exec --full-auto "审查代码变更和 tasks.md 完成度 ..."
```

结果：PASS 输出 `✅ Code Review PASS`；FAIL 输出具体问题。

> 注意：Codex CLI 不可用时中止，不自动跳过。
