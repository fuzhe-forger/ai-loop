# B渠道政策项目继续跟进（2026-06-18）

## 原始请求

用户提供 3 份飞书材料，并要求结合 Multica 里的 B渠道政策项目继续跟进，走 Loop：

- https://mi.feishu.cn/wiki/I0Urw0PAbiPvxokHl6xc6QNdnnh
- https://mi.feishu.cn/docx/IKw0dV30LoaNQHxAhKDcmdyWn0d
- https://mi.feishu.cn/wiki/HLNywEYmhi8kvQk1cOncuf2pnY4

用户后续澄清：Multica 是 ai-loop 大框架下的任务追踪看板，且允许只读查询 Multica 远程、飞书和本地 Loop。

## 已批准边界

- 允许只读查询 Multica 远程服务器。
- 允许只读读取上述飞书文档。
- 允许读取本地 `/home/user/JAVA/ai/ai-loop`。
- 允许生成本地任务文件与 Loop run artifacts。
- 不写 Multica、不写飞书、不 push、不部署、不删数据、不访问生产。

## Multica 远程现状

### 相关项目

- `B端政策重构`
  - Project ID: `318014e7-3d74-4672-ac3b-2c94d6bf143b`
  - Status: `planned`
  - Issue count: project list initially showed `0`, but direct project issue query shows existing `FUZ-562`
  - Description: B端政策体系重构项目，覆盖四层政策体系（商品服务范围 / 客户渠道政策 / 订单政策 / SN政策）、权益核销机制、额度并发控制、凑整功能等。

- `B政策新增直返服务方式`
  - Project ID: `c2f85294-8068-40ad-b1e6-e9dba55c8b34`
  - Status: `planned`
  - Priority: `high`
  - Issue count: `6`
  - Description: 直返服务方式支持项目，关联业务 BRD、工单需求方案和 Meego。

### 相关 issue 状态

- `FUZ-70` 需求分析：`in_review`
  - 评论指出：已新建 `B端政策重构` 项目；直返服务方式项目与 B端政策重构项目独立推进、独立排期。
- `FUZ-71` `[F01] xms-common 新增直返枚举值`：`blocked`
  - 代码与单测已完成；阻塞在 MR #1950 人工合并与后续发版。
- `FUZ-72` `[F02] 服务类型管理页支持直返服务方式（FDE）`：`in_review`
  - 前端改动已完成，分支 `feature/FUZ-72-direct-return-service-way`，提交 `f955b0903`。
  - 验证：`diff --check`、`node --check`、映射脚本通过；`npm build` 因私有 SSH 权限未跑通。
- `FUZ-73` `[F03] 直返渠道表初始化与建表准备`：`in_review`
  - SQL 与测试已完成，分支 `feature/FUZ-73-direct-return-channel-init`，提交 `5f8f6a2765a`。
  - JDK8 下 `mvn -Dmaven.repo.local=/tmp/m2-repository -pl operation-common -Dtest=DirectReturnChannelSqlTest test` 通过。
- `FUZ-74` `[F00] 编写技术方案文档`：`in_review`
  - 技术方案和 FDE 交接文档已产出；等待人工 review / 节后技术评审。
- `FUZ-355` `【B端直返】直返服务方式支持（按会议纪要纠偏）`：`in_review`
  - 2026-06-12 会议纪要已纠偏范围：本期不做直返渠道 CRUD/API/管理页，FDE 仅承接服务类型管理页新增“直返”列。
  - 旧实现分支不能直接沿用。
- `FUZ-562` `MAF 品类建单：政策主数据三级品类查询接口配合方案`：`in_progress`
  - 属于 `B端政策重构` 项目，已沉淀三级品类查询接口配合方案。
  - 下一步需要确认 MAF 接老 `PolicyService` 还是新 `PolicyQueryService`，以及返回字段口径。

## 飞书材料摘要

### `B政策框架规划`

- B政策管理范围包含政策类型、政策内容、服务方式。
- 政策类型覆盖退、换、修、补贴等场景。
- 政策内容包含政策比例、起算时间等规则。
- 服务方式中包含“直返”：生态链商品直返生态链公司。
- 政策管理框架强调四层/多维政策管理，细分场景下政策类型为上级子集，政策内容是时效或比例拓展，下层政策消耗上层政策额度。
- 工作量预估显示政策模块与工单侧工作量较大，不适合混入直返小项目一次性完成。

### `【PRD】中国区B渠道客户售后政策系统 - 需求文档`

- 背景：ToB渠道业务规模 1000 亿+，约占中国区整体业务 51.3%。
- TOP 渠道包括京东、电商直供、授权店等。
- 核心价值：实现 B端政策精细化、灵活化、线上化管理和留痕，降低商家投诉和售后资损。
- 系统设计包含商品服务范围、渠道客户、渠道客户政策、订单政策、SN政策等模块。
- 功能章节覆盖商品服务范围管理、渠道客户管理、渠道客户政策管理、订单政策管理、SN政策管理、政策核销、政策看板等。

### `【BRD】B渠道政策BRD方案`

- 与 PRD 互相引用，是 B渠道政策重构的业务方案来源。
- 需要与 PRD 中的四层政策体系、权益核销、额度控制和凑整能力对齐。

## 当前判断

- `B政策新增直返服务方式` 是当前已拆解且已有执行进度的短期项目。
- `B端政策重构` 是承接 3 份飞书材料的中长期项目，当前已有 `FUZ-562`，但仍缺少完整子 issue 拆分。
- 本轮不应直接写 Multica 或飞书；应先输出可执行的项目推进计划、待拆 issue 列表和下一轮审批清单。

## 本轮目标

生成一个本地 Loop 规划产物，用于继续推进 B渠道政策项目：

1. 区分短期直返项目与中长期 B端政策重构项目。
2. 梳理当前项目状态、阻塞项、待人工决策项。
3. 给出建议创建的 Multica 子 issue 拆分草案。
4. 给出下一轮可以请求用户批准的远程写入清单。
5. 保持只读，不写回 Multica 或飞书。

## 验收标准

- 产出 Loop plan / dry-run artifacts。
- 明确项目分层：直返服务方式 vs B端政策重构。
- 明确每个已有关联 issue 的状态和下一步。
- 给出 B端政策重构建议 issue 拆分，至少覆盖：商品服务范围、渠道客户、渠道客户政策、订单政策、SN政策、权益核销、额度并发控制、凑整、看板/查询、数据模型/迁移。
- 给出远程写入前需要用户批准的操作列表。

## 验证命令

本轮只做本地 Loop 规划验证：

```bash
./bin/ai-loop plan --repo /home/user/JAVA/ai/ai-loop --task tasks/b-channel-policy-followup-20260618.md --dry-run --run-id b-channel-policy-followup-20260618-plan-dry-run
./bin/ai-loop run --repo /home/user/JAVA/ai/ai-loop --task tasks/b-channel-policy-followup-20260618.md --dry-run --run-id b-channel-policy-followup-20260618-run-dry-run
```

## 后续非本轮动作

如用户批准远程写入，可在下一轮执行：

- 在 Multica `B端政策重构` 项目下创建子 issue。
- 更新 `FUZ-70` 或父项目评论，附本轮整理结论。
- 将相关飞书链接、技术方案链接、本地 Loop artifact 链接写入 Multica issue 描述或 metadata。
