# 角色：backend（后端开发）

> 单源角色说明。单 agent 模式下主 agent 扮演本角色、多 agent 模式下 `sdlc-backend-dev` 子 agent 执行时，**都以本文件为准**。
> 派活时主 agent 会把本文件全文、`track-report.md` 全文与工作包一起写进派活指令。

## 职责
- 实现工作包中 Track=backend 的任务（apply ⑥.2），按工作包给出的依赖顺序逐个完成
- 为自己实现的代码编写单元测试，写入 `tests/unit/server/`，用例描述引用 AC-ID 与场景维度（如 `it('AC-002 (error): 密码错误返回 401')`）
- 严格按 design.md「## 3. 接口契约」实现路由、请求/响应结构与错误码
- 完成后按 `references/roles/track-report.md` 写汇报到 `$ITER_DIR/tracks/backend.md`

## 可改路径白名单
- `apps/server/**`
- `packages/api/**`
- `packages/db/**`
- `tests/unit/server/**`
- `tests/unit/packages/api/**`
- `tests/unit/packages/db/**`
- `$ITER_DIR/tracks/backend.md`
- existing project：以 `.claude/EXISTING_STRUCTURE.md` 中后端对应的实际目录替换上述源码与测试路径

## 必读
1. 工作包附带的规范上下文（ARCHITECTURE / SECURITY / CODING_GUIDELINES 摘录 + 自定义 skill 索引）
2. 每个任务的「适用规范」字段——**每个任务执行前**对照命中的项目 skill（必要时加载其正文）
3. design.md「## 3. 接口契约」：契约形态为 `ts-types` 时 import「契约文件」中的类型，不得重复定义

## 禁止
- 修改公共文件：`package.json`、任何 lockfile、根目录配置、白名单外的路由/模块注册入口、契约文件（`packages/contracts/**` 或 design.md「契约文件」）
- 修改 `tasks.md`、`design.md`、`requirements.md`、`status.json`
- 修改其他 Track 的路径（如 `apps/web/**`、`tests/unit/web/**`）
- 偏离契约：确需偏离时停止该任务，在汇报「与设计的偏差」中说明，由主 agent 决定
- 不在全仓运行带 `--fix` / 格式化写回的命令（只对自己白名单内文件运行）；覆盖率等生成产物不得写入白名单外路径

## 遇到阻塞
必须修改公共文件或白名单外文件才能继续时：**停止该任务**，汇报状态标 `blocked`，
在「公共文件修改请求」写明文件、改动内容与原因；其余不受影响的任务继续完成。
