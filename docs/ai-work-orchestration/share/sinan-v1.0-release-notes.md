# 司南 v1.0 Release Notes

## 一句话

司南 v1.0 把 AI 从“会话里的执行助手”推进为“可治理、可审计、可复盘的 AI 需求交付系统”。

## 主要能力

- 需求/方案/交付门禁：先澄清、先设计、先验收。
- 时间校准：每轮开工估时，收工记录真实耗时并复盘偏差。
- Evidence 标准：执行结果进入可复核证据链。
- 人控写回：飞书、Multica、metadata 写回有审批和 readback。
- 项目记忆：经验、决策、踩坑和偏好可沉淀和推荐。
- 多角色质量：规划、执行、审查、测试、表达职责分离。
- 团队复制：演示脚本、最佳实践、模板、能力注册表齐备。

## 从 v0.2 到 v1.0 的变化

| 维度 | v0.2 | v1.0 |
|---|---|---|
| 定位 | 本地可控闭环工作台 | AI 需求交付系统 |
| 门禁 | 已有脚本 MVP | 有规范、样例、回归验证 |
| 时间 | 开始内置校准 | 明确版本能力和限制 |
| 写回 | 受控写回跑通 | 明确 release 级边界和 readback 要求 |
| 记忆 | 文件化开始 | 纳入 v1.0 能力边界 |
| 分享 | 有案例包 | 有 release notes 和复制路线 |

## 验收证据

- Version source：`config/sinan-version.json`
- Version doc：`docs/ai-work-orchestration/VERSION.md`
- Known limits：`docs/ai-work-orchestration/Known-Limits.md`
- Backlog：`docs/ai-work-orchestration/backlog-v1.1.md`
- Product manual：`docs/ai-work-orchestration/product/sinan-v1-product-manual.md`
- Roadmap：`docs/ai-work-orchestration/product/sinan-v1-to-v2-roadmap.md`
- Gap audit：`runs/<current-run>/v1-gap-audit.md`
- Final acceptance：`runs/v1.0-final/acceptance-report.md`

## 已知限制

详见 `docs/ai-work-orchestration/Known-Limits.md`。核心边界是：不自动 reviewer 裁决、不自动远端写回决策、不自动部署、不把 P50/P80 当承诺。

## 推荐下一步

1. 使用 `product/sinan-v1-product-manual.md` 作为 v1.0 对外说明和快速上手入口。
2. 按 `product/sinan-v1-to-v2-roadmap.md` 推进 v1.1 到 v2.0。
3. 用真实文档、代码、写回任务补齐 v1.1 E2E case pack。
4. 持续收集 timestamp 样本，优化估时准确率。
