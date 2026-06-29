# B端直返 ZF 显式获取与场景隔离：可评审执行方案 v1.1

## 0. 本轮范围

本轮只细化方案，不进入开发实现。

- 不改业务仓库代码。
- 不跑真实 `ai-loop run`。
- 不提交 Git、不 push、不建 MR。
- 仅产出方案、拆解、验收清单、评审门禁。

## 1. 方案目标

`ServiceWayEnum.ZF(6, "直返")` 是公共枚举值，但不能作为默认服务方式在全系统自然暴露。本方案目标是：

1. 公共枚举允许定义 `ZF`。
2. 默认查询接口不返回 `ZF`。
3. 只有显式直返场景可获取 `ZF`。
4. 展示、可用性、建单三层分别校验。
5. 老消费者不会被动收到 `ZF`。
6. C端权益和普通售后链路不受影响。
7. B端/平台商直返链路具备清晰开发任务和验收标准。

## 2. 最终设计原则

### 2.1 默认安全

所有历史无参接口、默认下拉、普通 C端/客服/OpenAPI/小程序入口都不返回 `ZF`。

默认可见集合：

```text
DJ 到家
DD 到店
JX 寄修
CJ 厂家售后
XN 虚拟服务受理
```

直返 `ZF` 不属于默认集合。

### 2.2 显式获取

调用方必须同时表达：

1. 我需要直返：`includeDirectReturn=true`。
2. 我是什么场景：`scene=BIZ_CUSTOMER_CONFIG` / `PLATFORM_DIRECT_RETURN` / `DIRECT_RETURN_CHANNEL`。
3. 我具备上下文：`orgId/sapCode/customerCode/goodsId/serviceType` 至少按场景提供。

### 2.3 服务端授权

`includeDirectReturn=true` 不是授权，只是请求意图。服务端必须再次判断：

- scene 是否允许。
- 用户/菜单/角色是否允许。
- org/sap/customer 是否是 B端/平台商主体。
- 商品权益是否配置直返。
- 直返全局开关是否打开。

### 2.4 建单兜底

前端展示不能作为安全边界。所有建单入口遇到 `serviceWay=ZF` 都必须强校验。

失败策略：

```text
未命中配置 -> 失败
依赖未就绪 -> 失败
场景不允许 -> 失败
权限不足 -> 失败
未知服务方式 -> 失败
```

禁止策略：

```text
ZF -> JX 降级
非 DJ -> JX 默认归类
前端过滤替代后端校验
普通 OpenAPI 默认接受 ZF
```

## 3. 场景矩阵

| 场景 | 现有入参是否足够 | 默认返回 ZF | 显式返回 ZF | 建单允许 ZF | 说明 |
| --- | --- | --- | --- | --- | --- |
| 无参全量枚举 | 否 | 否 | 否 | 不适用 | 没有上下文，必须过滤 |
| C端权益配置 | 部分 | 否 | 否 | 否 | 不纳入本期直返 |
| 客服普通建单 | 部分 | 否 | 否 | 否 | 避免客服误选 |
| 小程序/官网普通入口 | 部分 | 否 | 否 | 否 | 本期不开放 |
| OpenAPI 普通建单 | 部分 | 否 | 否 | 否 | 默认 fail-closed |
| 第三方普通建单 | 部分 | 否 | 否 | 否 | 默认 fail-closed |
| B端商品权益配置 | 是 | 否 | 是 | 不适用 | 可展示和配置 ZF |
| B端直返渠道管理 | 是 | 否 | 是 | 不适用 | 专项页面可展示 |
| 平台商直返专项建单 | 是 | 否 | 是 | 是 | 必须强校验 |
| 管理后台超级配置 | 是 | 否 | 是 | 不适用 | 需要权限点 |

## 4. 分层能力设计

### 4.1 展示可见性服务

职责：返回页面/接口可展示的服务方式列表。

建议接口：

```java
Response<ListDTO<SelectDTO>> getServiceWays(ServiceWayQueryParam param);
```

请求模型：

```java
public class ServiceWayQueryParam implements Serializable {
    private ServiceWaySceneEnum scene;
    private Boolean includeDirectReturn = Boolean.FALSE;
    private String orgId;
    private String sapCode;
    private String customerCode;
    private String goodsId;
    private ServiceTypeEnum serviceType;
    private Integer orderFrom;
    private Integer channelId;
    private Map<String, String> orderExt;
    private Long operatorMiliao;
}
```

场景枚举：

```java
public enum ServiceWaySceneEnum {
    DEFAULT,
    C_CUSTOMER,
    CUSTOMER_SERVICE_CREATE,
    OPEN_API,
    MINI_APP,
    THIRD_PARTY,
    BIZ_CUSTOMER_CONFIG,
    PLATFORM_DIRECT_RETURN,
    DIRECT_RETURN_CHANNEL,
    ADMIN_CONFIG
}
```

返回规则：

```java
if (param == null) return defaultWaysWithoutZf;
if (!Boolean.TRUE.equals(param.getIncludeDirectReturn())) return defaultWaysWithoutZf;
if (!DIRECT_RETURN_VISIBLE_SCENES.contains(param.getScene())) return defaultWaysWithoutZf;
if (!hasDirectReturnPermission(param)) return defaultWaysWithoutZf;
return defaultWaysWithZf;
```

### 4.2 业务可用性服务

职责：判断某个机构/客户/商品/服务类型是否能使用直返。

建议接口：

```java
Response<DirectReturnAvailabilityDTO> checkDirectReturnAvailable(DirectReturnAvailabilityParam param);
```

请求模型：

```java
public class DirectReturnAvailabilityParam implements Serializable {
    private String orgId;
    private String sapCode;
    private String customerCode;
    private String goodsId;
    private ServiceTypeEnum serviceType;
    private String sn;
    private Integer orderFrom;
    private Integer channelId;
    private ServiceWaySceneEnum scene;
}
```

响应模型：

```java
public class DirectReturnAvailabilityDTO implements Serializable {
    private Boolean available;
    private String reasonCode;
    private String reasonMessage;
    private String directReturnChannelCode;
    private String directReturnChannelName;
    private String warehouseOrgId;
    private String warehouseOrgName;
}
```

失败原因建议：

| reasonCode | 含义 |
| --- | --- |
| DIRECT_RETURN_DISABLED | 直返总开关关闭 |
| SCENE_NOT_ALLOWED | 当前场景不允许直返 |
| PERMISSION_DENIED | 无直返权限 |
| ORG_NOT_ALLOWED | 当前机构不允许直返 |
| SAP_NOT_ALLOWED | 当前 B客户不允许直返 |
| GOODS_RIGHT_NOT_CONFIGURED | 商品未配置直返权益 |
| SERVICE_TYPE_NOT_SUPPORTED | 服务类型不支持直返 |
| CHANNEL_NOT_CONFIGURED | 直返渠道未配置 |
| WAREHOUSE_NOT_FOUND | 未找到核销仓/直返仓 |
| FULFILLMENT_NOT_READY | 履约链路未就绪 |

### 4.3 建单校验服务

职责：在工单创建/更新/导入/批量建单时拦截 `ZF`。

建议统一方法：

```java
void assertDirectReturnCreatable(CreateDirectReturnContext context);
```

上下文：

```java
public class CreateDirectReturnContext {
    private String orgId;
    private String acceptOrgId;
    private String sapCode;
    private String customerCode;
    private String goodsId;
    private ServiceTypeEnum serviceType;
    private ServiceWayEnum serviceWay;
    private String businessType;
    private String createFrom;
    private Integer orderFrom;
    private Integer channelId;
    private Long operatorMiliao;
}
```

校验触发条件：

```java
if (context.getServiceWay() == ServiceWayEnum.ZF) {
    assertDirectReturnCreatable(context);
}
```

## 5. 接口兼容策略

### 5.1 老接口不变，但默认过滤

以下接口保留签名，行为变为“永远不返回 ZF”：

- `SrvEnumDubboService.getAllServiceWay()`
- `CommonApiService.getAllServiceWay()`
- `SrvServicingApiService.getAllServiceWay()`
- `BaseInfoManageService.getAllServiceWay()`
- `BaseDictService.getServiceWayVoList()`
- `BaseServiceWayService.getAllServiceWayVoList()`

### 5.2 新接口只给直返场景使用

新增接口不得替换老接口默认调用点，必须由直返专项页面显式调用。

建议命名：

```java
getServiceWays(ServiceWayQueryParam param)
getDirectReturnServiceWays(ServiceWayQueryParam param) // 更保守，可选
```

如果担心 Dubbo 兼容，优先新增方法而不是改老方法签名。

### 5.3 不建议方案

不建议只新增：

```java
getAllServiceWay(Boolean includeDirectReturn)
```

原因：缺少 scene、orgId、goodsId、权限上下文，容易被误用。

## 6. 数据与配置策略

### 6.1 xms-common 枚举

新增：

```java
ZF(6, "直返", "XmsCommon.ServiceWayEnum.ZF")
```

### 6.2 base_service_way 字典

推荐策略：

1. 可以新增 `base_service_way=6/直返`。
2. 不依赖 `enable=N` 来控制默认可见性，因为有些代码走枚举、有些代码走字典。
3. 必须在服务层统一过滤 `ZF`，不能只靠字典 enable。
4. 服务类型关系 `base_service_type_way` 是否配置 `ZF`，只允许直返相关服务类型/页面使用。

### 6.3 开关配置

建议默认值：

```text
direct.return.enabled=false
direct.return.visible.scenes=BIZ_CUSTOMER_CONFIG,PLATFORM_DIRECT_RETURN,DIRECT_RETURN_CHANNEL
direct.return.allowed.orgs=
direct.return.allowed.sapCodes=
direct.return.allowed.goodsIds=
direct.return.openapi.enabled=false
direct.return.thirdparty.enabled=false
direct.return.force.failClosed=true
```

## 7. 仓库级改造清单

### 7.1 xms-common

目标：定义枚举，不承载业务过滤。

文件：

- `xms-common/src/main/java/com/mi/xms/common/constant/ServiceWayEnum.java`
- `xms-common/src/test/java/com/mi/xms/common/constant/ServiceWayEnumTest.java`
- i18n 资源文件

验收：

- `ServiceWayEnum.ZF.getId() == 6`
- `getById(6) == ZF`
- `getByName("ZF") == ZF`
- 不影响已有枚举 ID。

### 7.2 asp-operation-service

目标：默认过滤和显式查询的主实现。

重点文件：

- `operation-manage-service/src/main/java/com/mi/xms/operation/mng/base/impl/BaseInfoManageServiceImpl.java`
- `operation-dao-service/src/main/java/com/mi/xms/operation/base/impl/BaseDictServiceImpl.java`
- `operation-dao-service/src/main/java/com/mi/xms/operation/policy/impl/BaseServiceWayServiceImpl.java`
- `operation-manage-service/src/main/java/com/mi/xms/operation/mng/policy/impl/ServiceTypeManageServiceImpl.java`
- `operation-manage-service/src/main/java/com/mi/xms/operation/mng/policy/impl/RightManageServiceImpl.java`
- `operation-biz/src/main/java/com/mi/xms/operation/biz/organization/org/ability/serviceway/factory/IServiceWayAbilityFactory.java`
- `operation-api/src/main/java/com/mi/xms/operation/api/service/businesscustomer/BizCustomerService.java`

必须完成：

1. 所有默认服务方式列表过滤 `ZF`。
2. 新增显式查询模型和方法。
3. B端直返可用性校验接口设计落地。
4. `IServiceWayAbilityFactory` 不允许 `ZF` 进入 default 空异常。
5. `BizCustomerService.getGoodsRight(goodsId, serviceType)` 不承担调用方授权，新增可用性校验接口。

### 7.3 asp-aftersale-service

目标：默认不暴露，建单强校验，平台商逻辑修复。

重点文件：

- `maf-service-provider/src/main/java/com/mi/maf/dubbo/service/srv/impl/SrvEnumDubboServiceImpl.java`
- `maf-api/src/main/java/com/mi/maf/api/service/CommonApiService.java`
- `maf-api/src/main/java/com/mi/maf/api/service/SrvServicingApiService.java`
- `maf-service-provider/src/main/java/com/mi/maf/dubbo/service/srv/impl/SrvListDubboServiceImpl.java`
- `maf-srv-aftersale/src/main/java/com/mi/maf/srv/aftersale/manager/platform/PlatformPolicyBaseManager.java`
- `maf-srv-aftersale/src/main/java/com/mi/maf/srv/aftersale/service/rule/PlatformRuleService.java`
- 建单相关转换/校验入口：`CreateReq`、`ThirdServiceCreateReq`、`SrvCreateServiceOpenApiParam` 对应 service/processor。

必须完成：

1. 老全量接口默认过滤 `ZF`。
2. 平台商 `isToHomeGoodsId` 明确处理 `ZF`。
3. 平台商 `goodsIdsGroupingBySrvWay` 按真实服务方式分组，不再非 `DJ` 即 `JX`。
4. 建单传 `ZF` 统一调用 direct return availability。
5. OpenAPI/第三方默认拒绝 `ZF`。

### 7.4 asp-b2b-service

目标：B端权益配置显式支持直返。

重点文件：

- `asp-b2b-web/src/main/java/com/xiaomi/xms/b2b/web/freemarker/controller/BizCustGoodsRightController.java`
- 对应 freemarker 页面/导入模板/导出模板

必须完成：

1. 导入校验支持“直返”。
2. desc 与 id 转换支持 `ZF=6`。
3. 导出支持 `6 -> 直返`。
4. 页面下拉只在直返配置入口显式展示。

### 7.5 asp-third-service / asp-open-api / asp-platform-web

目标：普通入口默认拒绝或过滤。

必须完成：

1. `ServiceWayEnum` 到业务类型映射显式处理 `ZF`。
2. 默认不展示 `ZF`。
3. 收到 `ZF` 时 fail-closed，不映射到 `JX`。

## 8. 发版顺序

### Step 1：保护性改造先行

先改所有默认接口过滤和 fail-closed 逻辑，但不开放直返。

输出：

- 老接口不返回 `ZF`。
- `ZF` 不会被归为 `JX`。
- 普通建单传 `ZF` 会失败。

### Step 2：xms-common 发版

新增 `ZF`，provider/consumer 升级依赖。

门禁：所有对外默认接口已经过滤。

### Step 3：显式查询接口发版

发布 `ServiceWayQueryParam` / `ServiceWaySceneEnum` / `getServiceWays(param)`。

门禁：只有白名单 scene 能返回 `ZF`。

### Step 4：B端权益配置开放

B2B/operation 管理端支持配置直返。

门禁：只在 B端直返入口展示。

### Step 5：平台商直返建单开放

平台商直返专项入口接入可用性校验。

门禁：未配置不可建单，配置命中才进入直返链路。

### Step 6：联调履约/备件/质检退回

在联调环境验证直返完整链路。

门禁：质检退回和取消链路未完成前，不允许生产开放。

## 9. 验收用例

### 9.1 默认不可见

| 用例 | 预期 |
| --- | --- |
| `getAllServiceWay()` | 不返回 `ZF` |
| `CommonApiService.getAllServiceWay()` | 不返回 `ZF` |
| `BaseInfoManageService.getAllServiceWay()` | 不返回 `ZF` |
| 客服普通建单下拉 | 不展示直返 |
| C端权益配置页 | 不展示直返 |
| 小程序服务方式 | 不展示直返 |
| OpenAPI 普通服务方式 | 不展示直返 |

### 9.2 显式可见

| 用例 | 预期 |
| --- | --- |
| `scene=BIZ_CUSTOMER_CONFIG + includeDirectReturn=true` | 有权限时返回 `ZF` |
| `scene=PLATFORM_DIRECT_RETURN + includeDirectReturn=true` | 命中权限时返回 `ZF` |
| `scene=DIRECT_RETURN_CHANNEL + includeDirectReturn=true` | 返回 `ZF` |
| `scene=C_CUSTOMER + includeDirectReturn=true` | 不返回 `ZF` |
| `scene=OPEN_API + includeDirectReturn=true` | 默认不返回 `ZF` |

### 9.3 建单校验

| 用例 | 预期 |
| --- | --- |
| C端普通建单传 `ZF` | 失败 |
| OpenAPI 建单传 `ZF` | 失败 |
| 第三方建单传 `ZF` | 失败 |
| 平台商未配置直返商品传 `ZF` | 失败 |
| 平台商配置直返商品传 `ZF` | 通过直返可用性校验 |
| 同单混用 `ZF/JX` | 失败 |
| 同单混用 `ZF/DJ` | 失败 |
| 直返履约开关关闭 | 失败 |

### 9.4 回归

| 用例 | 预期 |
| --- | --- |
| 原到家建单 | 不变 |
| 原寄修建单 | 不变 |
| 原平台商换货/退货 | 不变 |
| 原 B端商品权益导入 | 不变 |
| 原服务类型配置 | 不变 |

## 10. 评审门禁

技术评审必须确认：

1. `ZF` 默认不可见是否被产品接受。
2. 哪些页面是直返显式入口。
3. `ServiceWaySceneEnum` 枚举值是否够用。
4. direct return availability 的权威数据源是谁。
5. B端权益表是否允许同一 `goodsId + serviceType` 多条服务方式，还是仍单条记录。
6. 直返渠道和商品权益是否需要绑定关系。
7. 履约、备件、质检退回是否具备联调时间表。
8. 老消费者升级清单是否完整。
9. OpenAPI/第三方是否明确本期不开放直返。
10. 生产灰度策略是否按商品/机构白名单执行。

## 11. 开发任务拆分

### T1：公共枚举新增

- 仓库：`xms-common`
- 内容：新增 `ZF`、测试、i18n。
- 验收：枚举测试通过。
- 依赖：无。

### T2：operation 默认过滤

- 仓库：`asp-operation-service`
- 内容：统一默认过滤 `ZF`；老接口保持签名。
- 验收：所有默认接口不返回 `ZF`。
- 依赖：可先于 xms-common，用代码兼容写法预留。

### T3：operation 显式服务方式查询

- 仓库：`asp-operation-service`
- 内容：新增 `ServiceWayQueryParam`、`ServiceWaySceneEnum`、`getServiceWays(param)`。
- 验收：只有直返 scene 返回 `ZF`。
- 依赖：T2。

### T4：operation 直返可用性校验

- 仓库：`asp-operation-service`
- 内容：新增 `checkDirectReturnAvailable`。
- 验收：未配置/无权限/开关关闭均失败。
- 依赖：B端权益和直返渠道数据确认。

### T5：aftersale 默认过滤与平台商保护

- 仓库：`asp-aftersale-service`
- 内容：全量接口过滤、平台商二分逻辑修正。
- 验收：`ZF` 不再误归 `JX`。
- 依赖：T1/T2。

### T6：aftersale 建单强校验

- 仓库：`asp-aftersale-service`
- 内容：建单入口统一处理 `ZF`。
- 验收：未命中直返校验不可建单。
- 依赖：T4。

### T7：B2B 配置支持

- 仓库：`asp-b2b-service`
- 内容：导入/导出/页面配置支持直返。
- 验收：B端直返权益可配置。
- 依赖：T1/T3。

### T8：第三方/OpenAPI fail-closed

- 仓库：`asp-third-service`、`asp-open-api`、`asp-aftersale-service`
- 内容：默认拒绝 `ZF`。
- 验收：不会走默认寄修/到家。
- 依赖：T1。

## 12. 暂缓开发声明

本轮只输出方案。建议下一轮先做评审，不直接开发。

评审通过后，第一批开发只建议做：

1. operation 默认过滤。
2. aftersale 默认过滤。
3. 平台商 `DJ/JX/ZF` fail-closed 修正。

暂不开放 B端直返建单，直到履约/备件/质检退回链路评审完成。
