# FUZ-554 一页式分享稿：从 AI 执行到可复核工作闭环

## 一句话结论

`FUZ-554` 证明了一件事：AI 不只是“更快地干活”，而是可以被放进一个本地优先、证据优先、人类复核的工程工作系统中。

## 为什么做

单个 AI 助手可以提升局部效率，但团队真正需要的是稳定闭环：

- 任务从哪里来？
- AI 做了什么？
- 证据在哪里？
- 哪些动作需要人确认？
- 结果能不能复盘和分享？

`FUZ-554` 的目标就是把这些问题跑成一个真实低风险样板，并把“能做”推进到“可复核、可拒绝、可分享”。

## 怎么做

本案例按“本地优先、证据优先、人类复核”的原则逐层推进：

1. 元流程：从 Multica issue 到本地 ai-loop dry-run。
2. 文档型试点：沉淀 `05-case-playbook.md`，定义后续案例怎么跑。
3. 脚本型试点：新增 `--policy-help`，降低状态策略理解成本。
4. 单 run checklist：新增 `evidence-checklist.sh`，检查单次运行证据。
5. 多 run evidence index：新增 `evidence-index.sh`，总览案例级证据完整度。
6. Human review packet：新增 `review-packet.sh`，生成面向人的复核入口。
7. 真实 patch 摘要：新增 `patch-summary.sh`，把本地改动范围沉淀成报告。
8. 代码改动准入：为 patch summary 增加 scope check，识别是否超出允许路径。
9. 复核包增强：让 review packet 纳入 patch summary 和 scope check 结果。
10. Strict Evidence Gate：为 `verify-toolchain.sh` 增加 `--strict`，缺少 core evidence 时直接失败。

## 产出了什么

核心产物：

- 总入口：`docs/ai-work-orchestration/README.md`
- 案例指南：`docs/ai-work-orchestration/05-case-playbook.md`
- 案例复盘：`docs/ai-work-orchestration/cases/FUZ-554/README.md`
- 下一任务候选池：`docs/ai-work-orchestration/07-next-code-candidates.md`
- Evidence index：`runs/FUZ-554-evidence-index-pilot/index.md`
- Review packet：`runs/FUZ-554-review-packet-include-patch-pilot/review-packet.md`
- Strict verification：`runs/FUZ-554-strict-evidence-gate-pilot/verification-report.md`

## 证据状态

截至 Strict Evidence Gate 阶段，`FUZ-554` 已有 17 个 run，全部具备 core evidence：

- `summary.md`
- `stage-report.md`
- `multica-comment.md`

其中 16 个 run 已完成远端 comment 回写并保留 `writeback-summary.md`。未回写的首个 dry-run 保持原始“只生成本地草稿、不默认写远端”的保守边界。

本次 scope split review 新增 `runs/FUZ-554-scope-split-review/` 后，当前本地 `FUZ-554*` run 共 22 个，strict evidence gate 已全部通过。提交前 scope split 已将当前工作树拆为 FUZ-554 工具链/文档包、AI Loop 核心代码包、其他 issue 任务草稿和 ignored 本地 evidence。

## 工具链状态

当前本地工具链已覆盖四类复核入口：

- Evidence：`evidence-checklist.sh` 和 `evidence-index.sh` 用于检查单 run 与多 run 证据完整度；evidence index 已包含生成时间、pattern 和排序说明。
- Review：`review-packet.sh` 汇总案例证据，并可通过 `--include-patch-summary` 引用 patch summary；review packet 已包含生成时间、pattern 和排序说明。
- Patch：`patch-summary.sh` 生成改动摘要，并支持 `--allow-prefix` 做 scope check。
- Gate：`verify-toolchain.sh --strict` 对匹配 run 执行 core evidence 准入检查。

## 人类控制点

本案例保留了明确的人类控制点：

- dry-run 通过不等于业务完成。
- comment/status 写入必须人工确认或遵循明确 standing policy。
- 状态同步不由脚本自动判断业务完成。
- review packet 只辅助判断，不代表自动批准。
- strict gate 只证明 core evidence 齐全，不替代业务复核。

## 可复用价值

后续团队可以直接复用三层材料：

- 任务层：`tasks/*.md` 定义目标、验收和边界。
- 证据层：`runs/<run-id>/` 保留执行事实。
- 复核层：checklist、evidence index、patch summary、review packet、strict verification 支撑人工判断。

## 下一步

建议进入两条线：

1. 选择下一个真实低风险代码任务，优先验证 evidence index 的排序/生成说明，继续保持本地可验证、低副作用。
2. 把本分享稿作为团队内部第一次同步材料，收集团队对边界、证据、状态策略和 strict gate 的反馈。
