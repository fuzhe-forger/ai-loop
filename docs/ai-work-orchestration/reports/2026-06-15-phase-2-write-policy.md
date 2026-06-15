# 阶段报告：Phase 2 写回策略准备

## 目标

在 Phase 1 本地 dry-run 链路跑通后，准备显式远端写入能力，但保持默认只读。

## 策略

远端写入分两类：

- `--write-comment`：把 `multica-comment.md` 写回 issue comment。
- `--write-status`：根据 `run.json` 状态同步 issue 状态。

## 状态映射

初始映射：

- `PASSED -> in_review`
- 其他状态 -> `blocked`

后续需要扩展为更细粒度映射：

- `FAILED_WORKSPACE -> blocked`
- `FAILED_CONFIG -> blocked`
- `FAILED_AGENT_EXIT -> blocked`
- `FAILED_VERIFY -> blocked`
- `PASSED dry-run -> in_review 或保持 todo` 需要人工确认

## 风险

- dry-run 的 `PASSED` 只代表编排链路通过，不代表业务实现完成。
- 因此自动改 `in_review` 只适合“桥接工具自身”的验证，不适合业务开发 issue。
- `--write-status` 必须保持显式开启。

## 当前实现

`scripts/multica-loop.sh` 已支持两个显式开关，但本轮未执行远端写入。

## 待确认

是否允许对 `FUZ-552` 执行一次集中远端写入：

1. 写入 comment，附上 Phase 1 dry-run 结果。
2. 将 `FUZ-552` 状态从 `todo` 改为 `in_review`。

## 执行结果

已在人工确认后完成首次显式回写：

- Issue：`FUZ-552`
- Comment ID：`08ca3cf6-47cd-4c4e-a25c-f38701458562`
- Status：`in_review`
- Project：`AI 工作编排实践：Multica × ai-loop`

该结果证明 Phase 2 写回链路可用，但默认策略仍保持只读。
