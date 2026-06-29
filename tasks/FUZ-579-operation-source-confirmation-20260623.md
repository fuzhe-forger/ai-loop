# FUZ-579：operation 源码优先确认品类建单政策侧待确认项

## 背景

FUZ-579 已完成 sfp-entitlement-config-service 首轮司南分析。用户补充：XMS 系统中的代码主要在 operation，待确认问题应优先走 operation 源码确认，有问题再向业务/MAF/履约确认。

## 目标

只读 `/home/user/JAVA/asp-operation-service` 源码，补充确认 FUZ-579 中以下问题：

1. `thirdCategoryId` 是否可以视为 operation/XMS 里的三级 `brandClassId`。
2. operation 是否已有按 `trademarkId + brandClassIds` 查询品类政策的接口和实现。
3. operation 是否已有 `brandClassId` 入参的政策权益详情查询。
4. 服务前准备/服务规范在 operation 中是否已有配置模型，是否与政策服务同域。
5. 运费/取件/闪送是否在 operation 中已有品类维度能力，哪些可以由政策/config 侧承接，哪些应归履约/物流侧。
6. 对 FUZ-579 首轮 plan 的 P0/P1/P2 拆分做修正。
7. 反思为什么前一次 Multica 查找没有第一时间定位到 FUZ-579。

## 输出要求

- 不修改业务代码。
- 不 push、不 MR、不部署、不访问生产。
- 产出可评审方案草稿，包含源码依据（文件路径 + 行号）、已确认项、仍需业务确认项、下一轮实现 Loop 拆分。
- 本轮不回写 Multica，除非用户后续明确批准。
