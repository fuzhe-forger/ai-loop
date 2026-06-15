# 下一真实代码任务候选池

## 目标

在 `FUZ-554` 已完成真实 patch 闭环后，选择下一条更接近业务开发但仍低风险的代码任务，继续验证 AI Loop 的工程落地能力。

候选池的目标不是一次性排满路线图，而是给下一轮选择提供清晰标准：什么任务值得做，为什么风险可控，如何验证，完成后能产出什么证据。

## 选择标准

候选任务必须满足：

- 范围小：只改一个脚本、一个 CLI 子命令或一小段本地逻辑。
- 本地可验证：不依赖生产系统、远端账号或真实数据。
- 副作用低：不部署、不写库、不推送、不创建 MR。
- 可复核：能生成 patch summary、verification report、review packet。
- 可分享：完成后能沉淀为团队可复用经验。

## 候选任务

### A. Patch summary 增加 `--check-scope`

状态：已完成，落地为 `scripts/patch-summary.sh --allow-prefix` / scope check。

为 `scripts/patch-summary.sh` 增加一个只读检查能力：根据传入的允许路径前缀，标记当前 changed/untracked files 是否超出范围。

- 类型：脚本参数校验增强
- 风险：低
- 验证：本地构造 allow-prefix，运行 `patch-summary.sh --check-scope`
- 价值：把“是否超出 scope”从人工阅读推进到工具辅助
- 推荐度：高

### B. Review packet 增加 `--include-patch-summary`

状态：已完成，落地为 `scripts/review-packet.sh --include-patch-summary <file>`。

让 `scripts/review-packet.sh` 可以引用某个 patch summary 文件，把 patch 范围信息纳入 human review packet。

- 类型：报告生成增强
- 风险：低
- 验证：本地生成 review packet 并检查包含 patch summary 路径
- 价值：把代码改动证据接入复核入口
- 推荐度：高

### C. Evidence index 增加排序稳定性说明

状态：已完成，落地为 `scripts/evidence-index.sh` 的 `Metadata` 区块。

为 `scripts/evidence-index.sh` 的输出增加排序说明和生成时间，减少多人复核时对索引顺序的疑问。

- 类型：报告可读性增强
- 风险：低
- 验证：本地生成 index 并检查说明字段
- 价值：小，但能提高报告可信度
- 推荐度：中

### D. Verify toolchain 增加 `--strict`

状态：已完成，落地为 `scripts/verify-toolchain.sh --strict`。

在默认 smoke check 外增加 strict 模式，要求指定 pattern 下每个 run 都有 summary、stage report 和 comment draft。

- 类型：工具链验证增强
- 风险：中
- 验证：对 `FUZ-554*` 运行 strict 检查
- 价值：让证据完整性变成可执行 gate
- 推荐度：中高

## 推荐下一步

当前建议：暂停继续扩展新脚本能力，进入阶段复核与提交准备。

原因：

- A/B/C/D/E 已经完成并形成证据链。
- 当前工具链已覆盖 evidence、patch、review、strict gate 的核心闭环。
- 继续增加小功能的边际价值下降，下一步更适合做人工复核、整理提交或选择更真实的业务改动。
- 仍保持不访问远端系统、不改变状态同步策略。

### E. Review packet 增加生成时间与排序说明

状态：已完成，落地为 `scripts/review-packet.sh` 的 `Metadata` 区块。

为 `scripts/review-packet.sh` 的输出增加 metadata：生成时间、pattern 和 run 表排序说明。

- 类型：报告可读性增强
- 风险：低
- 验证：本地生成 review packet 并检查 `Metadata` 区块
- 价值：让人工复核包与 evidence index 的可复核字段保持一致
- 推荐度：中高

## 下一任务草案

任务名：`FUZ-554-T Stage Review And Commit Prep`

目标：停止继续扩展脚本功能，整理当前所有本地改动、运行最终 strict gate，并准备一份人工复核/提交前检查清单。

验收：

- 输出当前改动范围摘要。
- 输出最终 strict gate 结果。
- 输出未回写 comment/status 的清单。
- 默认行为保持本地只读。
- 不访问 Multica，不写远端。

验证命令：

```bash
git status -sb
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --strict --output runs/FUZ-554-stage-review-commit-prep/verification-report.md
./scripts/review-packet.sh --case FUZ-554 --pattern 'FUZ-554*' --output runs/FUZ-554-stage-review-commit-prep/review-packet.md
```

## 决策点

如果下一轮继续推进，默认选择 T 做阶段复核与提交准备，除非用户指定继续扩展功能。
