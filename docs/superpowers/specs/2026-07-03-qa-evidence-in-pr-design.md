# QA 截图证据进 PR 设计

- 日期：2026-07-03
- 状态：已批准（方案 A），待实现
- 范围：让 qa 阶段产出「成功态验收截图」，并在 pr 阶段把它们作为证据嵌入 PR body

## 背景与缺口

1. qa 现在**只在失败时截图**（`flow-qa.md`：`失败时截图保存到 tests/reports/<slug>/screenshots/`）。没有「验收通过」的正向证据图。
2. 上一改动已把 `tests/reports/**` 的二进制（截图/playwright/cdp）加入 `.gitignore`，避免仓库噪音。
3. PR body 要显示图，必须是 GitHub 能渲染的**绝对 URL**（markdown 相对路径在 PR 描述里不渲染）。

## 方案 A（选定）

**每个 E2E 场景通过时截一张成功图，存入按迭代归档的、已提交的 `evidence/` 目录，pr 阶段用 raw URL 嵌入 PR body。**

- 证据图路径：`docs/iterations/<date>/<seq>-<slug>-<type>/evidence/<Scenario-ID>.png`
- 该路径在 `docs/` 下、**不在** 上一步的 `tests/reports/**` 忽略范围内 → 由 accept 的 `git add -A` 自然提交，pr push 后 branch raw URL 即可解析。
- qa 的嘈杂 dump（trace、失败诊断图）继续被忽略；只有**每 AC/场景一张精选成功图**入库。这调和了「别塞二进制」与「PR 要证据」两个诉求。

### 被否方案

- **B. GitHub user-attachments CDN 上传**：上传口不在官方 API / `gh`，脚本调用脆弱易失效，不适合自动化流水线。
- **C. 外部存储**（S3/gist/release asset）：需额外基建，过重。

## 影响文件与任务

### Task 1：flow-qa.md —— 成功态截图 + 报告登记

- 步骤二执行循环：在「断言通过」后新增「截成功态证据图 → `docs/iterations/<迭代>/evidence/<Scenario-ID>.png`」；失败截图保持落 `tests/reports/<slug>/screenshots/`（诊断用，不入 PR）。
- 步骤三报告：在 `<slug>-e2e-report.md` 登记各场景证据图相对路径。
- 补一句：`evidence/` 由 accept 提交、被 pr 消费。

### Task 2：12-pr-creator.md —— PR body 嵌入证据

- 在生成 PR body 前推导：`REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)`、`EVIDENCE_DIR="$ITER_DIR/evidence"`。
- 仅当 `EVIDENCE_DIR/*.png` 存在时，构造「验收证据」小节，逐图嵌入：
  `![<name>](https://raw.githubusercontent.com/<REPO>/<CURRENT_BRANCH>/<相对路径>)`
- qa 跳过 / 无证据图 → 优雅省略该节。
- 该节插入到 body 的「测试结果」之后。

## 设计取舍（已定默认）

- **URL 用 branch 形式**（`.../<branch>/...`）：PR 打开期间 branch 存在即可解析；足够覆盖评审场景。（如需合并后永久有效，可改用 commit SHA，本期不做。）
- **每场景一张**，按 Scenario-ID 命名；一个场景覆盖多 AC 时以场景为单位截一张。
- **evidence 目录不加 gitignore**：确认现有忽略规则只针对 `tests/reports/**`，`docs/iterations/**/evidence/*.png` 不受影响。

## 非目标

- 不做 CDN / 外部存储上传。
- 不追溯改写历史里已提交的截图。
- 不改 accept 的提交范围（`git add -A` 已覆盖 evidence 目录）。

## 验证

- 本地用一段 shell 模拟 evidence 目录，验证「有图→生成嵌入 markdown、URL 形态正确」「无图→省略小节」两条分支。
- 人工核对 flow-qa.md 循环新增成功截图、报告登记路径。
