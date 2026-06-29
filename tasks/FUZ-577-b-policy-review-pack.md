# FUZ-577 BPR-12 技术方案与评审包

## Multica Issue

- Issue: `FUZ-577`
- Title: `BPR-12 技术方案与评审包`
- Project: `B端政策重构`
- Project ID: `318014e7-3d74-4672-ac3b-2c94d6bf143b`
- Current status before this task: `backlog`

## 背景

B端政策重构需要统一技术方案和评审包，作为商品服务范围、渠道客户、渠道客户政策、订单政策、SN政策、权益核销、额度并发控制、凑整、政策看板、数据模型迁移、决策引擎等子任务的实现基线。

本任务承接：

- 飞书 `B政策框架规划`
- 飞书 `【PRD】中国区B渠道客户售后政策系统 - 需求文档`
- 飞书 `【BRD】B渠道政策BRD方案`
- Multica `FUZ-562`：MAF 品类建单政策主数据三级品类查询接口配合方案
- Multica `FUZ-566` ~ `FUZ-577`：B端政策重构拆分 issue
- 本地 Loop 产物：`tasks/b-channel-policy-followup-20260618.md`、`runs/b-channel-policy-followup-20260618-run-dry-run/stage-report.md`

## 本轮目标

1. 将 `FUZ-577` 从 backlog 推进为技术方案主线任务。
2. 形成可进入评审前讨论的 review packet 草稿。
3. 明确 B端政策重构与短期直返项目的边界。
4. 串联 `FUZ-566` ~ `FUZ-576` 的模块关系、依赖和建议里程碑。
5. 输出评审会议议程、待决策清单和下一步执行建议。

## 本期不做

- 不修改业务代码。
- 不写飞书文档。
- 不发版、不部署、不 push Git。
- 不关闭或完成任何 Multica issue。
- 不承诺最终排期，仅给出评审包草案和推进建议。

## 评审包验收标准

- 明确范围、非目标、架构分层、模块拆分、里程碑和风险。
- 覆盖 `FUZ-566` ~ `FUZ-576` 作为子模块输入。
- 标出需要产品 / 后端 / FDE / QA / 运营确认的问题。
- 给出下一轮需要写飞书或更新 Multica 时的审批清单。
- 本地 Loop dry-run 通过。

## 本轮验证命令

```bash
./bin/ai-loop run --repo /home/user/JAVA/ai/ai-loop --task tasks/FUZ-577-b-policy-review-pack.md --dry-run --run-id FUZ-577-b-policy-review-pack-dry-run
```
