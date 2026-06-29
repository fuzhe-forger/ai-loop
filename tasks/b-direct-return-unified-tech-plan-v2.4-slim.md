# B端直返服务方式支持技术设计方案 v2.4（精简版）

## 0. 结论先行

<callout emoji="✅" background-color="green" border-color="green">
**最终结论**：`ZF/直返` 可以进入公共 `ServiceWayEnum`，但不能进入默认服务方式集合。历史无参/默认接口不返回 `ZF`；只有带明确 `scene + includeDirectReturn + B端/平台商上下文` 的专项接口才能返回 `ZF`。所有建单入口收到 `serviceWay=ZF` 必须服务端 fail-closed 校验，禁止 `ZF -> JX` 或“非 DJ -> JX”降级。
</callout>

## 1. 本期目标

| 目标 | 说明 |
| --- | --- |
| 公共枚举 | 新增 `ServiceWayEnum.ZF(6, "直返")` |
| 默认隔离 | 老接口、C端、客服普通建单、OpenAPI、第三方默认不返回/不接受 `ZF` |
| 显式获取 | 只有专项 scene + 上下文 + 权限满足时返回 `ZF` |
| B端配置 | B端权益配置、导入、导出支持 `ZF=6` |
| 建单兜底 | 平台商专项直返建单必须通过可用性校验 |

## 2. 本期范围

### 2.1 包含

- `xms-common` 新增 `ServiceWayEnum.ZF=6` 和 i18n。
- `asp-operation-service` 默认服务方式接口过滤 `ZF`。
- `asp-operation-service` 新增显式服务方式查询和直返可用性校验。
- `asp-aftersale-service` 默认枚举接口过滤 `ZF`，平台商按真实服务方式分组。
- `asp-b2b-service` 商品权益导入、导出、页面配置支持 `ZF=6`。
- OpenAPI/第三方普通入口显式拒绝 `ZF`。

### 2.2 不包含

- 不做 C端直返开放。
- 不做 OpenAPI/第三方直返开放。
- 不做 B端政策重构。
- 不做直返渠道完整 CRUD/API/管理页。
- 不做工单履约完整流转改造。

## 3. B端权益与 C端权益边界

| 维度 | C端/普通售后 | B端直返 |
| --- | --- | --- |
| 默认展示 `ZF` | 否 | 否 |
| 显式获取 `ZF` | 否 | 是，仅专项场景 |
| 老 `getGoodsRight(goodsId,type)` 授权 `ZF` | 否 | 否 |
| 建单 `ZF` | 拒绝 | 专项校验通过后允许 |
| 判断依据 | 现有 C端/普通售后权益 | B客户/平台商上下文 + 商品权益 + 直返渠道/仓/履约 |

## 4. 场景矩阵

| 场景 | 默认返回 ZF | 显式返回 ZF | 允许建单 ZF | 策略 |
| --- | --- | --- | --- | --- |
| 历史无参全量枚举 | 否 | 否 | 不适用 | 老接口过滤 |
| C端权益查询 | 否 | 否 | 否 | 传入拒绝 |
| 客服普通建单 | 否 | 否 | 否 | 传入拒绝 |
| OpenAPI/第三方普通入口 | 否 | 否 | 否 | 传入拒绝 |
| B端商品权益配置 | 否 | 是 | 不适用 | 专项 scene 展示/保存 |
| 平台商直返专项建单 | 否 | 是 | 是 | 可用性校验后允许 |
| 管理后台超级配置 | 否 | 是 | 不适用 | 权限点控制 |

## 5. 关键代码事实

| 事实 | 影响 | 结论 |
| --- | --- | --- |
| `ServiceWayEnum.values()` 会遍历全部枚举 | 新增 `ZF` 后全量接口会自然暴露 | 默认接口必须过滤 |
| `getGoodsRight(goodsId,type)` 只有商品和服务类型 | 无法识别 B/C 场景、组织、客户、渠道 | 不承担直返授权 |
| 平台商存在非 `DJ` 即 `JX` 逻辑 | `ZF` 可能被误归为寄修 | 必须按真实 serviceWay 分组 |
| B2B 导入当前主要支持到家/寄修 | “直返”可能导入失败或无法转换 | 补 `直返 -> 6` |

## 6. 接口设计

### 6.1 老接口兼容

以下接口保持签名不变，默认过滤 `ZF`：

| 仓库 | 方法 |
| --- | --- |
| `asp-operation-service` | `BaseInfoManageService.getAllServiceWay()` |
| `asp-operation-service` | `BaseDictService.getServiceWayVoList()` |
| `asp-operation-service` | `BaseServiceWayService.getAllServiceWayVoList()` |
| `asp-aftersale-service` | `SrvEnumDubboService.getAllServiceWay()` |
| `asp-aftersale-service` | `CommonApiService.getAllServiceWay()` |
| `asp-aftersale-service` | `SrvServicingApiService.getAllServiceWay()` |

### 6.2 显式服务方式查询

建议新增：

    Response<ListDTO<SelectDTO>> getServiceWays(ServiceWayQueryParam param);

关键入参：

| 字段 | 说明 |
| --- | --- |
| `scene` | 调用场景，如 `BIZ_CUSTOMER_CONFIG`、`PLATFORM_DIRECT_RETURN` |
| `includeDirectReturn` | 请求意图，不代表授权 |
| `orgId/sapCode/customerCode` | B端/平台商上下文 |
| `goodsId/serviceType` | 商品和服务类型上下文 |
| `channelId/orderFrom/operatorMiliao` | 渠道、来源、操作人上下文 |

返回规则：

    param 为空 -> 默认不返回 ZF
    includeDirectReturn != true -> 默认不返回 ZF
    scene 非白名单 -> 默认不返回 ZF
    上下文缺失 -> 默认不返回 ZF
    权限/配置不满足 -> 默认不返回 ZF
    全部满足 -> 返回含 ZF 的服务方式列表

### 6.3 直返可用性校验

建议新增：

    Response<DirectReturnAvailabilityDTO> checkDirectReturnAvailable(DirectReturnAvailabilityParam param);

响应字段：

| 字段 | 说明 |
| --- | --- |
| `available` | 是否可直返 |
| `reasonCode/reasonMessage` | 不可用原因 |
| `directReturnChannelCode/directReturnChannelName` | 直返渠道 |
| `warehouseOrgId/warehouseOrgName` | 直返仓/核销仓 |

核心失败码：

| reasonCode | 含义 |
| --- | --- |
| DIRECT_RETURN_DISABLED | 总开关关闭 |
| SCENE_NOT_ALLOWED | 场景不允许 |
| PERMISSION_DENIED | 无权限 |
| REQUIRED_CONTEXT_MISSING | 上下文缺失 |
| GOODS_RIGHT_NOT_CONFIGURED | 商品未配置直返权益 |
| CHANNEL_NOT_CONFIGURED | 直返渠道未配置 |
| WAREHOUSE_NOT_FOUND | 未找到直返仓/核销仓 |
| FULFILLMENT_NOT_READY | 履约链路未就绪 |

## 7. 数据与配置

| 对象 | 策略 |
| --- | --- |
| 公共枚举 | 新增 `ZF(6, "直返", "XmsCommon.ServiceWayEnum.ZF")` |
| i18n | `XmsCommon.ServiceWayEnum.ZF=直返` |
| 字典 | `base_service_way` 可初始化 `6/直返`，但默认查询仍过滤 |
| 服务类型关系 | 只允许直返相关服务类型/页面使用 |
| 直返渠道表 | 空表优先，首批数据由产品确认后初始化 |
| 开关 | 默认关闭，灰度开启，异常可关闭专项直返能力 |

## 8. 任务拆分

| 任务 | 仓库 | 内容 |
| --- | --- | --- |
| T1 | `xms-common` | 新增 `ServiceWayEnum.ZF=6` 与 i18n |
| T2 | `asp-operation-service` | 默认服务方式列表过滤 `ZF` |
| T3 | `asp-operation-service` | 新增场景化服务方式查询 |
| T4 | `asp-operation-service` | 新增直返可用性校验 |
| T5 | `asp-operation-service` | `IServiceWayAbilityFactory` 显式处理 `ZF` |
| T6 | `asp-aftersale-service` | 老全量服务方式接口默认过滤 `ZF` |
| T7 | `asp-aftersale-service` | 平台商按真实服务方式分组，`ZF` 单独分组 |
| T8 | `asp-aftersale-service` | 建单入口收到 `ZF` 强校验 |
| T9 | `asp-b2b-service` | B端权益导入/导出/页面支持 `ZF=6` |
| T10 | OpenAPI/第三方入口 | 默认拒绝 `ZF`，不降级、不吞错 |

## 9. 发版顺序

1. 保护性过滤和建单 fail-closed 先上。
2. 发布公共枚举 `ZF=6`。
3. 初始化字典、关系和渠道表。
4. 开放 B端权益配置和 B2B 导入/导出。
5. 联调平台商专项建单、履约/备件/质检退回。
6. 回归 C端、客服普通入口、OpenAPI、第三方普通入口。

## 10. 验收门禁

### 10.1 默认隔离

- [ ] 老服务方式列表接口不返回 `ZF`。
- [ ] C端权益查询不返回 `ZF`。
- [ ] 客服普通建单不展示/不接受 `ZF`。
- [ ] OpenAPI/第三方普通入口传 `ZF` 被拒绝。

### 10.2 显式获取

- [ ] `includeDirectReturn=false` 不返回 `ZF`。
- [ ] 非白名单 `scene` 不返回 `ZF`。
- [ ] 缺少上下文不返回 `ZF`。
- [ ] B端配置/平台商专项 scene 命中权限和配置后返回 `ZF`。

### 10.3 建单兜底

- [ ] 无商品权益配置建单失败。
- [ ] 无渠道/仓配置建单失败。
- [ ] 履约未就绪建单失败。
- [ ] `ZF` 不降级为 `JX`。
- [ ] 命中配置后专项建单成功。

### 10.4 B2B 配置

- [ ] 新增/编辑 B端商品权益可选择“直返”。
- [ ] 导入“直返”可识别为 `serviceWay=6`。
- [ ] 导出 `serviceWay=6` 展示为“直返”。
- [ ] 历史到家/寄修导入导出不受影响。

## 11. 权限、安全与观测

| 项 | 要求 |
| --- | --- |
| 权限 | B端配置、平台商专项建单、管理后台超级配置需要权限或白名单控制 |
| 审计 | 记录直返配置变更、导入结果、专项建单可用性校验结果 |
| 日志 | 记录 `scene`、`includeDirectReturn`、操作人、商品、客户、reasonCode |
| 监控 | 默认接口返回 `ZF` 次数应为 0；OpenAPI/第三方误传 `ZF` 应监控 |
| 告警 | 默认接口出现 `ZF`、直返可用性失败突增、履约未就绪突增需告警 |

## 12. 测试方案

| 类型 | 用例 |
| --- | --- |
| 冒烟 | 老接口不返回 `ZF`；B端配置 scene 返回 `ZF`；普通入口传 `ZF` 被拒绝 |
| 回归 | C端权益、客服普通建单、OpenAPI、第三方、B2B 导入导出、平台商专项建单 |
| 异常 | 缺上下文、无权限、无商品权益、无渠道/仓、履约未就绪 |
| 回滚 | 关闭 `direct.return.enabled` 后专项能力不可用，默认入口仍不展示 `ZF` |

测试负责人仍需项目侧确认；未确认前不进入正式提测。

## 13. 风险与待确认

| 编号 | 问题 | 建议结论 | 责任方 |
| --- | --- | --- | --- |
| Q1 | `ZF` 枚举 id | 固定为 `6` | xms-common 维护方 |
| Q2 | 老 `getGoodsRight(goodsId,type)` 是否改签名 | 不改，新增可用性接口 | operation 后端 |
| Q3 | 直返渠道是否绑定商品/客户/组织 | 至少接口预留，落表看产品范围 | 产品/后端 |
| Q4 | OpenAPI/第三方是否开放直返 | 本期不开放 | 产品/开放平台 |
| Q5 | 平台商专项建单入口如何识别 | `scene=PLATFORM_DIRECT_RETURN` + 来源/权限/上下文 | 工单/平台商 |
| Q6 | 履约寻仓失败是否允许转寄修 | 不允许自动转，必须失败或人工处理 | 产品/履约/工单 |
| Q7 | 测试负责人是谁 | 必须明确 | 项目负责人/测试 |
| Q8 | 首批直返渠道数据是否存在 | 未确认则只发布空表 | 产品/业务 |

## 14. 不建议方案

| 方案 | 风险 |
| --- | --- |
| 只在公共枚举新增 `ZF` | 全量接口自然暴露，影响 C端/客服/OpenAPI/第三方 |
| 只在老接口加 `includeDirectReturn` | 缺少 scene 和上下文，无法授权 |
| 只靠前端隐藏 | 接口可绕过，建单仍可能传 `ZF` |
| 把 `ZF` 当作 `JX` 特例 | 履约、质检退回、渠道/仓逻辑不同，风险高 |

## 15. 关联资料

| 类型 | 链接/路径 |
| --- | --- |
| BRD | `https://mi.feishu.cn/wiki/DYh9wRto6ijvCZkrYL2c0XJknmf` |
| 需求文档 | `https://mi.feishu.cn/docx/OlDhdCGD9oA7vhx64gwcQYXzn3f` |
| 会议纪要/补充方案 | `https://mi.feishu.cn/docx/UbfBdWpdwoZRTZxXyvic8sCsnQb` |
| 本地精简稿 | `JAVA/ai/ai-loop/tasks/b-direct-return-unified-tech-plan-v2.4-slim.md` |
