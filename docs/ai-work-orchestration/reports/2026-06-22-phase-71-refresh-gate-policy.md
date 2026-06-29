# Phase 71：刷新链路自动生成 Gate Policy Evidence

## 目的

把 Phase 70 的 `gate-policy-check` 从手动步骤接入标准 run evidence 刷新链路，减少执行者漏跑策略校验的概率。

## 结论

- `scripts/refresh-run-evidence.sh` 默认会为每个匹配 run 生成：
  - `state-evaluation.json` / `state-evaluation.md`
  - `metadata-draft.json` / `metadata-draft.md`
  - `gate-policy-check.json` / `gate-policy-check.md`
- 新增 `--task-type <type>`，可对批量 run 显式指定任务类型。
- 新增 `--skip-gate-policy`，保留旧刷新行为，方便只刷新状态和 metadata。
- 新增 `--strict-gate-policy`，当任一策略校验失败时让刷新命令退出非零。
- `scripts/verify-toolchain.sh` 已加入 `refresh-run-evidence --pattern <pattern> --skip-gate-policy` smoke check，避免历史样例缺 gate 时阻断工具链验证。

## 产物

- `scripts/refresh-run-evidence.sh`
- `scripts/verify-toolchain.sh`
- `docs/ai-work-orchestration/21-local-operating-protocol.md`
- `docs/ai-work-orchestration/23-design-output-governance.md`
- `docs/ai-work-orchestration/README.md`

## 验证

已完成本地验证：

```bash
./scripts/refresh-run-evidence.sh --pattern 'phase-70-gate-policy-*' --issue PHASE-70 --task-type feature
./scripts/refresh-run-evidence.sh --pattern 'phase-70-gate-policy-*' --issue PHASE-70 --task-type feature --strict-gate-policy
./scripts/refresh-run-evidence.sh --pattern 'phase-70-gate-policy-*' --issue PHASE-70 --skip-gate-policy
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*'
```

验证结果：

- 非严格刷新：2 个 run 刷新成功，1 个 gate policy 失败被记录但不阻断。
- 严格刷新：按预期退出非零，因为 fail fixture 的 `design` 分数低于 `feature` 策略阈值。
- 跳过策略刷新：只刷新 state 和 metadata，`Gate Policy` 列显示 `SKIPPED`。
- 工具链 smoke checks 通过。

## 副作用

- Network access: false
- Remote writes: false
- Multica writes: false
- Feishu writes: false
- Real Obsidian writes: false
- Local writes: matching `runs/<run-id>/state-evaluation.*`、`metadata-draft.*`、`gate-policy-check.*`

## 下一步

- 评估是否把 `gate-policy-check` 接入 `multica-loop.sh` 的单次执行收尾阶段。
- 评估是否把策略失败结果纳入 `evaluate-state` 的 next state 建议。
