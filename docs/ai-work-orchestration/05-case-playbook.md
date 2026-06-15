# AI Loop 案例执行指南

## 定位

这份指南用于把一个低风险任务跑成可分享、可复盘的 AI 工程实践案例。

它的重点不是“让 AI 自动完成所有事情”，而是让每次 AI 参与都有清晰边界、执行证据、人工判断和下一轮决策。

## 适用场景

优先选择以下任务作为首批案例：

- 文档补充、说明整理、案例复盘。
- 脚本帮助信息或非核心输出格式优化。
- 本地测试、校验命令或 dry-run 能覆盖的改动。
- 不涉及生产系统、远端发布、批量数据或权限变更的任务。

暂不适合作为首批案例：

- 生产故障处理。
- 自动部署、远端写库、批量修改。
- 跨多个仓库的大重构。
- 验证标准不清晰的探索性任务。

如果准备从文档/脚本试点进入真实代码改动，先阅读 `06-code-change-gate.md`，确认任务满足代码改动准入门禁。

## 输入

每个案例开始前至少要具备以下输入：

- `Project`：所属 Multica 项目或本地实践主题。
- `Issue`：要处理的具体任务或本地任务草案。
- `Repo`：目标仓库路径。
- `Task file`：本地 Markdown 任务文件。
- `Verification command`：可重复执行的本地验证命令。
- `Approval policy`：哪些副作用允许自动执行，哪些必须人工确认。

## 执行步骤

### 1. 明确任务

先把任务写成本地 `task.md` 或 `tasks/*.md`，至少包含：

- 背景
- 目标
- 交付物
- 验收标准
- 验证命令
- 安全边界

### 2. 分类风险

按副作用而不是按代码行数判断风险：

- 低风险：只改本地文档、模板、测试样例。
- 中风险：改脚本行为、局部业务逻辑、需要跑测试。
- 高风险：远端写入、生产系统、批量处理、部署发布。

低风险任务可以直接推进本地改动；中高风险任务必须先列出副作用并等待确认。

### 3. 执行本地改动

默认只在本地完成交付物，不自动执行远端动作。

执行过程中保留最小必要改动，避免顺手修复无关问题。

### 4. 生成证据包

每个案例至少保留以下证据：

- `task.md`：任务定义。
- `summary.md`：执行摘要。
- `stage-report.md`：阶段报告。
- `multica-comment.md`：可选远端评论草稿。
- 验证命令输出或验证结论。

如果使用 `scripts/multica-loop.sh`，优先引用其生成的 `runs/<run-id>/stage-report.md`。

需要人工复核证据完整性时，可以生成本地证据清单：

```bash
./scripts/evidence-checklist.sh --run-id <run-id>
```

如需把清单纳入证据包，可显式写入本地文件：

```bash
./scripts/evidence-checklist.sh --run-id <run-id> --output runs/<run-id>/evidence-checklist.md
```

该脚本只读取本地 `runs/` 目录，不访问 Multica，也不会产生远端写入。

当一个案例包含多个 run 时，可以生成汇总索引：

```bash
./scripts/evidence-index.sh --pattern 'FUZ-554*'
```

如需把索引纳入证据包，可显式写入本地文件：

```bash
./scripts/evidence-index.sh --pattern 'FUZ-554*' --output runs/FUZ-554-evidence-index-pilot/index.md
```

该脚本同样只读取本地 `runs/` 目录，不访问 Multica，也不会产生远端写入。

### 5. 复盘与决策

复盘时只回答三个问题：

- 目标是否达成？
- 证据是否足够让人复核？
- 下一步是否需要远端写入或状态变更？

远端写入必须由人确认后再执行。

当一个案例已经包含多个阶段证据时，可以生成一份面向人的复核包：

```bash
./scripts/review-packet.sh --case FUZ-554 --pattern 'FUZ-554*'
```

如需纳入证据包，可显式写入本地文件：

```bash
./scripts/review-packet.sh --case FUZ-554 --pattern 'FUZ-554*' --output runs/FUZ-554-review-packet-pilot/review-packet.md
```

如果本轮包含真实代码改动，可把 patch summary 一并纳入复核包：

```bash
./scripts/review-packet.sh --case FUZ-554 --pattern 'FUZ-554*' --include-patch-summary runs/<run-id>/patch-summary.md --output runs/<run-id>/review-packet.md
```

复核包用于辅助人类判断是否可分享、是否缺证据、是否需要远端回写；它不代表自动批准。

复用这套本地工具链前，可以先运行总自检：

```bash
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*'
```

如需先查看自检会执行哪些本地检查：

```bash
./scripts/verify-toolchain.sh --list-checks
```

如需保存自检报告：

```bash
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --output runs/FUZ-554-toolchain-verify-pilot/verification-report.md
```

该命令只验证本地脚本和本地 `runs/` 证据，不读取 Multica，也不会产生远端写入。

在准备分享或进入正式复核前，可以启用 strict evidence gate，要求匹配到的每个 run 都具备 core evidence：

```bash
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --strict --output runs/<run-id>/verification-report.md
```

进入真实代码改动后，应为 patch 生成本地摘要：

```bash
./scripts/patch-summary.sh --base HEAD --output runs/<run-id>/patch-summary.md
```

Patch summary 只读取本地 `git diff` 元信息，用于先审查改动范围、文件列表和 diff stat；它不替代完整 diff 复核。

## 状态策略

默认使用 `conservative`：

- dry-run 通过只说明编排链路成立，不代表业务完成。
- 普通业务任务不因 dry-run `PASSED` 自动进入 `in_review`。
- 只有工具链自身验证或明确人工确认时，才使用 `validation`。
- 批量观察或只生成报告时，使用 `no-status`。

本地自查可以运行：

```bash
./scripts/multica-loop.sh --policy-help
```

该命令只输出策略说明，不读取 Multica issue，也不产生远端写入。

## 分享产物

每个案例完成后，建议沉淀三类材料：

- 面向团队的短报告：目标、过程、结果、下一步。
- 面向工程复用的模板：任务文件、复盘模板、验证命令。
- 面向管理视角的指标：节省了什么、风险如何被控制、哪些环节仍需人工。

## 完成定义

一个案例只有同时满足以下条件，才算完成：

- 任务目标明确。
- 本地交付物已产生。
- 验证命令已执行或说明无法执行的原因。
- 证据包路径清晰。
- 远端副作用已明确：未执行、已授权执行或等待确认。
- 下一轮动作明确。
