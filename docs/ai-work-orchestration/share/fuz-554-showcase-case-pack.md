# FUZ-554 展示案例包：从 issue 到 evidence 的闭环

## 案例定位

FUZ-554 是司南 v0.2 的首个低风险闭环样例，用来验证：AI 接到一个正式任务后，能否完成目标澄清、本地执行、证据收集、知识库沉淀、Multica 写回和最终状态更新。

## 起点

- Issue：FUZ-554
- 标题：Phase 1：首个案例复盘
- 原始目标：选择一个低风险试点，完整记录从 issue 到 evidence 的闭环案例。
- 本地任务：tasks/FUZ-554.md
- Run ID：FUZ-554-real-multica-loop-gated-20260622-142303

## 执行链路

```text
FUZ-554 issue
  -> tasks/FUZ-554.md
  -> execution preflight
  -> loop closeout
  -> evidence / share-preflight
  -> Obsidian generated
  -> Multica progress/final comment
  -> metadata readback
  -> status done
```

## 关键产物

| 类型 | 路径 |
|---|---|
| 执行前 checklist | runs/FUZ-554-real-multica-loop-gated-20260622-142303/execution-preflight.md |
| Closeout summary | runs/FUZ-554-real-multica-loop-gated-20260622-142303/closeout/closeout-summary.md |
| Evidence | runs/FUZ-554-real-multica-loop-gated-20260622-142303/evidence.md |
| Verification | runs/FUZ-554-real-multica-loop-gated-20260622-142303/verification-report.md |
| Share preflight | runs/FUZ-554-real-multica-loop-gated-20260622-142303/share-preflight-summary.md |
| Obsidian generated run | /mnt/d/JAVA/knowledge/tiandao/99-generated/loop/runs/FUZ-554-real-multica-loop-gated-20260622-142303.md |
| Multica progress comment result | runs/FUZ-554-real-multica-loop-gated-20260622-142303/multica-six-hour-progress-comment-result.json |
| Multica final comment result | runs/FUZ-554-real-multica-loop-gated-20260622-142303/multica-six-hour-final-comment-result.json |
| Multica final readback | runs/FUZ-554-real-multica-loop-gated-20260622-142303/multica-six-hour-final-issue-readback.json |

## 做对了什么

- 北极星：先对齐“可治理、可审计、可复盘”的最终目标，再把 40 条任务拆成 Phase I/B/C/D/E/F/G/A/QA。
- 证据链：每个阶段都沉淀 `verification-report.md`、`evidence-summary.json`、`evidence-checklist.md`、`review-packet.md`，让验收从口头进度变成可复核 artifact。
- 计时校准：每个批次用 `execution-timer.sh start/close` 记录预计耗时、真实耗时、误差和下一次建议估时，避免“假装跑了 30 分钟”。
- 澄清门禁：对“司南健身”这类意图不清的任务，先通过 ambiguity gate 阻断，再要求补充上下文。
- 受控回写：Multica / Feishu / metadata / status 都必须先走 approval boundary，写后保留 readback，避免“写了但不可见”。
- 先把任务转成本地 task 和 run evidence，而不是直接写外部系统。
- 用 closeout 统一本地验证，减少重复命令。
- Obsidian generated 页面能直接看到 Execution Preflight、Closeout Summary、Share Preflight Summary。
- Multica 写回前有本地草稿，写回后有 result 和 readback。
- 最终状态改为 done 前，本地 closeout 和 verification 已通过。

## 暴露的问题

- 前半段过度补 guard，导致 token 和报告数量偏高。
- Obsidian 同步审批一开始被反复打断，后来才固化 standing approval。
- 部分证据路径一开始不够集中，后面才通过 closeout 和 generated run 页收敛。
- Multica 写回首次失败是 workspace 参数缺失，说明写回命令需要固定 workspace 上下文。

## 修正后的规则

- 后续正式任务按 L0-L4 分级，不再所有任务都走重流程。
- L2 标准任务默认：preflight → closeout → Obsidian sync → 必要写回。
- 默认不写 phase report / operation log。
- Multica / Feishu 写回必须有本地草稿和 readback。
- Git remote、部署、工具安装、全局配置、破坏性操作仍必须单独审批。

## 最终状态

- Closeout：通过。
- Verification：通过。
- Obsidian sync：完成。
- Multica progress comment：已写入并 readback。
- Multica final comment：已写入并 readback。
- Multica metadata：已写入并 readback。
- Multica status：done。

## 可复用方式

下一个 L2 标准任务可以直接套用：

```bash
./scripts/loop-execution-preflight.sh   --issue <ISSUE>   --task tasks/<ISSUE>.md   --repo .   --run-id <RUN_ID>   --allow-multica-write   --no-phase-report   --no-operation-log

./scripts/loop-closeout.sh   --issue <ISSUE>   --task tasks/<ISSUE>.md   --repo .   --run-id <RUN_ID>   --allow-multica-write   --no-phase-report   --no-operation-log
```

## 一句话结论

FUZ-554 证明司南 v0.2 可以把一个正式 issue 走完“本地证据闭环 + Obsidian 沉淀 + Multica 写回 + done”流程；同时也暴露出要严格控制报告、日志和验证命令数量。
