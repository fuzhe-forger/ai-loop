# sfp-entitlement-config-service 错误日志 Top 3 治理 Loop 计划

## Multica 追踪

- Issue：`FUZ-565`
- 项目：`政策权益稳定性治理`
- 约束：代码改动、飞书回填、MR、部署前均需单独确认。
- 当前阶段：本地 Loop 初始化与 intake gate。

## 背景

飞书多维表《错误日志分析》中，按治理人 `傅喆 / fuzhe1@xiaomi.com` 筛选到 29 条记录，总错误次数 914,774。所有记录集中在 `sfp-entitlement-config-service`。

Top 3 点位合计约 97%，优先治理：

| 优先级 | record_id | 点位ID | 次数 | 占比 | 异常/样例 |
|---|---|---|---:|---:|---|
| P0 | recvm855D4CAcm | 0003-sfp-entitlement-config-service-1afbda9ccf1d95bc | 682361 | 74.59% | 当前无设备三包时间 / getPolicyByGoodsIdAndSaleChannel |
| P1 | recvm855D4jLyo | 0010-sfp-entitlement-config-service-146eca415f2c7e15 | 148904 | 16.28% | getPolicyByGoodsIdAndSaleChannel 业务异常 |
| P2 | recvm855D4mtxe | 0017-sfp-entitlement-config-service-38866da3f0c82eaf | 56258 | 6.15% | 找不到有效的政策 / getComp |

## 目标

将飞书表中治理人属于傅喆的 Top 3 错误点位纳入 Loop 流程，完成影响面受控的治理计划：先定位根因和最小代码影响面，再决定是否进入代码修改阶段。

## 验收标准

- 明确 Top 3 点位对应代码入口、调用链、日志输出位置。
- 明确每个点位的根因假设、修复策略、兼容风险和回滚策略。
- 只给出针对 Top 3 的治理建议，不扩散处理其余 26 条。
- 后续如需代码改动，必须单独进入 implementation Loop，并列出验证命令。
- 后续如需飞书回填，必须先生成 dry-run 变更清单，仅允许更新 `治理状态`、`源码路径`、处理结论类字段，不改原始数据。

## 边界与风险

- 不修改飞书表内其他治理人的记录。
- 不改 `点位ID`、`次数`、`点位`、`完整样例`、`样例首行` 等原始数据字段。
- 不在本阶段修改业务代码、提交 Git、创建 MR、部署或访问生产。
- 不把 `FUZ-560` / `FUZ-562` 等其他业务任务混入本治理任务，除非后续确认同属一个 Multica issue。
- 正式执行前必须绑定 Multica issue；没有 issue 时只能停留在本地计划阶段。

## 目标仓库

- 业务仓库：`/home/user/JAVA/sfp-entitlement-config-service`
- 编排仓库：`/home/user/JAVA/ai/ai-loop`

## 初始执行计划

1. 已创建并绑定 Multica issue：`FUZ-565`。
2. 对 Top 3 点位做代码入口和调用链定位。
3. 输出影响面、修复策略和验证命令。
4. 评审通过后再进入代码修改 Loop。
5. 修复验证后生成飞书回填 dry-run。
