# 受控回写策略模型

## 目标

建立 comment/status/metadata 回写的门禁机制，确保远端副作用可控、可审计、可撤销。

## 定位

Phase E 的核心是把回写从"脚本参数控制"升级成"policy gate 保护"，让每次远端副作用都有明确的：

- 前置条件检查
- 人工确认记录
- 失败回滚方案
- 审计日志

## 设计原则

- **默认不写**：没有明确授权，不执行任何远端副作用
- **分类授权**：comment、status、metadata 分开授权，不捆绑
- **可撤销**：写入失败或写错时，有明确的回滚方案
- **可审计**：每次写入都记录在 writeback-summary 和 git 历史
- **人控为主**：自动化是可选项，人工确认是必需项

## 回写类型

### 1. Comment 回写

**定位**：最低风险的回写类型，用于同步执行进展。

**前置条件**：

- ✅ Core evidence 齐全（summary、stage-report、comment-draft）
- ✅ Comment draft 存在且非空
- ✅ Comment draft 不包含密钥或敏感信息

**授权方式**：

- 方式 1：命令行 `--write-comment` 标志
- 方式 2：环境变量 `MULTICA_WRITE_COMMENT=true`
- 方式 3：配置文件 `writeback.policy.comment=allow`（后续实现）

**失败处理**：

- 写入失败记录到 `multica-write-error.log`
- writeback-summary 标记 `comment_written: failed`
- 不阻塞后续流程

**回滚方案**：

- Multica comment 可以删除或编辑
- 本地 comment draft 保留，可重新提交

### 2. Status 回写

**定位**：中风险回写类型，影响 issue 工作流。

**前置条件**：

- ✅ Core evidence 齐全
- ✅ Strict gate 通过
- ✅ State gate 通过
- ✅ State evaluation 建议的状态转换合法
- ✅ 状态策略明确（conservative / validation / no-status）

**授权方式**：

- 方式 1：命令行 `--write-status` 标志
- 方式 2：环境变量 `MULTICA_WRITE_STATUS=true`
- 方式 3：配置文件 `writeback.policy.status=conservative`（后续实现）

**状态策略**：

| 策略 | 说明 | 适用场景 |
|-----|------|---------|
| `conservative` | dry-run PASSED → todo（证明准备就绪，但未实际执行） | 默认策略 |
| `validation` | dry-run PASSED → in_review（验证类任务，dry-run 即为完成） | 基础设施验证 |
| `no-status` | 不写状态 | 观察模式 |

**失败处理**：

- 写入失败记录到 `multica-write-error.log`
- writeback-summary 标记 `status_written: failed`
- 退出码非零，阻塞后续流程

**回滚方案**：

- Multica 可以手动改回原状态
- 本地 state-evaluation 保留，可重新执行

### 3. Metadata 回写

**定位**：高风险回写类型，影响 issue 元数据和工作记忆。

**前置条件**：

- ✅ Core evidence 齐全
- ✅ Strict gate 通过
- ✅ State gate 通过
- ✅ Metadata draft 存在且格式正确
- ✅ Metadata draft 不覆盖人工设置的字段
- ✅ 人工明确批准

**授权方式**：

- 方式 1：命令行 `--write-metadata` 标志 + `--metadata-approved-by <name>`
- 方式 2：配置文件 `writeback.policy.metadata=require-approval`（后续实现）

**可写字段**：

| 字段 | 可写 | 说明 |
|-----|------|------|
| `pipeline_status` | ✅ | Loop 流水线状态 |
| `latest_run_id` | ✅ | 最新 run 标识 |
| `strict_gate` | ✅ | 证据门禁结果 |
| `next_actor` | ✅ | 下一步抽象角色 |
| `assigned_actor` | ✅ | 下一步具体处理人 |
| `review_verdict` | ❌ | 仅由 reviewer 写入 |
| `blocked_reason` | ✅ | 阻塞原因 |
| `assignee` | ❌ | 仅人工分配 |
| `priority` | ❌ | 仅人工设置 |

**失败处理**：

- 写入失败记录到 `multica-write-error.log`
- writeback-summary 标记 `metadata_written: failed`
- 退出码非零，阻塞后续流程

**回滚方案**：

- Multica metadata 可以手动删除或覆盖
- 本地 metadata draft 保留，可重新执行

## 门禁检查

### Writeback Gate

新增 `scripts/writeback-gate.sh`，在回写前执行检查：

```bash
./scripts/writeback-gate.sh \
  --issue FUZ-554 \
  --run-id <run-id> \
  --type comment \
  --policy conservative \
  --output writeback-gate-report.md
```

**检查项**：

| 检查项 | comment | status | metadata |
|-------|---------|--------|----------|
| Core evidence | ✅ | ✅ | ✅ |
| Strict gate | ❌ | ✅ | ✅ |
| State gate | ❌ | ✅ | ✅ |
| Draft 文件存在 | ✅ | ✅ | ✅ |
| 敏感信息检查 | ✅ | ❌ | ✅ |
| 状态转换合法 | ❌ | ✅ | ❌ |
| Metadata 格式 | ❌ | ❌ | ✅ |
| 人工批准 | ❌ | ❌ | ✅ |

**输出**：

```json
{
  "gate": "writeback",
  "type": "comment",
  "issue": "FUZ-554",
  "run_id": "FUZ-554-scope-split-review",
  "result": "PASSED",
  "checks": {
    "core_evidence": "PASSED",
    "draft_exists": "PASSED",
    "no_secrets": "PASSED"
  },
  "allowed": true,
  "reason": "all checks passed"
}
```

## 多角色协作

### 角色职责

| 角色 | 可执行回写 | 需要审批 | 说明 |
|-----|-----------|---------|------|
| `execution_agent` (顾实) | comment | ❌ | 可同步进展，不改状态 |
| `reviewer` (裴衡) | comment, status | metadata | 可复核通过并改状态 |
| `human` (人类) | 全部 | ❌ | 最终决策权 |
| `scheduler` (黑墙) | comment | status, metadata | 可分派任务，不直接改状态 |
| `tester` (测真) | comment | ❌ | 可报告测试结果 |
| `scribe` (简辞) | comment | ❌ | 可沉淀文档 |

### 协作流程

```
execution_agent (顾实)
  → 执行任务，生成 evidence
  → 写 comment 同步进展
  ↓
reviewer (裴衡)
  → 复核 evidence 和 review packet
  → 写 comment 给出复核结论
  → 改 status 为 in_review / done / blocked
  ↓
human (人类)
  → 确认是否回写 metadata
  → 确认是否关闭 issue
```

## 审计日志

### Writeback Summary

每次回写都生成 `writeback-summary.md`：

```markdown
# Writeback Summary

## Scope
- Issue: FUZ-554
- Run ID: FUZ-554-scope-split-review
- Timestamp: 2026-06-16T16:00:00Z

## Requests
- Write comment: true
- Write status: true
- Write metadata: false

## Gate Results
- Writeback gate: PASSED
- Core evidence: PASSED
- Strict gate: PASSED
- State gate: PASSED

## Execution
- Comment written: true
- Status written: true (todo → in_review)
- Metadata written: false

## Approval
- Requested by: execution_agent (顾实)
- Approved by: human (人类)
- Approval time: 2026-06-16T16:00:00Z

## Rollback
- Comment ID: abc123 (可删除)
- Previous status: todo (可恢复)
- Metadata: not written (无需回滚)
```

### Git 记录

每次回写后提交 writeback-summary 到 git：

```bash
git add runs/<run-id>/writeback-summary.md
git commit -m "Record writeback for FUZ-554 run <run-id>

- Comment: written
- Status: todo → in_review
- Metadata: not written
- Approved by: human"
```

## MVP 实现范围

Phase E 只实现：

- ✅ 新增 writeback gate 脚本
- ✅ Comment 回写门禁检查
- ✅ Status 回写门禁检查
- ✅ Metadata 回写门禁检查（require-approval）
- ✅ 敏感信息检查
- ✅ Writeback summary 审计日志
- ✅ 角色权限表

暂不实现：

- ❌ 配置文件驱动的 policy
- ❌ 自动回滚
- ❌ 回写历史查询
- ❌ 回写冲突检测

## 后续演进

Phase F+：

- 配置文件驱动的回写策略
- 回写历史查询和统计
- 回写冲突检测和解决
- 多人协作的锁机制
- 回写审批工作流

## 价值

受控回写让 AI 工作从"本地执行"升级成"闭环同步"，同时保持人控为主：

- **可控**：每次回写都有门禁保护
- **可审计**：完整的审计日志
- **可撤销**：失败有明确回滚方案
- **可协作**：多角色分工明确

---

**文档状态**：Phase E 设计  
**生成时间**：2026-06-16
