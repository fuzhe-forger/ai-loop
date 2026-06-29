# Phase 73：Multica Loop 单次收尾接入 Gate Policy

## 目的

把 `gate-policy-check` 接入 `multica-loop.sh` 的单次 dry-run 收尾阶段，让从 Multica issue 进入本地 Loop 的任务自动沉淀 classification 和任务类型策略 evidence。

## 结论

- `scripts/multica-loop.sh` 新增 `--task-type <type>`，可覆盖自动分类结果。
- `scripts/multica-loop.sh` 新增 `--skip-gate-policy`，可跳过策略 evidence 生成。
- `multica-loop.sh` 在本地收尾阶段生成并引用：
  - `classification.json`
  - `gate-policy-check.md`
  - `gate-policy-check.json`
- `multica-loop.sh` 会先生成 gate policy，再运行 `evaluate-state` 和 `metadata-draft`，保证状态建议能看到策略失败。
- `scripts/classify-task.sh` 增强 labels 解析，兼容字符串 label 和对象 label。
- 远端写入控制不变：只有 `--write-comment` / `--write-status` 会触发远端副作用。

## 产物

- `scripts/multica-loop.sh`
- `scripts/classify-task.sh`
- `scripts/verify-toolchain.sh`
- `docs/ai-work-orchestration/21-local-operating-protocol.md`
- `docs/ai-work-orchestration/23-design-output-governance.md`
- `docs/ai-work-orchestration/README.md`

## 验证

已完成本地验证：

```bash
bash -n scripts/multica-loop.sh
bash -n scripts/classify-task.sh
./scripts/multica-loop.sh --help
./scripts/multica-loop.sh --policy-help
./scripts/classify-task.sh --issue PHASE-73 --ai-model none
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*'
```

验证结果：

- `multica-loop.sh --help` 已展示 `--task-type` 和 `--skip-gate-policy`。
- `classify-task` heuristic 输出合法 JSON。
- `verify-toolchain` 本地 smoke checks 通过。
- 未运行真实 `multica-loop.sh --issue ...`，因为该命令会读取 Multica issue，属于外部网络/业务系统访问；需要用户审批后再跑真实链路。

## 副作用

- Network access: false in validation
- Remote writes: false
- Multica writes: false
- Feishu writes: false
- Real Obsidian writes: false

## 下一步

- 为人工例外设计标准 evidence 字段。
- 在真实审批后，用一个低风险 issue 跑完整 `multica-loop` dry-run 验证。
