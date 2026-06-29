# Phase 72：Gate Policy 接入状态机

## 目的

让 `gate-policy-check` 不只是 review packet 的展示信息，而是能参与 `evaluate-state` 的下一状态建议：低于任务类型策略阈值的 run 应先修复或记录人工例外，而不是直接进入 review。

## 结论

- `scripts/evaluate-state.sh` 已读取 `gate-policy-check.md` / `gate-policy-check.json`。
- 非澄清场景下，如果 gate policy 结果为 `FAILED`，状态进入 `blocked`，下一角色为 `execution_agent`。
- `needs_clarification` 逻辑仍保持优先级：需求不清且澄清 evidence 合格时，继续交给 `human` 补需求，不被 gate policy 抢先覆盖。
- `scripts/refresh-run-evidence.sh` 已调整顺序：先生成 gate policy，再评估 state 和 metadata，确保状态建议不落后一轮。
- state evaluation Markdown 已展示 `Gate policy check` 状态和 artifact 路径。

## 产物

- `scripts/evaluate-state.sh`
- `scripts/refresh-run-evidence.sh`
- `docs/ai-work-orchestration/21-local-operating-protocol.md`
- `docs/ai-work-orchestration/23-design-output-governance.md`

## 验证

已完成本地验证：

```bash
./scripts/evaluate-state.sh --issue PHASE-70 --run-id phase-70-gate-policy-pass-sample
./scripts/evaluate-state.sh --issue PHASE-70 --run-id phase-70-gate-policy-fail-sample
./scripts/refresh-run-evidence.sh --pattern 'phase-70-gate-policy-*' --issue PHASE-70 --task-type feature
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*'
```

验证结果：

- `phase-70-gate-policy-pass-sample`：`gate_policy_check=PASSED`，状态保持 `evidence_ready`。
- `phase-70-gate-policy-fail-sample`：`gate_policy_check=FAILED`，状态进入 `blocked`，下一角色为 `execution_agent`。
- `refresh-run-evidence` 已按新顺序生成策略后再评估状态，失败样例在刷新报告中显示 `Suggested State = blocked`。
- `verify-toolchain` 本地 smoke checks 通过。

## 副作用

- Network access: false
- Remote writes: false
- Multica writes: false
- Feishu writes: false
- Real Obsidian writes: false

## 下一步

- 评估是否把 `gate-policy-check` 接入 `multica-loop.sh` 的单次执行收尾阶段。
- 为人工例外设计标准 evidence 字段，避免临时绕过策略不可追踪。
