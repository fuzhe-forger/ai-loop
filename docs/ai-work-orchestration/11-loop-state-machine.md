# Multica Loop 状态机

## 目标

Multica Loop 状态机用于回答：

> 一个 issue 现在处于哪里，下一步应该由谁做，能不能产生远端副作用？

它不是为了自动把任务推到完成，而是为了让 AI 工作有明确边界、证据门禁和人工决策点。

## 核心原则

- issue 是输入，不是完成证明。
- evidence 是状态推进依据。
- comment 和 status 写入分开授权。
- 失败必须进入可解释状态，不能静默重试。
- 超过循环阈值必须升级给人或 reviewer。

## 状态列表

| 状态 | 含义 | 主要负责人 |
|---|---|---|
| `intake` | 收到 issue 或人工请求 | Multica Loop |
| `clarify` | 目标、范围、验收或 repo 不清楚 | 人类 / 黑墙 |
| `planned` | 已形成 task、repo、验证方式和策略 | Multica Loop |
| `dry_run_ready` | 可做编排预演，不产生业务变更 | ai-loop |
| `run_ready` | 可进入真实本地执行 | ai-loop |
| `running` | 正在执行 plan/run/verify | 执行 agent |
| `evidence_ready` | Core Evidence 齐全 | Multica Loop |
| `review_ready` | 证据和验证足够进入人工复核 | reviewer |
| `writeback_ready` | comment draft 清楚，副作用已授权 | 人类 / Multica Loop |
| `done` | 复核通过，必要回写完成 | 人类 |
| `blocked` | 缺上下文、验证失败、权限不足或风险过高 | 人类 / reviewer |
| `escalated` | 循环过多或判断复杂，需要更高层处理 | 黑墙 / Xcode |

## 主流程

```text
intake
  -> clarify
  -> planned
  -> dry_run_ready
  -> run_ready
  -> running
  -> evidence_ready
  -> review_ready
  -> writeback_ready
  -> done
```

允许跳过：

- 纯规划任务可以停在 `planned`。
- 只读分析任务可以从 `running` 到 `review_ready`，不进入 `writeback_ready`。
- 不需要远端回写时，`review_ready` 可由人确认后进入 `done`。

## 门禁

### intake -> clarify / planned

进入 `planned` 需要：

- 有明确目标。
- 有目标 repo 或明确说明只做文档/规划。
- 有验收口径。
- 有 side effects 策略。

否则进入 `clarify`。

### planned -> dry_run_ready

需要：

- task 文件存在。
- repo 可访问。
- dry-run 命令可构造。
- 不需要远端写入。

### dry_run_ready -> run_ready

需要：

- dry-run 通过。
- 工作树状态符合策略。
- 验证命令明确。
- 真实执行 side effects 已明确。

### running -> evidence_ready

需要 Core Evidence 齐全：

- `summary.md`
- `stage-report.md`
- `multica-comment.md`

缺任一项进入 `blocked`，原因是 `missing_evidence`。

### evidence_ready -> review_ready

需要：

- 验证结果可读。
- 风险和未完成项明确。
- 如果涉及代码变更，有 `patch-summary.md` 或等价说明。
- 如果范围复杂，有 `review-packet.md` 或 `scope-split-report.md`。

### review_ready -> writeback_ready

需要：

- reviewer 或人类确认可以回写。
- `multica-comment.md` 内容清楚。
- 写入目标、写入内容、状态策略明确。

### writeback_ready -> done

需要：

- 回写成功，或明确不需要回写。
- 必要时生成 `writeback-summary.md`。
- 结果已记录到 `logbook.md` 或阶段报告。

## 异常流转

| 来源 | 目标 | 条件 |
|---|---|---|
| 任意状态 | `blocked` | 缺权限、缺上下文、验证失败、工作树不安全 |
| `blocked` | `clarify` | 需要人补充目标、验收、权限或范围 |
| `blocked` | `planned` | 问题已解决，需要重新规划 |
| `review_ready` | `running` | reviewer 要求补改或补验证 |
| 任意循环 | `escalated` | 同一问题反复超过阈值 |

## 状态输入

状态机读取三类输入：

| 输入 | 来源 | 用途 |
|---|---|---|
| Issue metadata | Multica | 目标、负责人、优先级、远端状态 |
| Evidence metadata | `evidence.json` / runs | 判断是否可复核、可回写 |
| Policy metadata | 本地策略 | 判断是否允许副作用和状态同步 |

## 状态输出

每次状态判断应输出：

```json
{
  "issue": "FUZ-xxx",
  "run_id": "FUZ-xxx-...",
  "from": "evidence_ready",
  "to": "review_ready",
  "reason": "core evidence complete and verification readable",
  "required_next_actor": "reviewer",
  "side_effects_allowed": false
}
```

## MVP 实现顺序

第一版只实现本地判断，不自动写 Multica：

1. 读取 `evidence.json` 或 run 目录。
2. 判断 Core Evidence 是否齐全。
3. 判断验证结果是否存在。
4. 输出建议状态和下一步角色。
5. 生成 comment draft，但不自动写远端。

## 与现有脚本关系

- `collect-evidence.sh` 负责收集状态输入。
- `verify-toolchain.sh --strict` 负责 Core Evidence 门禁。
- `evaluate-state.sh` 负责输出 `from/to/reason/next_actor`。

## 下一步

- 把状态输出写入 run evidence。
- 在 Multica comment 中展示建议状态，而不是直接改远端状态。
