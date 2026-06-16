# Multica Loop 自研重构设计

## 定位

本设计不引入 LingTai 代码，只吸收长期智能体组织层的思想，并复用黑墙确认的“天道”编排经验。

三层分工：

- Multica：任务事实源，负责 issue、状态、评论、分配和项目管理。
- ai-loop：确定性执行层，负责 task、run、patch、verify、summary 和本地 evidence。
- Multica Loop 组织层：自研编排层，负责记忆、任务分发、证据采集、复核回写和边界控制。

## 天道经验复用

黑墙确认：“天道”不是独立代码项目，而是 Multica 智能体编排层的代号。可复用的是编排协议经验：

- A2A 协议：任务分派、结果回收、验收。
- 循环保护：执行者与 reviewer 循环超过阈值后升级。
- Issue Metadata：issue 级 KV 记忆暂存。
- 派活前类型判定：根据任务类型路由给合适智能体。
- 任务确认规则：歧义任务先提问确认，不直接执行。

## 记忆模型

| 层级 | 存储 | 生命周期 | 内容 |
|---|---|---|---|
| L1 工作记忆 | issue metadata | 单 issue | 当前状态、review verdict、blocked reason、run id |
| L2 项目记忆 | 本地文件或 KV | 跨 issue | 架构约束、决策记录、踩坑、验收偏好 |
| L3 全局记忆 | 后续向量库/知识图谱 | 长期 | agent 能力画像、历史方案模板、跨项目经验 |

MVP 只实现 L1 + 文件化 L2，不做 L3。

## 执行证据模型

每次执行都应该能产出结构化 evidence，而不是只写“已完成”：

```json
{
  "issue": "FUZ-xxx",
  "run_id": "FUZ-xxx-...",
  "status": "PASSED",
  "artifacts": {
    "summary": "runs/<run>/summary.md",
    "stage_report": "runs/<run>/stage-report.md",
    "comment_draft": "runs/<run>/multica-comment.md",
    "patch_summary": "runs/<run>/patch-summary.md",
    "review_packet": "runs/<run>/review-packet.md",
    "verification_report": "runs/<run>/verification-report.md"
  },
  "checks": {
    "core_evidence": "PASSED",
    "strict_gate": "PASSED"
  }
}
```

## 复核回写模型

回写分两层：

- comment：可以写结构化执行摘要，但必须有 evidence 支撑。
- status：默认不自动改，只有 policy 明确且人工确认后才写。

推荐 metadata 字段：

- `pipeline_status`
- `review_verdict`
- `latest_run_id`
- `strict_gate`
- `blocked_reason`

## 红线

- 不自动把 issue 改为 done。
- 不把 token、cookie、密钥写入 memory、runs 或 comment。
- 不默认执行远端副作用。
- 不直接访问生产。
- 不跨 workspace 共享数据。
- 不允许无限循环；必须有最大轮次、超时和升级机制。
- 不能静默失败；失败必须显式进入 evidence 和 review packet。

## MVP 闭环

第一版只做单仓库、issue 驱动、本地优先：

1. Multica issue 输入。
2. 生成本地 task.md。
3. ai-loop discover / plan / run 或 dry-run。
4. 收集 run evidence。
5. 生成 review packet。
6. 生成 comment draft。
7. 人工确认是否写回 Multica。

## 本阶段实现

新增本地 collector：

```bash
scripts/collect-evidence.sh \
  --issue FUZ-xxx \
  --run-id <run-id> \
  --output runs/<run-id>/evidence.json \
  --markdown runs/<run-id>/evidence.md
```

它只读取本地 run 目录，不访问 Multica，不写远端。
