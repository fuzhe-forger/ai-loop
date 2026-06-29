# Sinan Onboarding Local Drill

## 目标

跑通一次本地低风险司南演练，理解何时使用 fast path、Loop、gate、evidence 和 closeout。

## 范围

- 只读取本仓库文档和脚本。
- 只生成 `runs/onboarding/` 下的本地报告。
- 不执行远端 Git、部署、生产访问、删除、权限变更、Feishu 或 Multica 写回。

## 验收标准

- `sinan-capability-check` 通过。
- `sinan-doctor` 通过。
- `sinan-flow-advisor` 产物可读。
- `onboarding-drill-check` 通过。
- 能说明哪些操作必须停下等人类审批。

## 风险控制

- 本任务仅允许本地读写 run artifacts。
- 如发现任何外部副作用需求，停止并列出审批项。
