# AI 工作编排技术分享包

## 这是什么

这是 `Multica × ai-loop` AI 工作编排实践的技术分享材料包。

它服务一个目标：把项目从“做了很多脚本和阶段报告”整理成一套可以对团队讲清楚、演示清楚、复盘清楚的方法论。

## 推荐使用顺序

### 1. 先定方向

阅读：

- `../09-north-star.md`

用途：

- 明确终极效果。
- 解释为什么这不是脚本集合，而是 AI 工程团队操作系统。
- 统一后续分享口径。

### 2. 快速了解案例

阅读：

- `FUZ-554-one-page.md`

用途：

- 给没时间看完整文档的人快速理解 FUZ-554。
- 适合发在会前预读或会后总结。

### 3. 准备正式分享

阅读：

- `tech-sharing-outline.md`

用途：

- 20–30 分钟技术分享的大纲。
- 确定讲述顺序：终局 → 问题 → 架构 → 案例 → 工具链 → 路线。

### 4. 制作 PPT

阅读：

- `slide-deck.md`
- `slides-content.md`

用途：

- 直接转成幻灯片。
- 每页包含标题、核心信息、建议画面、讲者备注。
- `slides-content.md` 提供更精简的上屏文案。

### 5. 排练讲法

阅读：

- `speaker-notes.md`

用途：

- 按 14 页逐页排练。
- 控制 25 分钟左右分享节奏。
- 每页包含时间、讲法、重点、转场。

### 6. 做现场演示

阅读：

- `demo-script.md`
- `sinan-demo-script.md`

用途：

- 指导现场演示命令。
- 演示 `collect-evidence`、`refresh-run-evidence`、`verify-toolchain --strict --state-gate`、scope split 等稳定 artifacts。
- 演示司南从 preflight、evidence、share-preflight 到 approval boundary 的 5 分钟闭环。
- 避免依赖 live coding。

### 7. 会前预检

阅读：

- `preflight-checklist.md`

用途：

- 分享前 10 分钟确认材料、命令、fallback。
- 优先使用 `scripts/share-preflight.sh` 一键生成 refresh、verification、review packet。
- 避免把无关草稿混进本次分享。
- 现场命令失败时切到历史 evidence。

### 8. 复制到新任务

阅读：

- `sinan-best-practices-templates.md`
- `../../../../memory/templates/sinan-task-execution-template.md`

用途：

- 把任务拆分、估时、证据、交接、审批模板复制到新需求。
- 让新任务默认带有 readback、审批边界和交接摘要。

## 分享主线

一句话：

> 从 AI 编码助手，升级到可治理、可审计、可复盘、可持续进化的 AI 工程团队操作系统。

核心结构：

```text
Multica：任务事实源
Multica Loop：组织与治理层
ai-loop：本地执行事实源
Agent Network：能力角色层
Artifacts & Memory：知识沉淀层
```

## 现场推荐流程

1. 用 `09-north-star.md` 开场讲终局。
2. 用 `FUZ-554-one-page.md` 讲案例。
3. 用 `slide-deck.md` 做主 PPT。
4. 用 `speaker-notes.md` 控制讲法。
5. 用 `preflight-checklist.md` 做会前确认。
6. 按 `demo-script.md` 做 5–8 分钟稳定演示。
7. 最后落到下一步：evidence 标准、Multica Loop 状态机、项目记忆。

## 不建议怎么讲

- 不要从脚本开始讲。
- 不要把重点放在“AI 自动完成了多少”。
- 不要现场赌模型 live coding。
- 不要说系统已经全自动闭环。
- 不要忽略人控回写和安全红线。

## 当前交付状态

| 材料 | 状态 | 说明 |
|---|---|---|
| North Star | ready | 终局和路线 |
| One-page | ready | FUZ-554 快速分享 |
| Outline | ready | 正式分享大纲 |
| Demo script | rehearsed | 已彩排并修正注意点 |
| Sinan demo script | ready | 5 分钟司南闭环演示 |
| Slide deck structure | ready | 可转 PPT |
| Slides content | ready | 可直接制作 PPT 的上屏内容 |
| Speaker notes | ready | 可排练讲稿 |
| Preflight checklist | ready | 会前材料、命令、fallback 检查 |
| Best practice templates | ready | 新任务复制模板 |
| Continuous execution guide | ready | 执行/继续/Loop 场景下避免早停 |
| Time estimation calibration guide | ready | 可信计时、估时偏差和下次估时建议 |
| Sinan v1.0 release notes | ready | `sinan-v1.0-release-notes.md` 发布口径和已知限制索引 |
| Sinan capability registry | ready | `config/sinan-capabilities.json` 统一聚合能力入口、证据和验证 |
| Execution time contract | ready | 开工估时、收工真实用时复盘和下次校准 |

## 下一步

- 如果要正式对外/对团队分享：先按 `preflight-checklist.md` 预检，再制作 PPT。
- 如果要内部试讲：按 `speaker-notes.md` + `demo-script.md` 彩排。
- 如果要长时间连续推进：按 `sinan-continuous-execution-guide.md` 跑 timebox、closeout 和 continuation gate。
- 如果要复盘估时偏差：优先读取 closeout 自动生成的 `time-estimation-calibration.md/json`；必要时再按 `time-estimation-calibration-guide.md` 重跑。
- 如果要新增或调整司南能力：先改 `config/sinan-capabilities.json`，再跑 `scripts/sinan-capability-check.sh` 和 `verify-toolchain`。
- 如果要规范每轮执行：按 `../25-execution-time-contract.md` 强制开工估时和收工用时复盘。
- 如果要继续工程推进：优先做 Multica Loop 状态机和 evidence 标准化。
