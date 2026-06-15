# FUZ-553 Phase 1：回写与状态策略

## 原始需求

定义并实现 comment 回写草稿、状态变更白名单和默认只读策略。

## 目标

为 Multica ↔ ai-loop 联动定义更细粒度的 comment 回写与状态同步策略，并在 wrapper 中实现策略化状态映射。

## 验收

- 状态映射不再只有 PASSED / blocked 两类
- dry-run 的 PASSED 不自动等价于业务完成
- 失败状态能区分 config/workspace/agent/verify/safety 等类型
- 默认仍不写远端
- 显式 `--write-status` 才同步状态
- 有阶段报告说明风险与边界

## 安全边界

- 不默认写 Multica
- 不批量处理 issue
- 不将 dry-run 业务任务自动标为完成
