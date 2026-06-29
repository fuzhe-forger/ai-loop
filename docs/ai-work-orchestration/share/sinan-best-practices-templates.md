# 司南最佳实践模板索引

## 任务拆分

使用 `memory/templates/sinan-task-execution-template.md`，先写目标、非目标、验收，再拆执行切片。

## 估时

- 开始前必须给出预计耗时和依据。
- 结束后必须记录真实耗时、误差、下一次建议估时。
- 使用 `scripts/execution-timer.sh start/close` 生成可校准 evidence。

## Evidence

- 本地执行结果统一进入 `runs/<run-id>/evidence-summary.json`。
- 复核入口统一使用 `runs/<run-id>/review-packet.md`。
- 分享前使用 `scripts/share-preflight.sh` 做 golden path 检查。

## 交接

- 长任务不要无限拖长会话。
- 每个阶段结束沉淀 Markdown artifact。
- 新会话从最新 evidence、review packet、handoff 摘要开始。

## 审批

- Feishu、Multica、Git remote、部署、工具安装、Codex 配置修改都必须走 approval boundary。
- 批量审批必须包含 approver、expires_at、actions、side_effects、issues、run_ids。
- 写回后必须保留 readback artifact，避免“写了但不可见”。
