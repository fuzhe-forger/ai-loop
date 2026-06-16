# 阶段报告：Phase 25 Multica Loop Refactor Seed

## 目标

把黑墙对“天道”经验的确认落成自研 Multica Loop 重构设计，并实现第一版本地 evidence collector。

## 已完成

- 新增设计文档：`docs/ai-work-orchestration/08-multica-loop-refactor.md`。
- 新增本地脚本：`scripts/collect-evidence.sh`。
- 更新 `verify-toolchain.sh`，把 collector 纳入 smoke check。
- 更新总入口 `docs/ai-work-orchestration/README.md`。

## 设计结论

- 不引入 LingTai 代码。
- 复用“天道”编排经验：A2A、循环保护、任务路由、issue metadata、任务确认规则。
- MVP 只做 issue 驱动、单仓库、本地优先、证据优先。
- 第一版记忆只做 L1 issue metadata + 文件化 L2，不做 L3。

## 验证结果

- `bash -n scripts/collect-evidence.sh`：PASSED
- `bash -n scripts/verify-toolchain.sh`：PASSED
- `collect-evidence` 生成 JSON/Markdown：PASSED
- 缺失 run 负向用例：PASSED
- `verify-toolchain --strict`：PASSED

## 边界

- 不读取 Multica。
- 不写 Multica comment/status。
- 不 push、不创建 MR。
- 不访问生产。
- 不保存 token 或密钥。

## 结论

Multica Loop 自研重构已有设计种子和最小 evidence collector。下一步可以围绕 `collect-evidence -> review-packet -> comment draft` 做更完整的本地桥接。
