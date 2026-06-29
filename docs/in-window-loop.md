# 窗口内 Loop 协议

## 1. 为什么先做窗口内 Loop

当前 AI Loop 已经能在本地仓库里执行 `plan → dry-run → run → verify → retry`，但聊天窗口里的任务还会遇到外部副作用，例如飞书写入、网络请求、删除块、远程 Git、部署和生产访问。

如果这些外部动作没有先进入 Loop 协议，就会变成执行到一半才弹审批，让用户反复点确认。这不符合 Loop 的目标。

因此，所有 Loop 任务先在当前窗口执行一个轻量控制环，再决定是否调用本地 `ai-loop` CLI 或外部工具。

## 2. 状态机

窗口内 Loop 使用以下状态：

```text
INTAKE → CLASSIFY → PLAN → APPROVE → EXECUTE → VERIFY → REPORT → NEXT
```

| 状态 | 目的 | 输出 |
|---|---|---|
| `INTAKE` | 接收用户目标 | 原始需求 |
| `CLASSIFY` | 判断清晰度和风险 | 任务类型、风险级别 |
| `PLAN` | 给出短计划 | 步骤、验证方式、外部副作用 |
| `APPROVE` | 只对新增外部副作用要确认 | 批准策略或停止 |
| `EXECUTE` | 执行本地或外部动作 | 变更、artifact、日志 |
| `VERIFY` | 验证结果 | 命令结果、读回结果、diff |
| `REPORT` | 汇报状态 | 完成内容、失败原因、下一步 |
| `NEXT` | 决定是否迭代 | 继续、收敛、停止 |

## 3. 默认分流规则

### 3.1 任务不清晰

如果目标、范围或验收标准不清晰，先在窗口内做方案拆解。

如果需要形成可执行任务文件，再使用：

```bash
cd /home/user/JAVA/ai/ai-loop
./bin/ai-loop plan --repo <target-repo> --task <raw-request-file>
```

### 3.2 任务清晰且只影响本地仓库

优先走本地 AI Loop：

```bash
cd /home/user/JAVA/ai/ai-loop
./bin/ai-loop run --repo <target-repo> --task <task-file> --dry-run
./bin/ai-loop run --repo <target-repo> --task <task-file>
```

如果任务耗时较长，用异步脚本后台执行：

```bash
cd /home/user/JAVA/ai/ai-loop
./bin/ai-loop-async start --repo <target-repo> -- run --task <task-file>
```

### 3.3 任务包含外部副作用

外部副作用包括：

- 飞书写入、删除、覆盖、权限修改。
- 网络请求。
- 远程 Git fetch/push/MR。
- 发布、部署、生产访问。
- 删除文件或清理外部资源。

处理规则：

1. 先列出外部副作用清单。
2. 说明每个副作用的原因、目标、回滚方式。
3. 优先使用已批准的命令前缀。
4. 不临时发散到未规划的新命令。
5. 如果需要新权限，先在窗口里说明，再请求一次性批准。

## 4. 审批策略

窗口内 Loop 把审批分成三类：

| 类型 | 示例 | 默认动作 |
|---|---|---|
| 无副作用 | 读本地文件、跑本地编译 | 可直接执行 |
| 可审计低风险 | 写本地 repo、生成 artifact | 计划后执行 |
| 外部副作用 | 飞书写入、远程 Git、部署 | 先列清单并等待批准 |

已经批准过的命令前缀可以复用，但不能扩大语义。例如，批准 `feishu docx update` 不等于批准任意删除、覆盖或权限修改。

## 5. 飞书任务规则

涉及飞书时，必须进入窗口内 Loop：

1. 先明确目标文档 URL。
2. 先读当前内容或相关章节。
3. 说明写入模式：append、replace、delete、overwrite。
4. 优先 append 或 replace，避免 overwrite。
5. 写入后必须读回确认关键文本。
6. 如果读回发现重复、降级、格式损坏，先汇报，不继续扩散调用新工具。

## 6. 窗口内 Loop 输出模板

开始执行前：

```text
Loop Plan
- 目标：...
- 类型：plan / local-run / external-sync
- 预计耗时：... 分钟；估时依据：...
- started_at：... UTC
- 验收：...
- 外部副作用：无 / 有...
- 执行步骤：1...2...3...
```

执行后：

```text
Loop Result
- 状态：PASSED / FAILED / NEEDS_APPROVAL
- 时间复盘：预计 ... 分钟，实际 ... 秒 / ... 分钟，偏差原因：...
- 做了什么：...
- 验证：...
- Artifact：...
- 下一步：...
```

时间要求：每轮开始必须先估时并记录 `started_at`；每轮结束必须用真实 `completed_at` 计算实际用时。没有时间戳时不能声称“实际耗时”。repo-backed 本地任务优先用 `scripts/execution-timer.sh start/close` 生成 run-local timer marker 和 `execution-time-contract-<slice>.json`；只有已有明确时间戳时才直接调用 `scripts/execution-time-contract.sh`。

## 7. 和本地 ai-loop CLI 的关系

窗口内 Loop 是交互层，本地 `ai-loop` CLI 是执行层。

```text
聊天窗口
  → 窗口内 Loop 协议
    → ai-loop plan / run
      → worktree / agent / verify / retry
```

在外部副作用未被协议化前，不应把飞书写入、远程 Git、部署等动作直接塞进本地 `ai-loop run`。

`bin/ai-loop-async` 只负责异步运行本地 `ai-loop plan/run`，不负责绕过审批。窗口内 Loop 仍然是外部副作用的准入层。

## 8. 当前落地规则

以后用户说“做 Loop 任务”时，默认顺序是：

1. 先在当前窗口跑本协议。
2. 如果任务不清晰，先规划。
3. 如果任务清晰且本地可验证，再调用 `/home/user/JAVA/ai/ai-loop`。
4. 如果涉及飞书或网络写入，先列副作用清单，不让用户在执行中途反复点审批。
5. 每轮结束都给出状态、验证结果和下一步。
6. 每轮开始前给出预计耗时，每轮结束后给出实际用时和估时偏差。
