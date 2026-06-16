# AI 工作编排实践日志

## 2026-06-15：方向确立

### 背景

我们将 Multica、ai-loop、Codex、Claude、OpenClaw 的联动作为一个先锋 AI 工程实践方向推进。

这不是一次简单工具开发，而是一次关于 AI 工作闭环的工程化尝试。

### 当前状态

- Multica 已连接到 `Fuzhe` workspace。
- 本机 daemon `019e2acf...` 下的 `claude`、`codex`、`openclaw` runtime 已在线。
- 已新增 `Codex-顾实` 作为 Codex 主力工程智能体。
- `Xcode` 作为 Codex 二意见/救火智能体保留。
- 两个 Codex 智能体都已切到实际验证可用的 GPT 模型 `ppio/pa/gpt-5.5`。
- 已清理模型/连通性测试 issue。
- 已将当前真实活跃 issue 重新分派，形成 Codex 主力、Xcode 二意见、黑墙调度的盘面。

### 关键决策

1. Multica 作为控制台，不作为执行事实来源。
2. ai-loop artifacts 作为执行事实来源。
3. 第一阶段只做本地安全桥接，不做自动远端写入。
4. 每一步都要产出可分享文档。
5. 先做单 issue 链路，再做队列和调度。

### 本轮产出

- `docs/ai-work-orchestration/00-vision.md`
- `docs/ai-work-orchestration/01-domain-model.md`
- `docs/ai-work-orchestration/02-phase1-mvp.md`
- `docs/ai-work-orchestration/logbook.md`

### 下一步

进入 Phase 1 工程实现前，需要确认：

- 首个试点 issue。
- 目标 repo。
- dry-run 验证命令。
- 是否只生成 comment 草稿。

建议首个试点选择一个真实但低风险的 issue，先验证链路，而不是直接处理最高风险发布任务。

## 2026-06-15：Multica 项目化

### 目标

将“AI 工作编排实践”从零散 issue 上升为 Multica 项目，便于承载阶段目标、工作项、分享产物和复盘记录。

### 执行

创建 Multica 项目：

- 项目名：`AI 工作编排实践：Multica × ai-loop`
- Project ID：`20fc419d-038f-4ef2-9ea7-1ba0c30cb136`
- 初始状态：`planned`，随后更新为 `in_progress`

首批项目工作项：

- `FUZ-551`：Phase 0：先锋实践文档底座，状态 `in_review`
- `FUZ-552`：Phase 1：Multica 到 ai-loop 的安全桥接 MVP，状态 `todo`
- `FUZ-553`：Phase 1：回写与状态策略，状态 `todo`
- `FUZ-554`：Phase 1：首个案例复盘，状态 `todo`

### 决策

- 项目是战略容器，issue 是战术工作单元。
- 后续所有 Loop 集成相关工作都挂到该项目下。
- Phase 0 文档底座已进入复核，Phase 1 工程实现从 `FUZ-552` 开始。

### 问题

首次带 `lead/status/icon` 创建项目时服务端返回 500，已降级为最小参数创建。后续如需 lead/icon/status，可单独更新。

### 下一步

围绕 `FUZ-552` 创建本地任务文件，进入窗口内 Loop 协议后执行 Phase 1 MVP 的本地开发。

## 2026-06-15：Phase 1 MVP 初版实现

### 目标

围绕 `FUZ-552` 实现第一条本地安全桥接链路：Multica issue 到本地 ai-loop dry-run，再到 comment 草稿。

### 执行

- 创建本地任务文件：`tasks/FUZ-552-multica-loop-mvp.md`
- 新增 wrapper：`scripts/multica-loop.sh`
- wrapper 默认行为：读取 issue、生成 `tasks/FUZ-xxx.md`、执行 `ai-loop run --dry-run`、生成 `runs/<run-id>/multica-comment.md`

### 安全边界

- 默认不写 Multica comment。
- 默认不修改 Multica status。
- 默认只执行 ai-loop dry-run。
- `--write-comment` 当前只提示，不真实发出写操作。

### 下一步

执行本地验证：`bash -n scripts/multica-loop.sh`、`scripts/multica-loop.sh --help`，再用 `FUZ-552` 做一次真实 dry-run 链路验证。

### Evidence

本地验证已通过：

- `bash -n scripts/multica-loop.sh`
- `./scripts/multica-loop.sh --help`
- `./bin/ai-loop --help`
- `python3 -m py_compile lib/ai_loop/*.py`

`FUZ-552` dry-run 链路已跑通：

- Task：`tasks/FUZ-552.md`
- Run：`runs/FUZ-552-phase1-mvp-dry-run/run.json`
- Summary：`runs/FUZ-552-phase1-mvp-dry-run/summary.md`
- Comment 草稿：`runs/FUZ-552-phase1-mvp-dry-run/multica-comment.md`
- 结果：`PASSED`

该轮没有写回 Multica，也没有修改 issue 状态。

### 回归与增强

随后增强 `scripts/multica-loop.sh`：

- 增加 `stage-report.md` 阶段报告产物。
- 增加 `--write-comment` 显式回写开关。
- 增加 `--write-status` 显式状态同步开关。
- 默认行为仍然不写远端。

回归 run：

- Run：`runs/FUZ-552-phase1-regression/run.json`
- Summary：`runs/FUZ-552-phase1-regression/summary.md`
- Comment 草稿：`runs/FUZ-552-phase1-regression/multica-comment.md`
- Stage report：`runs/FUZ-552-phase1-regression/stage-report.md`
- 结果：`PASSED`
- 远端写入：未执行

## 2026-06-15：Phase 2 首次显式回写

### 目标

在人工确认后，对 `FUZ-552` 执行一次集中远端写入，验证 comment 回写和状态同步链路。

### 执行

- 写入 Multica comment：`08ca3cf6-47cd-4c4e-a25c-f38701458562`
- 将 `FUZ-552` 状态更新为 `in_review`
- 复查项目：`AI 工作编排实践：Multica × ai-loop` 仍为 `in_progress`

### Evidence

- Issue：`FUZ-552`
- 状态：`in_review`
- Project ID：`20fc419d-038f-4ef2-9ea7-1ba0c30cb136`
- Comment ID：`08ca3cf6-47cd-4c4e-a25c-f38701458562`
- 回写时间：`2026-06-15T16:33:21+08:00`

### 决策

远端写入必须继续保持显式授权。后续可以把 `--write-comment` 和 `--write-status` 作为 Phase 2 能力，但默认仍不启用。

## 2026-06-15：Phase 3 状态策略精炼

### 目标

将 Multica 状态同步从简单 pass/fail 映射升级为策略化、可解释、可审计的状态决策。

### 执行

更新 `scripts/multica-loop.sh`：

- 支持 `--status-policy conservative|validation|no-status`。
- 在 `stage-report.md` 中记录 `Mapped status` 与 `Mapping reason`。
- 远端写入结果拆分为 `Comment written` 和 `Status written`。
- 远端写入失败时保留 `multica-write-error.log`，避免只在终端里丢失证据。

### 验证

以 `FUZ-553` 执行三组只读回归：

- `FUZ-553-policy-v2-conservative`：dry-run `PASSED`，映射 `todo`。
- `FUZ-553-policy-v2-validation`：dry-run `PASSED`，映射 `in_review`。
- `FUZ-553-policy-v2-no-status`：dry-run `PASSED`，映射 `none`。

三组均未写 Multica comment，未改 Multica status。

### 决策

- 普通业务 issue 默认使用 `conservative`。
- 桥接工具自身验证可以使用 `validation`。
- 批量队列或观察模式优先使用 `no-status`。
- 状态写入继续要求显式 `--write-status` 和人工批准。

### 下一步

进入 `FUZ-554` 首个案例复盘，验证这套机制能否支撑真实任务闭环与分享文档沉淀。

### FUZ-553 远端回写

已在人工确认后完成 `FUZ-553` 的远端回写：

- Comment ID：`d96c844e-e33b-47a5-b6ab-bb0f628da949`
- Status：`in_review`
- 本地记录：`runs/FUZ-553-phase3-writeback/summary.md`

该回写用于标记状态策略阶段进入复核，不代表普通业务 issue 可以默认使用 `validation` 策略。

## 2026-06-15：Phase 4 首个案例复盘

### 目标

用 `FUZ-554` 验证从 Multica 项目工作项到本地 ai-loop 证据包，再到分享文档的首个案例闭环。

### 执行

- 读取 `FUZ-554` 并生成 `tasks/FUZ-554.md`。
- 执行 `FUZ-554-first-case-dry-run`。
- 使用 `conservative` 策略，dry-run `PASSED` 映射为 `todo`。
- 新增案例复盘文档：`docs/ai-work-orchestration/cases/FUZ-554/README.md`。
- 新增通用复盘模板：`docs/ai-work-orchestration/cases/FUZ-554/review-template.md`。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-4-first-case.md`。

### 结论

首个元流程案例闭环成立，但它仍不是业务任务完成证据。下一步需要进入一个真实低风险试点，验证代码/文档改动类任务的完整闭环。

## 2026-06-15：FUZ-554-B 文档型真实低风险试点

### 目标

在 `FUZ-554` 元流程案例之后，选择文档指南作为第一个真实低风险交付物，验证“任务草案 → 本地文档改动 → 验证 → 证据沉淀”的闭环。

### 执行

- 新增任务草案：`tasks/FUZ-554-doc-guide-pilot.md`。
- 新增案例执行指南：`docs/ai-work-orchestration/05-case-playbook.md`。
- 更新 `docs/ai-work-orchestration/cases/FUZ-554/README.md`，把文档型试点接到首个案例复盘后续。

### 边界

- 本轮只修改本地文档。
- 未写 Multica comment。
- 未修改 Multica status。
- 未 push、未 commit、未创建 MR。

### 下一步

执行本地验证，并根据验证结果决定是否把 `FUZ-554` 的案例复盘 comment 回写到 Multica。

## 2026-06-15：文档入口索引完善

### 目标

把分散的理念、路线、案例和报告连接成一个总入口，方便团队从一个文档进入整个实践体系。

### 执行

- 新增 `docs/ai-work-orchestration/README.md` 作为总入口索引。
- 在 `03-sharing-roadmap.md` 中补充实践入口链接。

### 边界

- 仅修改本地文档。
- 未写 Multica comment。
- 未修改 Multica status。

### 下一步

如果需要对外分享，优先从 `docs/ai-work-orchestration/README.md` 开始，再展开到具体阶段和案例。

### FUZ-554 远端回写

已在人工确认后完成 `FUZ-554` 的远端回写：

- Comment ID：`b1f07e79-c9b8-4064-aea5-f0d960513dbf`
- Status：`in_review`
- 本地记录：`runs/FUZ-554-doc-guide-pilot/writeback-summary.md`

该回写表示首个案例复盘与文档型真实低风险试点已进入人工复核。

## 2026-06-15：FUZ-554-C 脚本型真实低风险试点

### 目标

在文档型试点之后，用一个小型脚本增强验证“本地脚本改动 → 本地验证 → 证据沉淀”的闭环。

### 执行

- 为 `scripts/multica-loop.sh` 新增 `--policy-help`。
- 在 `docs/ai-work-orchestration/05-case-playbook.md` 中补充本地自查入口。
- 新增任务草案：`tasks/FUZ-554-script-policy-help-pilot.md`。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-5-script-pilot.md`。
- 新增证据包：`runs/FUZ-554-script-policy-help-pilot/`。

### 验证

- `bash -n scripts/multica-loop.sh`：通过。
- `./scripts/multica-loop.sh --policy-help`：通过。
- `./scripts/multica-loop.sh --policy-help | rg "conservative|validation|no-status|--write-comment|--write-status"`：通过。

### 边界

- 未读取 Multica issue。
- 未写 Multica comment。
- 未修改 Multica status。
- 未 push、未 commit、未创建 MR。

### 下一步

等待人工确认是否将本轮脚本型试点结果追加回写到 `FUZ-554`。

### FUZ-554-C 远端回写

已在人工确认后追加 `FUZ-554` 的脚本型试点 comment：

- Comment ID：`a6bbbecc-361d-4bce-aba5-694f3afb3f71`
- Status changed：`false`
- 本地记录：`runs/FUZ-554-script-policy-help-pilot/writeback-summary.md`

该回写用于补充脚本型真实低风险试点结果，未改变 issue 状态。

## 2026-06-15：FUZ-554-D 证据标准化试点

### 目标

把案例复盘中的证据检查标准化，减少人工从多个 `runs/` 目录翻找文件的成本。

### 执行

- 新增 `scripts/evidence-checklist.sh`。
- 新增任务草案：`tasks/FUZ-554-evidence-checklist-pilot.md`。
- 更新 `docs/ai-work-orchestration/05-case-playbook.md`，补充证据清单用法。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-6-evidence-checklist.md`。

### 边界

- 只读取本地 `runs/` 目录。
- 只在显式 `--output` 时写本地文件。
- 未读取 Multica issue。
- 未写 Multica comment。
- 未修改 Multica status。

### 下一步

执行本地验证，并决定是否把本轮证据标准化试点追加回写到 `FUZ-554`。

### FUZ-554-D 远端回写

已在人工确认后追加 `FUZ-554` 的证据标准化试点 comment：

- Comment ID：`f94c074b-9b3a-4a4c-857d-25f0080d1897`
- Status changed：`false`
- 本地记录：`runs/FUZ-554-evidence-checklist-pilot/writeback-summary.md`

该回写用于补充 evidence checklist 试点结果，未改变 issue 状态。

## 2026-06-15：FUZ-554-E 跨 run 证据索引试点

### 目标

把单个 run 的 evidence checklist 扩展为多 run 的 evidence index，便于复盘 `FUZ-554` 这种逐层推进的案例。

### 执行

- 新增 `scripts/evidence-index.sh`。
- 新增任务草案：`tasks/FUZ-554-evidence-index-pilot.md`。
- 更新 `docs/ai-work-orchestration/05-case-playbook.md`，补充多 run 索引用法。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-7-evidence-index.md`。

### 边界

- 只读取本地 `runs/` 目录。
- 只在显式 `--output` 时写本地文件。
- 未读取 Multica issue。
- 未写 Multica comment。
- 未修改 Multica status。

### 下一步

执行本地验证，并决定是否把多 run 证据索引试点追加回写到 `FUZ-554`。

### FUZ-554-E 远端回写

已在人工确认后追加 `FUZ-554` 的跨 run 证据索引试点 comment：

- Comment ID：`2605dad6-a7b2-4a85-b898-c3455df233a8`
- Status changed：`false`
- 本地记录：`runs/FUZ-554-evidence-index-pilot/writeback-summary.md`

该回写用于补充 evidence index 试点结果，未改变 issue 状态。

## 2026-06-15：FUZ-554-F 复核包生成试点

### 目标

把 evidence checklist 和 evidence index 进一步组织成面向人的 review packet，降低团队复核成本。

### 执行

- 新增 `scripts/review-packet.sh`。
- 新增任务草案：`tasks/FUZ-554-review-packet-pilot.md`。
- 更新 `docs/ai-work-orchestration/05-case-playbook.md`，补充复核包用法。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-8-review-packet.md`。

### 边界

- 只读取本地 `runs/` 目录。
- 只在显式 `--output` 时写本地文件。
- 未读取 Multica issue。
- 未写 Multica comment。
- 未修改 Multica status。

### 下一步

执行本地验证，并决定是否把复核包生成试点追加回写到 `FUZ-554`。

### FUZ-554-F 远端回写

已在人工确认后追加 `FUZ-554` 的复核包生成试点 comment：

- Comment ID：`8090dea3-6d70-403d-a492-c849c8fdaba4`
- Status changed：`false`
- 本地记录：`runs/FUZ-554-review-packet-pilot/writeback-summary.md`

该回写用于补充 review packet 试点结果，未改变 issue 状态。

## 2026-06-15：FUZ-554-G 一页式分享包试点

### 目标

把 `FUZ-554` 的多阶段证据整理成团队可直接阅读的一页式分享稿，完成从复核包到分享材料的转换。

### 执行

- 新增任务草案：`tasks/FUZ-554-share-packet-pilot.md`。
- 新增分享稿：`docs/ai-work-orchestration/share/FUZ-554-one-page.md`。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-9-share-packet.md`。
- 新增证据包：`runs/FUZ-554-share-packet-pilot/`。

### 边界

- 仅修改本地文档和本地证据。
- 未读取 Multica issue。
- 未写 Multica comment。
- 未修改 Multica status。

### 下一步

执行本地验证，并决定是否把分享包试点追加回写到 `FUZ-554`。

### FUZ-554-G 远端回写

已在人工确认后追加 `FUZ-554` 的一页式分享包试点 comment：

- Comment ID：`ecb5b5cb-86a0-4e08-8ba0-5e29b472f271`
- Status changed：`false`
- 本地记录：`runs/FUZ-554-share-packet-pilot/writeback-summary.md`

该回写用于补充 share packet 试点结果，未改变 issue 状态。

## 2026-06-15：FUZ-554-H 工具链自检试点

### 目标

为 `FUZ-554` 沉淀出来的本地 helper scripts 增加一个总验证入口，方便后续复用前快速自检。

### 执行

- 新增 `scripts/verify-toolchain.sh`。
- 新增任务草案：`tasks/FUZ-554-toolchain-verify-pilot.md`。
- 更新 `docs/ai-work-orchestration/05-case-playbook.md`，补充工具链自检用法。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-10-toolchain-verify.md`。

### 边界

- 只读取本地脚本和 `runs/` 目录。
- 只在显式 `--output` 时写本地文件。
- 未读取 Multica issue。
- 未写 Multica comment。
- 未修改 Multica status。

### 下一步

执行本地验证，并决定是否把工具链自检试点追加回写到 `FUZ-554`。

### FUZ-554-H 远端回写

已根据新的 standing policy 追加 `FUZ-554` 的工具链自检试点 comment：

- Comment ID：`62472c2d-49ff-4367-9f53-78ee57fd7000`
- Status changed：`false`
- 本地记录：`runs/FUZ-554-toolchain-verify-pilot/writeback-summary.md`

该回写用于补充 toolchain verify 试点结果，未改变 issue 状态。

## 2026-06-15：Multica 回写 standing policy

### 决策

用户明确授权：后续阶段性 Multica 回写不再逐次请求审批。

### 适用范围

- 有本地证据包和 `multica-comment.md` 草稿的 `FUZ-*` 阶段性 comment 回写。
- 基于已验证策略的 issue status 同步。
- 回写后必须保留本地 `writeback-summary.md` 和 `logbook.md` 记录。

### 不适用范围

- `git push`、`git commit`、MR 创建或合并。
- 生产系统访问、部署、数据库写入、批量破坏性操作。
- 删除文件、清理大目录或不可逆操作。

这些动作仍需单独确认。

## 2026-06-15：FUZ-554-I 真实代码改动准入门禁

### 目标

在进入真实代码改动前，先建立准入门禁，避免从文档/脚本样板直接跳到高风险自动化。

### 执行

- 新增 `docs/ai-work-orchestration/06-code-change-gate.md`。
- 新增任务草案：`tasks/FUZ-554-code-change-gate-pilot.md`。
- 更新 `docs/ai-work-orchestration/05-case-playbook.md`，加入代码改动准入入口。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-11-code-change-gate.md`。

### 边界

- 仅修改本地文档和本地证据。
- 未读取 Multica issue。
- 未写 Multica comment。
- 未修改 Multica status。

### 下一步

执行本地验证，并按 standing policy 把本阶段结果回写到 `FUZ-554`。

### FUZ-554-I 远端回写

已按 standing policy 追加 `FUZ-554` 的真实代码改动准入门禁 comment：

- Comment ID：`287fbef8-a974-4f5f-9b1f-07fe6eafd009`
- Status changed：`false`
- 本地记录：`runs/FUZ-554-code-change-gate-pilot/writeback-summary.md`

该回写用于补充 code change gate 试点结果，未改变 issue 状态。

## 2026-06-15：FUZ-554-J 低风险真实代码改动试点

### 目标

在真实代码改动准入门禁建立后，选择一个低风险脚本增强，验证从 patch 到本地验证和证据包的闭环。

### 执行

- 为 `scripts/verify-toolchain.sh` 新增 `--list-checks`。
- 更新 `docs/ai-work-orchestration/05-case-playbook.md`，补充自检检查列表入口。
- 新增任务草案：`tasks/FUZ-554-real-code-list-checks-pilot.md`。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-12-real-code-list-checks.md`。

### 边界

- 不读取 Multica issue。
- 不修改 Multica status。
- 不 push、不 commit、不创建 MR。
- 不访问生产系统。

### 下一步

执行本地验证，完成证据包后按 standing policy 回写 `FUZ-554` comment。

### FUZ-554-J 远端回写

已按 standing policy 追加 `FUZ-554` 的低风险真实代码改动试点 comment：

- Comment ID：`cbb8527c-a260-4b36-aa49-b5bf3ace2175`
- Status changed：`false`
- 本地记录：`runs/FUZ-554-real-code-list-checks-pilot/writeback-summary.md`

该回写用于补充 real code change 试点结果，未改变 issue 状态。

## 2026-06-15：FUZ-554-K Patch 证据化试点

### 目标

把真实代码改动的 patch 元信息纳入证据体系，降低复核者理解改动范围的成本。

### 执行

- 新增 `scripts/patch-summary.sh`。
- 新增任务草案：`tasks/FUZ-554-patch-summary-pilot.md`。
- 更新 `docs/ai-work-orchestration/05-case-playbook.md`，补充 patch summary 用法。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-13-patch-summary.md`。

### 边界

- 只读取本地 git diff 元信息。
- 未读取 Multica issue。
- 未修改 Multica status。
- 未 push、未 commit、未创建 MR。

### 下一步

执行本地验证，完成证据包后按 standing policy 回写 `FUZ-554` comment。

### FUZ-554-K 远端回写

已按 standing policy 追加 `FUZ-554` 的 Patch 证据化试点 comment：

- Comment ID：`e02b21c8-90e4-4a01-b201-29b709652050`
- Status changed：`false`
- 本地记录：`runs/FUZ-554-patch-summary-pilot/writeback-summary.md`

该回写用于补充 patch summary 试点结果，未改变 issue 状态。

## 2026-06-15：FUZ-554-L Patch Summary 接入工具链自检

### 目标

把 `patch-summary.sh` 纳入 `verify-toolchain.sh`，让 patch 证据化能力也进入工具链 smoke check。

### 执行

- 更新 `scripts/verify-toolchain.sh` 的 `--list-checks`。
- 常规自检新增 `bash -n scripts/patch-summary.sh`。
- 常规自检新增 `patch-summary --help`，避免 clean tree 无 diff 时误失败。
- 新增任务草案：`tasks/FUZ-554-toolchain-patch-summary-pilot.md`。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-14-toolchain-patch-summary.md`。

### 边界

- 未读取 Multica issue。
- 未修改 Multica status。
- 未 push、未 commit、未创建 MR。

### 下一步

执行本地验证，完成证据包后按 standing policy 回写 `FUZ-554` comment。

### FUZ-554-L 远端回写

已按 standing policy 追加 `FUZ-554` 的 Patch Summary 接入工具链自检 comment：

- Comment ID：`1b645196-8996-49bf-9d1c-44e9c7f6de62`
- Status changed：`false`
- 本地记录：`runs/FUZ-554-toolchain-patch-summary-pilot/writeback-summary.md`

该回写用于补充 patch-summary toolchain integration 试点结果，未改变 issue 状态。

## 2026-06-15：FUZ-554-M 证据快照刷新

### 目标

刷新 `FUZ-554` 的全量证据入口，避免早期 evidence index 和 review packet 无法覆盖后续新增 run。

### 执行

- 新增任务草案：`tasks/FUZ-554-evidence-refresh-pilot.md`。
- 刷新 evidence index：`runs/FUZ-554-evidence-refresh-pilot/index.md`。
- 刷新 review packet：`runs/FUZ-554-evidence-refresh-pilot/review-packet.md`。
- 刷新 patch summary：`runs/FUZ-554-evidence-refresh-pilot/patch-summary.md`。
- 刷新 toolchain verification report：`runs/FUZ-554-evidence-refresh-pilot/verification-report.md`。

### 结果

- Run count：`13`
- Runs with core evidence：`13`
- Runs with writeback summary：`11`

### 边界

- 只读取本地 `runs/` 和 git diff 元信息。
- 未读取 Multica issue。
- 未修改 Multica status。
- 未 push、未 commit、未创建 MR。

### 下一步

执行本地验证，完成后按 standing policy 回写 `FUZ-554` comment。

### FUZ-554-M 远端回写

已按 standing policy 追加 `FUZ-554` 的证据快照刷新 comment：

- Comment ID：`dedef6f8-10e1-4d09-8a98-881e8dc43e2b`
- Status changed：`false`
- 本地记录：`runs/FUZ-554-evidence-refresh-pilot/writeback-summary.md`

该回写用于补充 evidence refresh 试点结果，未改变 issue 状态。

## 2026-06-15：FUZ-554-M2 下一真实代码任务候选池

### 目标

在 `FUZ-554` 已完成真实 patch 和证据刷新后，整理下一批真实代码任务候选，避免继续推进时临时选题、扩大风险。

### 执行

- 新增 `docs/ai-work-orchestration/07-next-code-candidates.md`。
- 更新 `docs/ai-work-orchestration/share/FUZ-554-one-page.md` 的证据状态。
- 新增任务草案：`tasks/FUZ-554-next-code-candidates.md`。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-16-next-code-candidates.md`。

### 推荐

默认下一任务选择 `FUZ-554-N Patch Scope Check`，为 `scripts/patch-summary.sh` 增加 scope check 能力。

### 边界

- 仅修改本地文档和本地证据。
- 未读取 Multica issue。
- 未修改 Multica status。
- 未 push、未 commit、未创建 MR。

### 下一步

执行本地验证，完成证据包后按 standing policy 回写 `FUZ-554` comment。

### FUZ-554-M2 远端回写

已按 standing policy 追加 `FUZ-554` 的下一真实代码任务候选池 comment：

- Comment ID：`ac041c57-71b3-4ebd-b6a7-b3c18faa47f8`
- Status changed：`false`
- 本地记录：`runs/FUZ-554-next-code-candidates/writeback-summary.md`

该回写用于补充 next code candidates 结果，未改变 issue 状态。

## 2026-06-15：FUZ-554-N Patch Scope Check

### 目标

把 patch review 中的“是否超出允许范围”工具化，继续推进真实代码改动准入门禁。

### 执行

- 为 `scripts/patch-summary.sh` 新增 `--allow-prefix`。
- 新增任务草案：`tasks/FUZ-554-patch-scope-check-pilot.md`。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-17-patch-scope-check.md`。

### 边界

- 只读取本地 git diff 和 untracked files。
- 未读取 Multica issue。
- 未修改 Multica status。
- 未 push、未 commit、未创建 MR。

### 下一步

执行本地验证，完成证据包后按 standing policy 回写 `FUZ-554` comment。

### FUZ-554-N 远端回写

已按 standing policy 追加 `FUZ-554` 的 Patch Scope Check comment：

- Comment ID：`242d7e55-3ce2-4bb4-9361-8a717945ec6c`
- Status changed：`false`
- 本地记录：`runs/FUZ-554-patch-scope-check-pilot/writeback-summary.md`

该回写用于补充 patch scope check 试点结果，未改变 issue 状态。

## 2026-06-15：FUZ-554-O Review Packet Include Patch Summary

### 目标

把真实代码改动的 patch summary 纳入 human review packet，让复核者在一个入口看到改动范围与 scope check 状态。

### 执行

- 为 `scripts/review-packet.sh` 新增 `--include-patch-summary <file>`。
- 更新 `docs/ai-work-orchestration/05-case-playbook.md`，补充带 patch summary 的复核包命令。
- 新增任务草案：`tasks/FUZ-554-review-packet-include-patch-pilot.md`。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-18-review-packet-include-patch.md`。

### 验证

- `bash -n scripts/review-packet.sh`：PASSED
- 带 patch summary 生成 review packet：PASSED
- 缺失 patch summary 负向用例：PASSED
- 不带 patch summary 的原有用法：PASSED
- Toolchain verification：PASSED

### 边界

- 只读取本地 `runs/` 与显式传入的本地 patch summary 文件。
- 未读取 Multica issue。
- 未修改 Multica status。
- 未 push、未 commit、未创建 MR。

### 下一步

执行本地工具链自检，完成证据包后按 standing policy 回写 `FUZ-554` comment。

### FUZ-554-O 远端回写

已按 standing policy 追加 `FUZ-554` 的 Review Packet Include Patch Summary comment：

- Comment ID：`095cdc73-9e7c-444c-872d-251003571875`
- Status changed：`false`
- 本地记录：`runs/FUZ-554-review-packet-include-patch-pilot/writeback-summary.md`

该回写用于补充 review packet include patch summary 试点结果，未改变 issue 状态。

## 2026-06-15：FUZ-554-P Strict Evidence Gate

### 目标

把案例级证据完整性检查从 review packet 人工观察升级为可执行 gate。

### 执行

- 为 `scripts/verify-toolchain.sh` 新增 `--strict`。
- strict 模式要求每个匹配 run 具备 `summary.md`、`stage-report.md`、`multica-comment.md`。
- 新增任务草案：`tasks/FUZ-554-strict-evidence-gate-pilot.md`。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-19-strict-evidence-gate.md`。

### 验证

- `bash -n scripts/verify-toolchain.sh`：PASSED
- `verify-toolchain --strict` 正向用例：PASSED
- strict 负向缺证据用例：PASSED
- 非 strict smoke check 兼容：PASSED

### 边界

- 只读取本地脚本和本地 `runs/` 证据目录。
- 未读取 Multica issue。
- 未修改 Multica status。
- 未 push、未 commit、未创建 MR。

### 下一步

完成证据包后按 standing policy 回写 `FUZ-554` comment。

### FUZ-554-P 远端回写

已按 standing policy 追加 `FUZ-554` 的 Strict Evidence Gate comment：

- Comment ID：`4b0dd930-14d4-41da-8cd8-b02bb2950430`
- Status changed：`false`
- 本地记录：`runs/FUZ-554-strict-evidence-gate-pilot/writeback-summary.md`

该回写用于补充 strict evidence gate 试点结果，未改变 issue 状态。

## 2026-06-15：FUZ-554-Q Share Refresh Recovery

### 目标

恢复上个会话在 Phase 20 中断的分享包刷新工作，确保 `FUZ-554` 当前证据状态可以被团队阅读和复核。

### 执行

- 刷新 `docs/ai-work-orchestration/share/FUZ-554-one-page.md`。
- 更新 `docs/ai-work-orchestration/README.md` 和 `docs/ai-work-orchestration/cases/FUZ-554/README.md`。
- 更新 `docs/ai-work-orchestration/07-next-code-candidates.md`，标记 A/B/D 已完成并推荐 C。
- 新增任务草案：`tasks/FUZ-554-share-refresh-pilot.md`。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-20-share-refresh.md`。

### 验证

- 分享稿内容检查：PASSED
- 总入口/案例入口检查：PASSED
- `bash -n scripts/verify-toolchain.sh`：PASSED
- `verify-toolchain --strict`：PASSED

### 边界

- 只读取和写入本地文档、脚本与 `runs/` 证据目录。
- 未读取 Multica issue。
- 未修改 Multica comment/status。
- 未 push、未 commit、未创建 MR。

### 结果

当前本地 `FUZ-554*` run 共 18 个，18 个均具备 core evidence，16 个保留 `writeback-summary.md`。

## 2026-06-15：FUZ-554-R Evidence Index Stable Ordering

### 目标

为 evidence index 增加生成时间、匹配范围和排序说明，提升多 run 证据索引的可复核性。

### 执行

- 为 `scripts/evidence-index.sh` 输出新增 `Metadata` 区块。
- Metadata 包含 `Generated at`、`Pattern` 和 `Ordering`。
- 新增任务草案：`tasks/FUZ-554-evidence-index-stable-ordering-pilot.md`。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-21-evidence-index-stable-ordering.md`。

### 验证

- `bash -n scripts/evidence-index.sh`：PASSED
- evidence index metadata 检查：PASSED
- `bash -n scripts/verify-toolchain.sh`：PASSED
- `verify-toolchain --strict`：PASSED

### 边界

- 只读取本地 `runs/` 目录。
- 未读取 Multica issue。
- 未修改 Multica comment/status。
- 未 push、未 commit、未创建 MR。

### 结果

当前本地 `FUZ-554*` run 共 19 个，19 个均具备 core evidence，16 个保留 `writeback-summary.md`。

## 2026-06-15：FUZ-554-S Review Packet Metadata

### 目标

为 human review packet 增加生成时间、匹配范围和排序说明，让复核入口与 evidence index 使用一致 metadata 口径。

### 执行

- 为 `scripts/review-packet.sh` 输出新增 `Metadata` 区块。
- Metadata 包含 `Generated at`、`Pattern` 和 `Ordering`。
- 新增任务草案：`tasks/FUZ-554-review-packet-metadata-pilot.md`。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-22-review-packet-metadata.md`。

### 验证

- `bash -n scripts/review-packet.sh`：PASSED
- review packet metadata 检查：PASSED
- 带 patch summary 用法：PASSED
- 不带 patch summary 的兼容用法：PASSED
- `verify-toolchain --strict`：PASSED

### 边界

- 只读取本地 `runs/` 与显式传入的 patch summary 文件。
- 未读取 Multica issue。
- 未修改 Multica comment/status。
- 未 push、未 commit、未创建 MR。

### 结果

当前本地 `FUZ-554*` run 共 20 个，20 个均具备 core evidence，16 个保留 `writeback-summary.md`。

## 2026-06-15：FUZ-554-T Stage Review And Commit Prep

### 目标

停止继续扩展功能，整理当前本地工作树并生成提交前人工复核包。

### 执行

- 生成最终 patch summary：`runs/FUZ-554-stage-review-commit-prep/patch-summary.md`。
- 生成最终 review packet：`runs/FUZ-554-stage-review-commit-prep/review-packet.md`。
- 生成最终 strict verification：`runs/FUZ-554-stage-review-commit-prep/verification-report.md`。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-23-stage-review-commit-prep.md`。

### 验证

- patch summary：PASSED
- review packet：PASSED
- strict evidence gate：PASSED
- scope check：FAILED，原因是当前工作树包含早先 `lib/ai_loop/*` 与根文档改动，超出本阶段 allow-prefix。

### 边界

- 只读取本地 git 状态和本地证据。
- 未读取 Multica issue。
- 未修改 Multica comment/status。
- 未 push、未 commit、未创建 MR。

### 结果

当前本地 `FUZ-554*` run 共 21 个，21 个均具备 core evidence，16 个保留 `writeback-summary.md`。提交前需要人工确认是否拆分核心代码改动与 FUZ-554 工具链/文档证据包。

## 2026-06-15：FUZ-554-U Scope Split Review

### 目标

处理 Phase 23 的 scope check failure，将当前混合工作树拆成可人工复核的提交候选组。

### 执行

- 生成 scope split report：`runs/FUZ-554-scope-split-review/scope-split-report.md`。
- 将改动拆为 Group A/FUZ-554 工具链与编排文档、Group B/AI Loop core、Group C/FUZ-552/FUZ-553 task drafts、Group D/ignored local evidence。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-15-phase-24-scope-split-review.md`。

### 验证

- scope split report：PASSED
- strict evidence gate：PASSED

### 边界

- 未修改功能代码。
- 未删除文件。
- 未执行 git add/commit/stash/reset。
- 未读取或写入 Multica。
- 未 push、未创建 MR。

### 结果

当前本地 `FUZ-554*` run 共 22 个，22 个均具备 core evidence，16 个保留 `writeback-summary.md`。下一步需要人工选择提交策略。

## 2026-06-16：Agent Crew Model

### 目标

定义机组角色模型，为"next_actor 映射到 assigned_actor"提供规范基础。

### 执行

- 新增 `docs/ai-work-orchestration/13-agent-crew-model.md`。
- 定义 6 类机组角色：黑墙（调度）、顾实（执行）、裴衡（复核）、测真（验证）、简辞（记录）、人类（决策）。
- 定义 `next_actor -> assigned_actor` 映射规则。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-16-phase-49-agent-crew-model.md`。

### 验证

- markdown 格式检查：PASSED
- 无功能代码修改，无需运行测试。

### 边界

- 未读取或写入 Multica。
- 未修改脚本逻辑。
- 未动 `runs/` 本地证据。

### 结果

机组模型已定义，下一步补本地路由脚本。

## 2026-06-16：Agent Crew Routing

### 目标

实现本地 `scripts/route-actor.sh`，把状态机输出的 `next_actor` 映射成具体 `assigned_actor`。

### 执行

- 新增 `scripts/route-actor.sh`。
- 读取 `state-evaluation.json` 中的 `next_actor`。
- 按 Agent Crew 模型映射到 `assigned_actor`。
- 输出 JSON 和 Markdown。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-16-phase-50-agent-crew-routing.md`。

### 验证

- bash 语法检查：PASSED
- 正向测试：`execution_agent -> 顾实`，`reviewer -> 裴衡`，`human -> 人类`
- 负向测试：未知 `next_actor` 返回 `(unknown)`

### 边界

- 未读取或写入 Multica。
- 未修改现有门禁脚本。
- 未动 `runs/` 本地证据。

### 结果

路由脚本已可用，下一步让 metadata-draft 和 state gate 使用它。

## 2026-06-16：Assigned Actor Gate

### 目标

让 `metadata-draft.sh` 调用 `route-actor.sh`，让 `verify-toolchain.sh --state-gate` 检查 `metadata.assigned_actor` 字段。

### 执行

- 更新 `scripts/metadata-draft.sh`，新增 `assigned_actor` 字段。
- 更新 `scripts/verify-toolchain.sh`，`--state-gate` 检查 `metadata.assigned_actor` 是否存在。
- 对 FUZ-554 现有 22 个 run 执行 `refresh-run-evidence.sh`。
- 重新执行 `share-preflight.sh` 和 `verify-toolchain --strict --state-gate`。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-16-phase-51-assigned-actor-gate.md`。

### 验证

- 正向：FUZ-554 22 个 run 全部通过 `--strict --state-gate`。
- review packet 显示 `Assigned Actor`。
- 负向：构造缺少 `metadata.assigned_actor` 的临时 run，`--state-gate` 正确失败。

### 边界

- 未读取或写入 Multica。
- 未 push、未 commit、未创建 MR。
- 本地 `runs/` 证据已刷新，未纳入 git。

### 结果

状态门禁现在覆盖完整链路：`state-evaluation -> metadata-draft -> assigned_actor -> review packet`。下一步把机组路由补进技术分享。

## 2026-06-16：Agent Crew Sharing Update

### 目标

把 Agent Crew 机组路由补进技术分享材料，让分享从"黑墙确认天道经验"继续落到"next_actor 如何映射到 assigned_actor"。

### 执行

- 在 `slide-deck.md` 新增 Slide 10：机组路由。
- 在 `slides-content.md` 新增上屏内容页：从 `next_actor` 到 `assigned_actor`。
- 在 `speaker-notes.md` 新增对应讲法和转场。
- 在 `tech-sharing-outline.md` 新增"机组路由"章节，并顺延后续章节编号。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-16-phase-52-agent-crew-sharing.md`。

### 验证

- `git diff --check`：PASSED
- `share-preflight.sh`：PASSED
- `verify-toolchain --strict --state-gate`：PASSED

### 边界

- 未读取或写入 Multica。
- 未 push、未创建 MR。
- 未动 `runs/` 本地证据。

### 提交记录

- `a707e76 Add Agent Crew routing to sharing materials`
- `ccdce49 Record Agent Crew sharing update report`

### 结果

分享材料现在覆盖完整叙事链：`天道经验 -> Agent Crew 机组模型 -> next_actor -> assigned_actor -> review packet`。

## 2026-06-16：Multica Loop Validation

### 目标

验证 Multica Loop 组织层脚本的完整 evidence 生成链路，确认从任务输入到状态判断、元数据草稿、评论草稿和门禁验证的端到端流程。

### 执行

- 创建测试任务：`tasks/multica-loop-test.md`。
- 执行 ai-loop dry-run：`multica-loop-validation-pilot`。
- 生成完整 evidence 链路：summary、stage-report、multica-comment、state-evaluation、metadata-draft、review-packet。
- 运行 `verify-toolchain.sh --strict --state-gate`。
- 新增验证文档：`docs/ai-work-orchestration/14-multica-loop-validation.md`。
- 新增阶段报告：`docs/ai-work-orchestration/reports/2026-06-16-phase-53-multica-loop-validation.md`。

### 验证结果

- Strict evidence gate：PASSED
- State metadata gate：PASSED
- Toolchain smoke checks：12/12 PASSED
- 状态推进建议：running → evidence_ready，next actor: 顾实

### 边界

- 未读取真实 Multica issue。
- 未执行远端回写。
- 未 push、未创建 MR。
- 本地 `runs/multica-loop-validation-pilot/` 证据未纳入 git。

### 提交记录

- `1b98e4a Validate Multica Loop organization layer`

### 结果

Multica Loop 组织层脚本已可用，完整链路验证通过：`task → dry-run → state-evaluation → metadata-draft → comment-draft → review-packet → strict/state gate`。下一步可将 `multica-loop.sh` 用于真实低风险 Multica issue 验证端到端回写流程。
