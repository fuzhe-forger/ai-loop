# Phase 1 MVP：Multica Issue 到本地 ai-loop 的安全桥接

## 阶段目标

Phase 1 的目标是打通最小安全链路：

```text
FUZ-xxx
  -> 本地 task.md
  -> ai-loop dry-run
  -> summary / run artifacts
  -> Multica comment 草稿
```

这个阶段不追求全自动，只验证链路是否成立。

## 为什么先做 dry-run

真正的 AI 工作编排不是先追求“自动完成”，而是先证明系统能安全地接住任务。

dry-run 可以验证：

- issue 是否能被读取。
- task 是否能被规范生成。
- repo 与 task 路径是否正确。
- ai-loop 编排 artifact 是否能生成。
- summary 是否能被转成反馈材料。

在这之前，不应该自动执行真实代码修改。

## MVP 能力

### 1. Issue 拉取

给定一个 `FUZ-xxx`，从 Multica 读取 issue 详情，并保存本地快照。

### 2. Task 生成

把 issue 转成本地 `tasks/FUZ-xxx.md`，内容包括：

- issue 标题。
- issue 描述。
- 当前状态和优先级。
- 建议目标。
- 待人工补充的 repo、验收标准和验证命令。
- 安全边界说明。

### 3. Loop dry-run

调用：

```bash
./bin/ai-loop run --repo <target-repo> --task tasks/FUZ-xxx.md --dry-run
```

只生成编排 artifact，不调用 Agent，不修改代码。

### 4. Comment 草稿

读取 `summary.md`，生成 `multica-comment.md`，用于人工确认后回写。

默认不写 Multica。

## 非目标

Phase 1 不做：

- 自动修改 issue 状态。
- 自动写 comment。
- 自动真实执行开发。
- 自动 push、commit、MR。
- 批量处理队列。
- 自动分派智能体。
- 定时调度。

## 成功标准

以一个真实 issue 为例，例如 `FUZ-438`：

- 能生成 `tasks/FUZ-438.md`。
- 能生成 `runs/<run-id>/summary.md`。
- 能生成 `runs/<run-id>/multica-comment.md`。
- 默认没有任何 Multica 写操作。
- 所有本地验证命令通过。

## 安全策略

默认策略：

- Multica：只读。
- Git：只本地。
- ai-loop：先 dry-run。
- comment：只生成草稿。
- status：不修改。
- batch：不支持。

任何外部副作用都必须显式开启，并在窗口内 Loop 协议里说明。

## 后续阶段

### Phase 2：显式回写 comment

增加 `--write-comment`，把 comment 草稿写回 Multica。

### Phase 3：显式同步 status

增加 `--write-status`，根据 Loop 结果更新 issue 状态。

### Phase 4：真实 run

在 repo、验收和验证命令明确后，支持真实 `ai-loop run`。

### Phase 5：队列与调度

让黑墙根据策略从 Multica 队列中挑选任务，交给 Codex-顾实、Xcode 或测真。

## 分享重点

Phase 1 的分享重点不是“我们写了一个脚本”，而是：

- 如何把远端协作系统和本地 AI 执行系统解耦。
- 如何让 AI 执行默认安全。
- 如何用 artifacts 作为事实来源。
- 如何为后续自动化建立边界。

## 当前 MVP 命令

Phase 1 初版通过独立 wrapper 提供能力，避免改动 ai-loop 核心运行器：

```bash
./scripts/multica-loop.sh \
  --issue FUZ-552 \
  --repo /home/user/JAVA/ai/ai-loop \
  --run-id FUZ-552-demo
```

该命令会：

1. 读取 Multica issue。
2. 生成 `tasks/FUZ-552.md`。
3. 执行 `./bin/ai-loop run --dry-run`。
4. 生成 `runs/FUZ-552-demo/multica-comment.md`。

`--write-comment` 在 Phase 1 只作为显式意图标记，不会真正写回 Multica。
