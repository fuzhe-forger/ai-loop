# Evidence 标准

## 定义

Evidence 是一次 AI 工作执行后留下的可复核交付凭证。

它不等同于“AI 的总结”，而是用于回答：

> 这件事凭什么判断完成、失败、可复核或需要升级？

## 设计目标

- 让执行结果可检查，而不是只相信对话。
- 让 Multica Loop 可以基于证据推进状态。
- 让人类 reviewer 能快速判断是否继续、回滚、补充或回写。
- 让技术分享和复盘有稳定材料来源。

## 分层

### Core Evidence

每个有效 run 必须具备：

| 文件 | 作用 |
|---|---|
| `summary.md` | 本次执行做了什么、结论是什么 |
| `stage-report.md` | 阶段目标、产出、验证、风险 |
| `multica-comment.md` | 准备回写给 Multica 的结构化说明 |

`verify-toolchain.sh --strict` 当前以这三项作为最小门禁。

### Execution Evidence

证明执行过程和验证结果：

| 文件 | 作用 |
|---|---|
| `verification-report.md` | 本地脚本、语法、strict gate 等验证结果 |
| `patch-summary.md` | 变更文件、影响范围、风险点 |
| `run.json` | 机器可读执行状态，后续用于自动汇总 |

### Review Evidence

证明结果已经进入可复核状态：

| 文件 | 作用 |
|---|---|
| `review-packet.md` | 给 reviewer 的一包材料入口 |
| `scope-split-report.md` | 防止混合提交和范围越界 |
| `evidence.md` | evidence collector 生成的可读索引 |
| `evidence.json` | evidence collector 生成的机器可读索引 |

### Writeback Evidence

证明远端副作用是否发生：

| 文件 | 作用 |
|---|---|
| `writeback-summary.md` | 是否写 Multica、写了什么、结果如何 |
| `logbook.md` | 项目级阶段流水记录 |

## 最小合格线

### 普通 run

必须具备：

- `summary.md`
- `stage-report.md`
- `multica-comment.md`

### 涉及代码变更的 run

除 Core Evidence 外，还应具备：

- `patch-summary.md`
- `verification-report.md`
- 必要时补 `review-packet.md`

### 涉及远端回写的 run

除 Core Evidence 外，还必须具备：

- `writeback-summary.md`
- `logbook.md` 记录

## 判定规则

| 判定 | 条件 |
|---|---|
| `missing_evidence` | 缺少任一 Core Evidence |
| `ready_for_review` | Core Evidence 齐全，且验证结果可读 |
| `ready_for_writeback` | Core Evidence 齐全，comment draft 清楚，副作用已授权 |
| `blocked` | 验证失败、范围不清、缺权限或缺关键上下文 |
| `done` | 人类复核通过，且必要回写已完成 |

## 生成要求

- 文件名稳定，方便脚本收集。
- 内容优先结构化，避免只写自然语言流水账。
- 明确列出验证命令和结果。
- 明确列出未完成项和风险。
- 不写入 token、cookie、密钥、生产数据。
- 不把“计划做”写成“已经完成”。

## 脚本落点

当前已有两个本地能力：

```bash
./scripts/collect-evidence.sh \
  --issue FUZ-554 \
  --run-id FUZ-554-scope-split-review \
  --output /tmp/fuz554-evidence.json \
  --markdown /tmp/fuz554-evidence.md

./scripts/verify-toolchain.sh \
  --case FUZ-554 \
  --pattern 'FUZ-554*' \
  --strict \
  --output /tmp/fuz554-strict.md
```

## 下一步

- 把 `evidence.json` 作为 Multica Loop 的状态输入。
- 把判定规则接入 Loop 状态机。
- 为更多真实 issue 生成同样结构的 evidence。
