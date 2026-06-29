# 任务分级与执行策略

## 目标

让 AI 接到任务后先判断“走多重的流程”，避免小事重流程、大事轻流程。

## 分级总览

| 等级 | 适用任务 | 默认流程 | 外部写入 | 典型耗时 |
|---|---|---|---|---|
| L0 快速问答 | 解释、检索本地事实、给建议 | 直接回答 | 不写 | 1–10 分钟 |
| L1 轻量本地改动 | 小文档、小脚本、小修复 | preflight 简版 + 本地验证 | 默认不写 | 10–45 分钟 |
| L2 标准执行 | 有明确 issue/task/evidence 的正式任务 | preflight + 实现 + closeout + Obsidian | 可写 Multica/Feishu | 45–180 分钟 |
| L3 高风险协作 | 涉及远端状态、多人协作、生产影响 | 需求澄清 + 方案 + 分阶段 closeout | 写入需 evidence/readback | 半天以上 |
| L4 禁止自动执行 | Git remote、部署、工具安装、全局配置、破坏性操作 | 停止等待单独审批 | 不自动写 | 不适用 |

## 时间盒规则

权威配置在 `config/timebox-policy.json`，脚本和文档都以这里的 L0–L4 策略为准。

| 等级 | 最小连续执行窗口 | 何时允许停下来 |
|---|---|---|
| L0 | 不中断，直接答完 | 需要用户补充事实 |
| L1 | 至少 30 分钟或完成一个可验证切片 | 测试失败且需要外部信息 |
| L2 | 预估 90 分钟；30 分钟防空转阈值；完成可验收 closeout + 写回后立即收口 | 触发 L4 禁止项或连续 3 次同类失败 |
| L3 | 至少 120 分钟或完成一个阶段 closeout | 高风险审批边界或需求根本不清 |
| L4 | 立即停止 | 必须单独审批 |

执行过程中不把“完成一个小脚本 / 一次同步 / 一条评论”当作任务完成，只能算阶段进展。用户给出长时间窗口时，先做准确估时；如果已达到可验收结果，就尽快 closeout 并收口；如果尚未达到可验收结果，才继续找下一组实质交付，直到验收完成、触发审批边界或连续失败。

阶段完成后必须跑本地续跑判断，避免把“已验证一个小切片”误当成整轮结束：

```bash
./scripts/loop-continuation-gate.sh --issue <issue> --run-id <run> --task-tier L2 --started-at <iso> --completed-at <iso>
```

返回 `CONTINUE` 时继续推进下一组实质切片；返回 `ALLOW_STOP` 表示已有可验收执行结果，可以快速汇总；返回 `STOP_FOR_APPROVAL` 时只输出审批边界。

## L0 快速问答

### 判断条件

- 不需要改文件。
- 不需要跑命令或只需少量只读命令。
- 不产生外部写入。

### 输出要求

- 直接给结论。
- 不写 phase report。
- 不写 operation log。
- 不跑 closeout。

## L1 轻量本地改动

### 判断条件

- 改动范围小于 3 个文件。
- 不涉及审批、安全、写回、同步策略。
- 不涉及 Feishu / Multica / Git remote / deploy。

### 执行方式

- 可简化 preflight。
- 做最小本地验证。
- 只在必要时 Obsidian sync。

### 输出要求

- 简短说明文件和验证结果。
- 默认不写 phase report / operation log。

## L2 标准执行

### 判断条件

- 有明确 issue、task、repo、验收标准。
- 需要沉淀 evidence。
- 可能需要 Multica / Feishu 写回。

### 执行方式

```bash
./scripts/loop-execution-preflight.sh --issue <issue> --task <task> --repo <repo> --run-id <run> --no-phase-report --no-operation-log
./scripts/loop-closeout.sh --issue <issue> --task <task> --repo <repo> --run-id <run> --task-tier L2 --started-at <iso> --completed-at <iso> --no-phase-report --no-operation-log
./scripts/loop-continuation-gate.sh --issue <issue> --run-id <run> --task-tier L2 --started-at <iso> --completed-at <iso>
```

### 写回规则

- Multica：可以写 start/progress/final comment 和非破坏性 metadata；done 只在 closeout 通过后写。
- Feishu：必须有明确目标文档/表格；只追加或定点更新；写后 readback。
- Obsidian：验证通过后自动 sync。

## L3 高风险协作

### 判断条件

- 需求不完整或影响面不清。
- 需要跨系统写入。
- 可能影响生产、客户、资金、权限、法律合规。
- 多人或多 agent 协作。

### 执行方式

- 先做需求澄清。
- 输出设计方案和风险清单。
- 分阶段执行，每阶段 closeout。
- 远端写入必须有本地草稿、审批范围、write result、readback。

## L4 禁止自动执行

以下操作不进入自动执行：

- Git remote：fetch、push、创建 remote、MR、PR。
- 部署或生产访问。
- 工具安装。
- 全局 Codex 配置变更。
- 删除、覆盖、大范围重写。
- 未指定目标的 Feishu 批量写入。

## 自动选择规则

| 信号 | 推荐等级 |
|---|---|
| “解释一下 / 看看 / 总结” | L0 |
| “改个文档 / 补个小脚本” | L1 |
| “执行 / 推进 / loop / 写回” 且有 issue | L2 |
| “需求还不清 / 方案设计 / 多系统 / 高风险” | L3 |
| “push / deploy / install / 删除 / 全局配置” | L4 |

## 降 token 规则

- L0/L1 不生成长计划。
- L2 只生成一份 preflight 和一份 closeout。
- L3 才写设计文档。
- 同一主题不连续新建 phase report。
- 验证失败才展开日志；验证成功只报关键行。
- 不在 60 分钟内因普通阶段完成主动停下；阶段完成后继续推进下一组明确切片。
