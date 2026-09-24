# Track 汇报模板

每个角色完成自己的工作后，写 `$ITER_DIR/tracks/<track>.md`（track ∈ `foundation` / `backend` / `frontend` / `test`）。
单 agent 模式下由主 agent 写，多 agent 模式下由对应子 agent 写——**格式完全相同**，
主 agent 汇总（apply ⑥.3 / ⑦.1）与断点续跑只依赖这些文件，不关心执行者是谁。
`foundation` 由主 agent 在 ⑥.1 打地基完成后写。

```markdown
# Track 汇报：<track>

- 状态: done | partial | blocked
- 执行者: main | sdlc-<track>-dev
- 完成时间: <ISO8601>

## 完成的任务与 AC
- T-003: AC-001 ✅, AC-002 ✅, AC-004 ❌（原因）

## 修改的文件
- apps/server/src/routes/auth/login.ts

## 新增的测试
- tests/unit/server/auth/login.test.ts（覆盖 AC-001, AC-002）

## 公共文件修改请求
- package.json: 新增依赖 bcrypt@^5（原因：密码哈希）   # 无则写 "无"

## 与设计的偏差
- 无

## 阻塞说明（仅 blocked）
- <被什么阻塞，需要主 agent 做什么>
```

规则：
- 「修改的文件」「新增的测试」必须完整列出本角色改动的每个文件（含新建），主 agent 据此做越界检测。
- 状态含义：`done` 全部任务完成；`partial` 有 AC 未满足但未被阻塞（写明原因）；`blocked` 需主 agent 处理公共文件请求后才能继续。
