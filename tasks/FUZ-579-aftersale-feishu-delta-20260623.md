# FUZ-579：新飞书信息 + aftersale 仓库补充评估

## 输入

- 新飞书：`https://mi.feishu.cn/wiki/GO2yw8ID5i4FTUkMqM7crbOan3d`
- 本地读取：`/tmp/fuz-579-new-feishu-context.md`
- aftersale 仓库：`/home/user/JAVA/services/asp-aftersale-service`
- 既有 FUZ-579 方案：`/home/user/JAVA/sfp-entitlement-config-service/runs/category-order-policy-support-analysis-20260623/FUZ-579-reviewable-solution-operation-confirmed.md`

## 任务

在 FUZ-579 技术方案评估中纳入 aftersale 源码：

1. 评估新飞书中 HHG 直返方案对品类建单政策侧的影响。
2. 核查 `LogisticType/logistic_pre_way`、`ServiceWayEnum/service_way`、`GrouponCreateSrvService`。
3. 核查 aftersale 现有政策消费方式是否偏 SKU/goodsId。
4. 核查 aftersale 是否可持久化 `brandClassId`。
5. 更新 P0/P1/P2 和待确认项。

## 输出

- 补充评估：`/home/user/JAVA/sfp-entitlement-config-service/runs/category-order-policy-support-analysis-20260623/FUZ-579-aftersale-feishu-delta-20260623.md`

## 边界

- 不改业务代码。
- 不 push、不 MR、不部署。
- 不回写 Multica，除非用户确认。
