# Multica Loop 组织层验证

## 验证目标

验证 `scripts/multica-loop.sh` 和配套脚本能否正确完成完整 evidence 链路：

1. 任务输入 → task.md
2. ai-loop dry-run 执行
3. state-evaluation 状态判断
4. metadata-draft 元数据草稿
5. comment-draft 评论草稿
6. review-packet 人工复核包
7. strict + state gate 验证

## 验证流程

### 输入

- 任务文件：`tasks/multica-loop-test.md`
- Run ID：`multica-loop-validation-pilot`
- 模式：dry-run

### 执行

```bash
./bin/ai-loop run --repo . --task tasks/multica-loop-test.md --dry-run --run-id multica-loop-validation-pilot
./scripts/evaluate-state.sh --issue LOOP-TEST --run-id multica-loop-validation-pilot --write-run
./scripts/metadata-draft.sh --issue LOOP-TEST --run-id multica-loop-validation-pilot --output runs/multica-loop-validation-pilot/metadata-draft.json --markdown runs/multica-loop-validation-pilot/metadata-draft.md
./scripts/review-packet.sh --case LOOP-TEST --pattern multica-loop-validation-pilot --output runs/multica-loop-validation-pilot/review-packet.md
./scripts/verify-toolchain.sh --case LOOP-TEST --pattern multica-loop-validation-pilot --strict --state-gate --output /tmp/loop-verify.md
```

### 输出

| Artifact | 状态 | 路径 |
|---|---|---|
| summary.md | ✓ | runs/multica-loop-validation-pilot/summary.md |
| stage-report.md | ✓ | runs/multica-loop-validation-pilot/stage-report.md |
| multica-comment.md | ✓ | runs/multica-loop-validation-pilot/multica-comment.md |
| state-evaluation.json | ✓ | runs/multica-loop-validation-pilot/state-evaluation.json |
| state-evaluation.md | ✓ | runs/multica-loop-validation-pilot/state-evaluation.md |
| metadata-draft.json | ✓ | runs/multica-loop-validation-pilot/metadata-draft.json |
| metadata-draft.md | ✓ | runs/multica-loop-validation-pilot/metadata-draft.md |
| review-packet.md | ✓ | runs/multica-loop-validation-pilot/review-packet.md |

## 验证结果

### Strict Evidence Gate

- Core Evidence：**PASSED**
- 必需文件：summary.md、stage-report.md、multica-comment.md 全部存在

### State Metadata Gate

- State Evidence：**PASSED**
- 必需文件：state-evaluation.json、state-evaluation.md、metadata-draft.json、metadata-draft.md 全部存在
- metadata.assigned_actor：**存在**（顾实）

### Toolchain Smoke Checks

- 全部 bash 语法检查：**PASSED**
- multica-loop --policy-help：**PASSED**
- collect-evidence：**PASSED**
- evaluate-state：**PASSED**
- metadata-draft：**PASSED**
- route-actor：**PASSED**

## 状态推进建议

根据 state-evaluation：

- From：running
- To：evidence_ready
- Next actor：execution_agent（顾实）
- Reason：core evidence complete; verification report is not present

## 结论

Multica Loop 组织层脚本已可用：

- ✓ 完整 evidence 生成链路
- ✓ 状态判断和元数据草稿
- ✓ 机组角色路由
- ✓ strict + state gate 验证
- ✓ 本地优先、人工复核

下一步可将 `multica-loop.sh` 用于真实低风险 issue 验证端到端流程。
