# 现场演示脚本：Multica × ai-loop AI 工作编排

## 演示目标

用 5–8 分钟展示：一个 AI 工作编排系统应该如何从“任务”走到“证据”和“复核”，而不是只展示 AI 回答。

## 演示前准备

在仓库根目录执行：

```bash
cd /home/user/JAVA/ai/ai-loop
git status -sb
```

预期：除非有明确说明，否则工作树应干净或只包含已知草稿。

当前可接受的已知草稿：

```text
tasks/FUZ-560-getSkuMaterialWarranties-loop-plan.md
```

讲法：这是另一条任务草稿，不纳入本次 FUZ-554 分享链路。

## Step 1：展示终局

打开：

```text
docs/ai-work-orchestration/09-north-star.md
```

讲三句话：

- 终局不是脚本，是 AI 工程团队操作系统。
- Multica 管任务，ai-loop 管执行事实，Multica Loop 管组织治理。
- 分享不是炫技，而是展示可治理闭环。

## Step 2：展示案例

打开：

```text
docs/ai-work-orchestration/share/FUZ-554-one-page.md
```

讲三句话：

- FUZ-554 是第一个完整证据链案例。
- 它覆盖 task、run、summary、stage report、comment draft、patch summary、review packet、strict gate。
- 它证明我们能从 issue 走到可复核 artifacts。

## Step 3：现场收集 evidence

执行：

```bash
./scripts/collect-evidence.sh \
  --issue FUZ-554 \
  --run-id FUZ-554-scope-split-review \
  --output /tmp/fuz554-evidence.json \
  --markdown /tmp/fuz554-evidence.md
```

展示：

```bash
sed -n '1,120p' /tmp/fuz554-evidence.md
```

讲三句话：

- AI 说完成不算，evidence 才算。
- core evidence 是 summary、stage report、comment draft。
- strict gate 可以阻止证据不完整的回写，state gate 可以确认状态和 metadata evidence 已生成。

## Step 4：刷新 state evidence

执行：

```bash
./scripts/refresh-run-evidence.sh \
  --pattern 'FUZ-554*' \
  --issue FUZ-554 \
  --output /tmp/fuz554-refresh.md
```

展示：

```bash
rg -n "Refreshed runs|Remote writes" /tmp/fuz554-refresh.md
```

讲三句话：

- 每个 run 不只要有 summary，还要能进入状态机。
- refresh 会生成 state evaluation 和 metadata draft。
- 这一步只写本地 runs，不写 Multica。

## Step 5：运行 strict + state gate

执行：

```bash
./scripts/verify-toolchain.sh \
  --case FUZ-554 \
  --pattern 'FUZ-554*' \
  --strict \
  --state-gate \
  --output /tmp/fuz554-strict.md
```

展示：

```bash
rg -n "Strict Evidence Gate|State Metadata Gate|state metadata gate passed" /tmp/fuz554-strict.md
```

讲三句话：

- 这不是人工口头检查，是可执行 gate。
- 每个 run 都必须有 core evidence、state evidence、metadata draft。
- 这让分享和回写有最低质量线。

## Step 6：展示 scope split

打开：

```text
runs/FUZ-554-scope-split-review/scope-split-report.md
```

讲三句话：

- 工程系统不仅要证明做了什么，还要证明没有越界。
- scope split 是提交前历史 artifact，当时用于把 FUZ-554 包、核心代码包、其他任务草稿、本地 evidence 分开。
- 这就是 human in command 的体现。

注意：当前工作树已经完成拆分提交，所以这里展示的是“当时如何防止混合提交”的证据，不代表当前 git status。

## Step 7：展示黑墙确认后的设计

打开：

```text
docs/ai-work-orchestration/08-multica-loop-refactor.md
```

讲三句话：

- 天道不是独立代码，而是编排经验。
- 我们不引入 LingTai 代码，而是自研 Multica Loop。
- 下一步是 evidence 标准、状态机、项目记忆。

## 收尾

最后落一句：

> 这套系统的目标不是让 AI 自动做完一切，而是让 AI 的工作变成团队可以治理、验证、复盘和持续改进的工程事实。
