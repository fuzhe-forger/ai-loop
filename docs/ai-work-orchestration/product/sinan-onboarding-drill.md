# 司南 30 分钟 Onboarding Drill

## 目标

新人 30 分钟内理解司南并跑通一个低风险本地任务，不触发外部写回或部署。

## 前置条件

- 已进入仓库根目录。
- 本地可运行 Bash 和 Python3。
- 不需要飞书、Multica、远端 Git 权限。

## 步骤

1. 读入口：`docs/ai-work-orchestration/README.md`。
2. 读产品手册：`docs/ai-work-orchestration/product/sinan-v1-product-manual.md`。
3. 运行能力自检：`./scripts/sinan-capability-check.sh --output runs/onboarding/capability.md --json-output runs/onboarding/capability.json`。
4. 运行本地 readiness doctor：`./scripts/sinan-doctor.sh --output runs/onboarding/sinan-doctor.md --json-output runs/onboarding/sinan-doctor.json`。
5. 运行 flow advisor：`./scripts/sinan-flow-advisor.sh --task tasks/sinan-onboarding-local-drill.md --output runs/onboarding/flow-advice.md --json-output runs/onboarding/flow-advice.json`。
6. 校验 drill 产物：`./scripts/onboarding-drill-check.sh --drill-dir runs/onboarding --output runs/onboarding/onboarding-drill-check.md --json-output runs/onboarding/onboarding-drill-check.json`。
7. 如需兼容旧演示路径，再运行工具链验证：`./scripts/verify-toolchain.sh --case FUZ-554 --pattern FUZ-554-real-multica-loop-gated-20260622-142303 --strict --state-gate --output runs/onboarding/verification.md`。
8. 复查输出，确认无外部副作用。

## 验收

- 能说清司南适用/不适用场景。
- 能找到 evidence、gate、writeback、memory、time calibration 入口。
- 能生成本地 doctor、flow advice 和 drill check report。
- 可解释 legacy `verify-toolchain.sh` 何时需要补跑。
- 能解释哪些操作必须停下等人类审批。
