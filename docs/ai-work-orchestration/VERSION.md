# 司南版本说明

## 当前版本

- Product：司南
- Version：v1.0.0
- Baseline：v0.2 工作台
- Version source：`config/sinan-version.json`
- Release date：2026-06-24
- Release status：released（本地治理能力发布，未执行代码部署）

## v1.0 定义

司南 v1.0 的定义不是“自动做完所有事”，而是把 AI 需求交付过程稳定纳入治理：任务进入、需求澄清、方案门禁、本地执行、证据收集、时间校准、项目记忆、受控写回、复盘分享都有可追溯产物。

## v1.0 必备能力

| 能力 | 验收口径 | 证据 |
|---|---|---|
| 需求/方案/交付门禁 | 需求不清先追问，执行前有方案，交付前有证据 | `docs/ai-work-orchestration/gates/`、`fixtures/gates/` |
| 时间校准 | 开工估时、收工真实耗时、偏差复盘 | `scripts/execution-timer.sh`、`scripts/time-estimation-calibration.sh` |
| Evidence 标准 | run 结果能被 review、写回和分享复用 | `docs/ai-work-orchestration/10-evidence-standard.md`、`config/evidence-artifacts.json` |
| 人控写回 | 飞书/Multica/metadata 写回有审批和 readback | `scripts/approval-boundary.sh`、`scripts/writeback-gate.sh` |
| 项目记忆 | 经验、偏好、踩坑能被推荐和复用 | `docs/ai-work-orchestration/15-project-memory-model.md`、`scripts/recommend-memory.sh` |
| 多角色质量 | 路由、审查、验收职责明确，不自动裁决 | `docs/ai-work-orchestration/13-agent-crew-model.md`、`config/routing-policy.json` |
| 团队复制 | 有演示、模板、最佳实践和能力目录 | `docs/ai-work-orchestration/share/`、`config/sinan-capabilities.json` |
| 发布边界 | 已知限制清楚，不夸大自动化 | `docs/ai-work-orchestration/Known-Limits.md` |

## v1.0 不代表

- 不代表自动 reviewer 可以给最终裁决。
- 不代表自动远端写回决策。
- 不代表允许无审批部署、删除或生产操作。
- 不代表时间估计已经稳定到 1 分钟内；v1.0 只要求校准机制存在并持续记录。
- 不代表替代人类需求确认、方案决策和最终验收。

## 升级口径

- v0.2：本地可控闭环工作台。
- v1.0：可治理的 AI 需求交付系统。
- v1.1：服务化、跨仓库、数据库记忆和策略自动化候选方向。
