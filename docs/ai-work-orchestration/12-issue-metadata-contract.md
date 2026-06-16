# Issue Metadata 合约

## 定位

Issue metadata 是 Multica Loop 的 L1 工作记忆。

它用于记录单个 issue 当前处于什么状态、最近一次 run 是什么、证据是否合格、下一步该由谁处理。

第一阶段只生成本地 metadata 草稿，不自动写 Multica。

## 目标

- 让 issue 的编排状态机器可读。
- 让 reviewer 不必从多份文档里手工推断当前状态。
- 让后续自动路由、循环保护和回写策略有稳定输入。
- 保持人类控制：metadata 写入远端必须显式授权。

## 字段

| 字段 | 示例 | 含义 |
|---|---|---|
| `pipeline_status` | `review_ready` | Multica Loop 建议状态 |
| `review_verdict` | `pending` | reviewer 结论 |
| `latest_run_id` | `FUZ-554-scope-split-review` | 最近一次 run |
| `strict_gate` | `PASSED` | Core Evidence strict gate 结果 |
| `blocked_reason` | `missing_evidence: summary` | 阻塞原因，无阻塞时为空 |
| `next_actor` | `reviewer` | 下一步角色 |
| `state_reason` | `core evidence complete...` | 状态建议原因 |
| `updated_by` | `multica-loop-local` | metadata 来源 |
| `updated_at` | `2026-06-16T00:00:00Z` | 本地生成时间 |

## 状态取值

`pipeline_status` 使用状态机文档中的值：

- `intake`
- `clarify`
- `planned`
- `dry_run_ready`
- `run_ready`
- `running`
- `evidence_ready`
- `review_ready`
- `writeback_ready`
- `done`
- `blocked`
- `escalated`

## Review verdict

| 值 | 含义 |
|---|---|
| `pending` | 尚未复核 |
| `approved` | 复核通过 |
| `changes_requested` | 需要补改 |
| `blocked` | reviewer 判断无法继续 |
| `not_required` | 当前任务无需人工复核 |

## 来源映射

| Metadata 字段 | 本地来源 |
|---|---|
| `pipeline_status` | `state-evaluation.json.to` |
| `latest_run_id` | `state-evaluation.json.run_id` |
| `next_actor` | `state-evaluation.json.required_next_actor` |
| `state_reason` | `state-evaluation.json.reason` |
| `strict_gate` | `evidence.json.checks.strict_gate` 或 verification report |
| `blocked_reason` | `state-evaluation.json.reason`，仅当状态为 `blocked` |

## JSON 草稿格式

```json
{
  "schema_version": 1,
  "issue": "FUZ-554",
  "metadata": {
    "pipeline_status": "review_ready",
    "review_verdict": "pending",
    "latest_run_id": "FUZ-554-scope-split-review",
    "strict_gate": "PASSED",
    "blocked_reason": "",
    "next_actor": "reviewer",
    "state_reason": "core evidence complete and verification report present",
    "updated_by": "multica-loop-local",
    "updated_at": "2026-06-16T00:00:00Z"
  },
  "remote_write": false
}
```

## 写入边界

- 默认只生成本地草稿。
- 不自动写 Multica issue metadata。
- 不把 token、cookie、密钥、生产数据写入 metadata。
- 不用 metadata 替代 evidence；metadata 只是索引和状态摘要。
- 远端写入必须有显式授权和 writeback evidence。

## 下一步

- 增加本地 metadata 草稿生成脚本。
- 让 comment draft 引用 metadata 草稿路径。
- 后续再设计 metadata 写回命令和审批策略。
