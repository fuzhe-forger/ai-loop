# Phase 74：Gate Policy 人工例外 Evidence

## 目的

为 `gate-policy-check` 失败但人类判断可以继续的情况提供结构化、本地可审计的例外 evidence，避免“口头绕过”导致后续复盘不可追踪。

## 结论

- 新增 `scripts/gate-policy-exception.sh`，生成：
  - `gate-policy-exception.json`
  - `gate-policy-exception.md`
- 例外必须包含：`approved_by`、`reason`、`expires` 和 `scope`。
- `scripts/evaluate-state.sh` 已识别 ACTIVE 例外：gate policy 失败但有有效例外时，不再进入 `blocked`。
- `scripts/collect-evidence.sh` 已收集 gate policy exception artifacts。
- `scripts/review-packet.sh` 已新增 `Gate Exception` 列。
- `scripts/verify-toolchain.sh` 已加入 `gate-policy-exception` 语法和 help 检查。

## 产物

- `scripts/gate-policy-exception.sh`
- `scripts/evaluate-state.sh`
- `scripts/collect-evidence.sh`
- `scripts/review-packet.sh`
- `scripts/verify-toolchain.sh`
- `docs/ai-work-orchestration/21-local-operating-protocol.md`
- `docs/ai-work-orchestration/23-design-output-governance.md`
- `docs/ai-work-orchestration/README.md`

## 验证

已完成本地验证：

```bash
./scripts/gate-policy-exception.sh --run-id phase-70-gate-policy-fail-sample --issue PHASE-70 --approved-by fixture-human --reason 'fixture exception for policy override validation only' --expires 2099-12-31
./scripts/evaluate-state.sh --issue PHASE-70 --run-id phase-70-gate-policy-fail-sample
./scripts/collect-evidence.sh --issue PHASE-70 --run-id phase-70-gate-policy-fail-sample
./scripts/refresh-run-evidence.sh --pattern 'phase-70-gate-policy-*' --issue PHASE-70 --task-type feature
./scripts/review-packet.sh --case PHASE-70 --pattern 'phase-70-gate-policy-*'
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*'
```

验证结果：

- `gate-policy-exception` 生成 ACTIVE 例外 evidence。
- `evaluate-state` 仍保留 `gate_policy_check=FAILED` 事实，同时识别 `gate_policy_exception=ACTIVE`，状态不再因策略失败进入 `blocked`。
- `collect-evidence` 展示 `Gate policy exception: present` 并收集例外 artifact。
- `refresh-run-evidence` 刷新后，review packet 中失败样例显示 `Gate Exception = ACTIVE fixture-human`，Suggested State 为 `evidence_ready`。
- `verify-toolchain` 本地 smoke checks 通过。

## 副作用

- Network access: false
- Remote writes: false
- Multica writes: false
- Feishu writes: false
- Real Obsidian writes: false
- Local writes: `runs/<run-id>/gate-policy-exception.*` for validation fixture

## 下一步

- 增加过期例外的失败样例验证。
- 评估是否把人工例外同步到 Obsidian generated run 页面。
