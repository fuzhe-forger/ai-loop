# Phase 70：任务类型门禁策略

## 目的

把 Phase H 的质量门禁从“所有任务同一套阈值”推进到“按任务类型配置 required gates 和最低分”，让 `司南` 在方案设计和产出把控上更细粒度、更可审计。

## 结论

- 新增 `config/gate-policy.json`，定义 `bug_fix`、`feature`、`documentation`、`refactor`、`infrastructure`、`test`、`unknown` 的 required gates、optional gates 和最低分。
- 新增 `scripts/gate-policy-check.sh`，读取 run evidence、classification 或显式 task type，输出 Markdown/JSON 策略校验报告。
- `clarification-gate` 一旦存在，或 `requirement-gate` 失败，会升级为必检项，避免缺少澄清质量证据时交给人类。
- `collect-evidence.sh` 已纳入 `gate-policy-check.md/json` artifact，并输出 `checks.gate_policy_check`。
- `review-packet.sh` 已新增 `Gate Policy` 列，展示策略结果和任务类型。
- `verify-toolchain.sh` 已加入 `gate-policy-check` 语法、help 和 `config/gate-policy.json` 校验。

## 产物

- `config/gate-policy.json`
- `scripts/gate-policy-check.sh`
- `scripts/collect-evidence.sh`
- `scripts/review-packet.sh`
- `scripts/verify-toolchain.sh`
- `docs/ai-work-orchestration/23-design-output-governance.md`
- `docs/ai-work-orchestration/21-local-operating-protocol.md`
- `docs/ai-work-orchestration/README.md`
- `docs/ai-work-orchestration/09-north-star.md`

## 验证

已完成本地验证：

```bash
bash -n scripts/gate-policy-check.sh
python3 -m json.tool config/gate-policy.json
./scripts/gate-policy-check.sh --help
./scripts/gate-policy-check.sh --run-id phase-70-gate-policy-pass-sample --task-type feature
./scripts/gate-policy-check.sh --run-id phase-70-gate-policy-fail-sample --task-type feature
./scripts/collect-evidence.sh --issue PHASE-70 --run-id phase-70-gate-policy-pass-sample
./scripts/review-packet.sh --case PHASE-70 --pattern 'phase-70-gate-policy-*'
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*'
```

验证结果：

- `phase-70-gate-policy-pass-sample`：`feature` 策略通过，required gates 均满足最低分。
- `phase-70-gate-policy-fail-sample`：`feature` 策略按预期失败，原因是 `design` 分数 `70` 低于最低分 `85`。
- `collect-evidence` 已展示 `Gate policy check: present`，并收集 `gate-policy-check.md/json`。
- `review-packet` 已展示 `Gate Policy` 列，能区分 `PASSED feature` 和 `FAILED feature`。
- `verify-toolchain` 本地 smoke checks 通过。

## 副作用

- Network access: false
- Remote writes: false
- Multica writes: false
- Feishu writes: false
- Real Obsidian writes: false

## 下一步

- 用最小 fixture 验证 `feature` 通过路径和低分失败路径。
- 评估是否把 `gate-policy-check` 作为 `ai-loop run` 前置/后置标准步骤。
