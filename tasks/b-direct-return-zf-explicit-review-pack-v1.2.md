# B端直返 ZF 显式获取与场景隔离：评审包 v1.2

## 1. 本次评审要拍板的结论

| 编号 | 结论 | 建议 |
|-|-|-|
| C1 | `ZF/直返` 是否进入公共枚举 | 进入，使用 `ServiceWayEnum.ZF(6, "直返")` |
| C2 | 老全量服务方式接口是否返回 `ZF` | 不返回，默认过滤 |
| C3 | 老 `getGoodsRight(goodsId, serviceType)` 是否承担直返授权 | 不承担，因缺少 B/C 场景和组织/客户上下文 |
| C4 | 是否新增直返专项查询 | 是，新增 `getServiceWays(ServiceWayQueryParam)` 或更保守的 `getDirectReturnServiceWays(...)` |
| C5 | 是否新增直返可用性校验 | 是，新增 `checkDirectReturnAvailable(DirectReturnAvailabilityParam)` |
| C6 | OpenAPI/第三方普通入口是否开放直返 | 本期不开放，默认 fail-closed |
| C7 | 平台商直返是否允许建单 | 仅专项 scene + 权限 + 商品权益 + 渠道/仓/履约就绪后允许 |
| C8 | `ZF` 是否可降级为 `JX` | 禁止 |

## 2. 为什么不能只加公共枚举

新增公共枚举后，当前多处代码使用：

```java
Arrays.stream(ServiceWayEnum.values())
    .filter(serviceWayEnum -> serviceWayEnum.getId() > 0)
```

会导致 `ZF=6` 被所有默认入口自然返回，影响：

- C端权益判断。
- 客服普通建单。
- OpenAPI/第三方普通建单。
- 历史下拉/枚举消费者。

所以公共枚举新增必须配套默认过滤和专项查询。

## 3. B端权益和 C端权益边界

| 项 | C端/普通售后 | B端直返 |
|-|-|-|
| 默认展示 `ZF` | 否 | 否 |
| 显式获取 `ZF` | 否 | 是 |
| 建单 `ZF` | 拒绝 | 专项校验通过后允许 |
| 判断上下文 | 普通权益上下文 | `scene + orgId/sapCode/customerCode/goodsId/serviceType/channelId` |
| 失败策略 | fail-closed | fail-closed |

关键口径：`ZF` 是公共枚举，不是全局可用服务方式。

## 4. 接口方案

### 4.1 服务方式可见性查询

```java
Response<ListDTO<SelectDTO>> getServiceWays(ServiceWayQueryParam param);
```

必要字段：

```text
scene
includeDirectReturn
orgId/sapCode/customerCode
goodsId/serviceType
channelId/orderFrom
operatorMiliao
```

白名单 scene：

```text
BIZ_CUSTOMER_CONFIG
PLATFORM_DIRECT_RETURN
DIRECT_RETURN_CHANNEL
ADMIN_CONFIG
```

### 4.2 直返可用性校验

```java
Response<DirectReturnAvailabilityDTO> checkDirectReturnAvailable(DirectReturnAvailabilityParam param);
```

返回：

```text
available
reasonCode
reasonMessage
directReturnChannelCode/directReturnChannelName
warehouseOrgId/warehouseOrgName
```

核心失败码：

| reasonCode | 含义 |
|-|-|
| DIRECT_RETURN_DISABLED | 总开关关闭 |
| SCENE_NOT_ALLOWED | 场景不允许 |
| PERMISSION_DENIED | 无权限 |
| REQUIRED_CONTEXT_MISSING | 上下文缺失 |
| GOODS_RIGHT_NOT_CONFIGURED | 商品未配置直返权益 |
| CHANNEL_NOT_CONFIGURED | 直返渠道未配置 |
| WAREHOUSE_NOT_FOUND | 核销仓/直返仓未找到 |
| FULFILLMENT_NOT_READY | 履约链路未就绪 |

## 5. 必改点清单

| 任务 | 仓库 | 目的 |
|-|-|-|
| T1 公共枚举 | `xms-common` | 新增 `ZF=6` |
| T2 operation 默认过滤 | `asp-operation-service` | 老接口不暴露 `ZF` |
| T3 operation 专项查询 | `asp-operation-service` | 显式 scene 获取 `ZF` |
| T4 operation 可用性校验 | `asp-operation-service` | 判断商品/客户/渠道/仓是否可直返 |
| T5 operation 工厂保护 | `asp-operation-service` | `ZF` 不进空异常/不转 `JX` |
| T6 aftersale 默认过滤 | `asp-aftersale-service` | 普通售后不暴露 `ZF` |
| T7 aftersale 平台商分组 | `asp-aftersale-service` | `ZF` 单独分组，不归 `JX` |
| T8 aftersale 建单强校验 | `asp-aftersale-service` | 传 `ZF` 必须专项校验 |
| T9 B2B 配置支持 | `asp-b2b-service` | 导入/导出/页面支持直返 |
| T10 OpenAPI/第三方保护 | 实际入口仓库 | 默认拒绝 `ZF` |

## 6. 发版顺序

1. 保护性过滤和 fail-closed 先上。
2. 公共枚举 `ZF=6` 发版。
3. B端权益配置开放。
4. 直返可用性接口联调。
5. 平台商专项建单开放。
6. C端/客服/OpenAPI/第三方回归。

## 7. 验收门禁

### 默认不可见

- [ ] 所有老服务方式列表接口不返回 `ZF`。
- [ ] C端权益不返回 `ZF`。
- [ ] 客服普通建单不展示 `ZF`。
- [ ] OpenAPI/第三方普通入口不接受 `ZF`。

### 显式可见

- [ ] `includeDirectReturn=false` 不返回 `ZF`。
- [ ] 非白名单 `scene` 不返回 `ZF`。
- [ ] 缺上下文不返回 `ZF`。
- [ ] B端配置/平台商专项 scene 命中权限和配置后返回 `ZF`。

### 建单兜底

- [ ] 无商品权益配置建单失败。
- [ ] 无渠道/仓配置建单失败。
- [ ] 履约未就绪建单失败。
- [ ] `ZF` 不降级为 `JX`。
- [ ] 命中配置后专项建单成功。

## 8. 待评审确认

| 问题 | 建议结论 |
|-|-|
| `ZF` id | 固定为 `6` |
| 老 `getGoodsRight` 是否改签名 | 不改 |
| 直返渠道本期是否绑定商品/客户/组织 | 至少接口预留，落表范围需产品确认 |
| OpenAPI/第三方是否开放 | 本期不开放 |
| 履约寻仓失败能否转寄修 | 不允许自动转寄修 |
| 质检退回依赖未就绪能否上线 | 必须有临时方案或开关兜底 |
