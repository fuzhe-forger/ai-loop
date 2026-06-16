# AI 工作编排实践总入口

这是 `Multica × ai-loop` 先锋实践的总入口文档。它把项目、阶段文档、案例复盘、执行指南和阶段报告串成一条可分享、可复盘的路径。

## 你应该先看什么

1. `00-vision.md`：为什么要做这件事。
2. `01-domain-model.md`：项目、issue、run、evidence、policy 的关系。
3. `03-sharing-roadmap.md`：怎么讲给团队听、怎么分阶段分享。
4. `05-case-playbook.md`：低风险案例怎么执行。
5. `cases/FUZ-554/README.md`：第一个可复盘案例。
6. `reports/`：每个阶段的正式报告。

## 当前阶段

- 项目：`AI 工作编排实践：Multica × ai-loop`
- 当前重点：把真实低风险任务、证据门禁和分享材料串成可复核阶段包
- 默认策略：本地优先、证据优先、人类复核
- 当前案例：`FUZ-554` 已完成 Phase 24 scope split review；当前本地 `FUZ-554*` run 共 22 个，全部具备 core evidence

## 推荐阅读顺序

### 1. 理念

- `00-vision.md`
- `01-domain-model.md`

### 2. 路线

- `02-phase1-mvp.md`
- `03-sharing-roadmap.md`
- `04-status-policy.md`

### 3. 实践

- `cases/FUZ-554/README.md`
- `cases/FUZ-554/review-template.md`
- `05-case-playbook.md`
- `share/FUZ-554-one-page.md`

### 4. 阶段报告

- `reports/2026-06-15-phase-1-mvp.md`
- `reports/2026-06-15-phase-2-write-policy.md`
- `reports/2026-06-15-phase-3-status-policy.md`
- `reports/2026-06-15-phase-4-first-case.md`
- `reports/2026-06-15-phase-19-strict-evidence-gate.md`
- `reports/2026-06-15-phase-20-share-refresh.md`

## 当前证据入口

- 一页式分享稿：`share/FUZ-554-one-page.md`
- 最新 strict verification：`runs/FUZ-554-scope-split-review/verification-report.md`
- Strict gate 阶段报告：`reports/2026-06-15-phase-19-strict-evidence-gate.md`
- 分享包刷新报告：`reports/2026-06-15-phase-20-share-refresh.md`
- Evidence index metadata 报告：`reports/2026-06-15-phase-21-evidence-index-stable-ordering.md`
- Review packet metadata 报告：`reports/2026-06-15-phase-22-review-packet-metadata.md`
- Stage review and commit prep 报告：`reports/2026-06-15-phase-23-stage-review-commit-prep.md`
- Scope split review 报告：`reports/2026-06-15-phase-24-scope-split-review.md`
- Multica Loop 重构设计：`08-multica-loop-refactor.md`

## 使用方式

把新的案例、试点或分享报告继续按同样结构放进 `docs/ai-work-orchestration/` 下：

- 新案例放在 `cases/<issue-or-name>/`
- 新阶段报告放在 `reports/YYYY-MM-DD-<stage>.md`
- 通用规则放在编号文档中

这样团队成员可以先看总入口，再进入具体阶段和案例，不会被零散文件打散。
