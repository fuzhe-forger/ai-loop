# 司南 v0.2 工作台总览

## 一句话

司南 v0.2 是一套“AI 执行任务不乱跑”的本地工作台：先判断任务规模和副作用，再执行、验证、沉淀、写回，避免反复补救、反复审批、反复浪费 token。

## 解决的问题

- **需求没说清就开写**：先过执行前 checklist，不清楚就澄清。
- **AI 自己越改越远**：所有任务必须有目标、范围、验收和副作用边界。
- **证据散在多个文件里**：用 closeout 把验证、evidence、share-preflight 收成一个出口。
- **任务耗时靠感觉复盘**：用可信时间戳记录 `started_at/completed_at`，只让可审计样本进入估时校准。
- **开工不估时、收工不用时**：用执行时间契约强制每轮先估时、后复盘实际用时和偏差。
- **报告和日志膨胀**：默认不写 phase report / operation log，只有机制变化或外部写入才记录。
- **外部写入失控**：Feishu / Multica 写入必须先有草稿或 evidence，写完 readback。
- **Obsidian 同步反复打断**：Obsidian generated sync 已常驻授权，验证通过后自动同步。

## 工作流

```text
任务输入
  -> 任务分级
  -> 执行前 checklist
  -> 本地执行
  -> closeout 验证
  -> evidence / Obsidian 沉淀
  -> 必要时 Multica / Feishu 写回
  -> 最终总结或 done
```

## 核心入口

| 入口 | 作用 | 什么时候用 |
|---|---|---|
| `loop-execution-preflight.sh` | 生成执行前 checklist | 每个正式任务开始前 |
| `sinan-capability-check.sh` | 校验司南能力注册表 | 新能力加入或入口调整后 |
| `25-execution-time-contract.md` | 执行时间契约 | 每轮开始和结束都要遵守 |
| `loop-closeout.sh` | 统一本地收尾 | 本地实现完成后 |
| `verify-toolchain.sh` | 工具链与 gate 验证 | closeout 内部和关键改动后 |
| `loop-continuation-gate.sh` | 连续执行与可信计时门禁 | 每轮阶段完成时 |
| `time-estimation-calibration.sh` | 估时校准报告 | closeout / Multica Loop 自动生成，复盘时读取 |
| `share-preflight.sh` | 分享前证据摘要 | 需要交接、复盘、写回前 |
| `obsidian-sync.sh` | 同步知识库 generated | 本地验证通过后自动执行 |

## 默认决策

| 问题 | 默认规则 |
|---|---|
| 要不要写 phase report？ | 默认不写；只有机制、策略、可复用能力变化才写 |
| 要不要写 operation log？ | 默认不写；只有外部写入、批量授权、关键审计点才写 |
| 能不能写 Multica？ | 可以，但必须先有 evidence / 草稿，写后 readback |
| 能不能写 Feishu？ | 可以，但必须有明确目标文档/表格，只追加或定点更新 |
| 能不能改 done？ | closeout + 验证通过后可以 |
| 能不能自动同步 Obsidian？ | 可以，只写 `99-generated/` |
| 能不能把手填耗时当实际耗时？ | 不可以；只有 `timing_source=timestamp` 进入可信校准 |
| 能不能不做开工估时/收工用时复盘？ | 不可以；这是司南默认执行契约 |
| 能不能 Git push / 部署 / 安装工具？ | 不可以，必须单独审批 |

## 当前能力状态

- **任务前置判断**：已可用。
- **本地 closeout**：已可用。
- **Obsidian 可复盘页面**：已可用。
- **Multica 写回与 readback**：已跑通。
- **可信计时与估时校准**：已内置到 continuation gate / closeout / verify-toolchain；manual 只作回退审计，不参与校准。
- **能力注册表**：已用 `config/sinan-capabilities.json` 聚合核心能力、入口脚本、证据产物、文档和验证方式。
- **Feishu 写回策略**：已定义，待明确目标文档后执行。
- **自动任务分级建议**：下一步增强。

## 用法示例

```bash
./scripts/loop-execution-preflight.sh \
  --issue FUZ-554 \
  --task tasks/FUZ-554.md \
  --repo . \
  --run-id FUZ-554-real-multica-loop-gated-20260622-142303 \
  --allow-multica-write \
  --no-phase-report \
  --no-operation-log
```

```bash
./scripts/loop-closeout.sh \
  --issue FUZ-554 \
  --task tasks/FUZ-554.md \
  --repo . \
  --run-id FUZ-554-real-multica-loop-gated-20260622-142303 \
  --allow-multica-write \
  --no-phase-report \
  --no-operation-log
```

## 价值判断

司南 v0.2 的价值不是“多几个脚本”，而是把 AI 执行从临场发挥变成固定工作台：

- 开始前知道该不该做、怎么做、能不能写外部系统。
- 结束时有统一证据，不需要翻一堆中间日志。
- 外部写入可追溯，可 readback。
- 人类审批只在真正高风险边界出现。
