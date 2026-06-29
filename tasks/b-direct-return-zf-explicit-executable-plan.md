# B端直返 ZF 显式获取与场景隔离：可执行技术方案 v1.0

## 0. 本轮 Loop 结论

- 任务文件：`/home/user/JAVA/ai/ai-loop/tasks/b-direct-return-zf-explicit-scope.md`
- Loop planning run：`/home/user/JAVA/services/asp-operation-service/runs/20260618-141056-plan-b-direct-return-zf-explicit-scope/`
- 状态：`ai-loop plan` 已启动只读 agent 并生成 artifacts，但 agent 未写 `summary.md/final.md`，已手动中止；本方案基于 Loop 日志 + 本地代码审计收敛。
- 业务代码：本轮未修改。
- 本地配置：按授权仅在目标仓库创建 `.ai-loop.yml`，不得提交远端。

## 1. 核心决策

`ZF/直返` 作为公共枚举值新增到 `xms-common`，但作为“显式获取/显式使用”的服务方式处理：

1. 现有无参/默认服务方式接口默认过滤 `ZF`。
2. 新增带场景的查询接口，只有明确场景、权限和直返能力校验通过时才返回 `ZF`。
3. 展示可见性、业务可用性、建单防线三层拆开实现。
4. 建单入口遇到 `serviceWay=ZF` 必须 fail-closed，不允许默认降级成 `JX/DJ`。
5. C端权益、客服普通建单、OpenAPI、小程序、第三方普通建单默认不可见、不可用 `ZF`。

## 2. 三层模型

### 2.1 展示可见性层

回答“页面/接口是否可以看到直返”。

- 默认返回：`DJ/DD/JX/CJ/XN`。
- 仅以下场景允许返回 `ZF`：
  - B端商品权益配置页。
  - B端直返渠道配置页。
  - 平台商直返专项建单/查询页。
  - 管理后台具备直返权限的配置页。
- 无参接口一律不返回 `ZF`。

### 2.2 业务可用性层

回答“当前机构/商品/服务类型是否允许使用直返”。

必须同时满足：

1. 直返全局开关开启。
2. 调用场景属于 B端/平台商直返。
3. `orgId/sapCode/customerCode` 命中允许的 B端/平台商主体。
4. `goodsId + serviceType` 在 B端商品权益中配置 `serviceWay=ZF`。
5. 直返渠道、履约寻仓、需求单、取消、质检退回依赖已配置。

### 2.3 建单防线层

回答“请求传 `ZF` 时是否允许创建/流转”。

- 任何建单入口只要 `serviceWay=ZF`，必须强制调用直返校验服务。
- 校验失败返回明确错误：`当前商品/机构未配置直返服务方式` 或 `直返链路能力未开启`。
- 不允许把未知服务方式归类为寄修。
- 不允许同一工单混用 `ZF/JX/DJ`。

## 3. 接口与模型设计

### 3.1 新增枚举

建议放在 `operation-api` 或对应 API 包，避免散落字符串。

```java
public enum ServiceWaySceneEnum {
    DEFAULT,
    C_CUSTOMER,
    CUSTOMER_SERVICE_CREATE,
    OPEN_API,
    MINI_APP,
    BIZ_CUSTOMER_CONFIG,
    PLATFORM_DIRECT_RETURN,
    DIRECT_RETURN_CHANNEL,
    ADMIN_CONFIG
}
```

### 3.2 新增查询 DTO

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

### 3.3 新增展示接口

在 `BaseInfoManageService` 或新增专用 facade 中提供：

```java
Response<ListDTO<SelectDTO>> getServiceWays(ServiceWayQueryParam param);
```

兼容策略：

```java
Response<ListDTO<SelectDTO>> getAllServiceWay(); // 保留，固定过滤 ZF
```

### 3.4 新增业务校验接口

建议在 B端直返专用 domain/service 中新增：

```java
Response<DirectReturnAvailabilityDTO> checkDirectReturnAvailable(DirectReturnAvailabilityParam param);
```

字段建议：

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
}

public class DirectReturnAvailabilityDTO implements Serializable {
    private Boolean available;
    private String reasonCode;
    private String reasonMessage;
    private String directReturnChannelCode;
    private String warehouseOrgId;
}
```

## 4. 代码改造清单

### 4.1 xms-common

文件：`JAVA/shared/xms-common/xms-common/src/main/java/com/mi/xms/common/constant/ServiceWayEnum.java`

改造：

1. 新增 `ZF(6, "直返", "XmsCommon.ServiceWayEnum.ZF")`。
2. 补单测：`getById(6)`、`getByName("ZF")`、ID 不冲突。
3. 补 i18n key：`XmsCommon.ServiceWayEnum.ZF`。

验收：新枚举存在，但没有任何默认业务接口直接全量暴露。

### 4.2 asp-operation-service：统一过滤能力

新增建议：

- `operation-api/.../ServiceWaySceneEnum.java`
- `operation-api/.../ServiceWayQueryParam.java`
- `operation-biz/.../ServiceWayVisibilityService.java`

核心规则：

```java
boolean canShowDirectReturn(ServiceWayQueryParam param) {
    if (!Boolean.TRUE.equals(param.getIncludeDirectReturn())) return false;
    if (param.getScene() == null) return false;
    switch (param.getScene()) {
        case BIZ_CUSTOMER_CONFIG:
        case PLATFORM_DIRECT_RETURN:
        case DIRECT_RETURN_CHANNEL:
        case ADMIN_CONFIG:
            return hasDirectReturnPermissionOrContext(param);
        default:
            return false;
    }
}
```

### 4.3 asp-operation-service：默认服务方式接口过滤

必须改造点：

1. `operation-manage-service/src/main/java/com/mi/xms/operation/mng/base/impl/BaseInfoManageServiceImpl.java`
   - `getAllServiceWay()` 当前直接 `ServiceWayEnum.values()`，改为统一过滤，不返回 `ZF`。
   - 新增带参 `getServiceWays(ServiceWayQueryParam param)`。
2. `operation-dao-service/src/main/java/com/mi/xms/operation/base/impl/BaseDictServiceImpl.java`
   - `getServiceWayVoList()` 当前从 `BASE_SERVICE_WAY` 字典取所有启用项，默认过滤 `ZF`。
   - 新增带 scene 的查询方法，只有直返场景返回 `ZF`。
3. `operation-dao-service/src/main/java/com/mi/xms/operation/policy/impl/BaseServiceWayServiceImpl.java`
   - `getAllServiceWayVoList()` 默认过滤 `ZF`。
   - 新增带 scene 的查询方法供直返配置页使用。
4. `operation-manage-service/src/main/java/com/mi/xms/operation/mng/policy/impl/ServiceTypeManageServiceImpl.java`
   - `list/detail` 默认不出现 `ZF`。
   - 直返配置入口改用显式查询。
5. `operation-manage-service/src/main/java/com/mi/xms/operation/mng/policy/impl/RightManageServiceImpl.java`
   - `getAllRightServiceList()` 默认过滤 `ZF`，避免 C端权益配置页污染。

补充发现：`BaseInfoManageServiceImpl.getAllServiceWayList()` 方法名像服务方式，但当前取 `BASE_SERVICE_TYPE`，需要单独确认是否历史命名错误；本项目不建议顺手修，避免扩大范围。

### 4.4 asp-operation-service：组织服务方式能力

文件：`operation-biz/src/main/java/com/mi/xms/operation/biz/organization/org/ability/serviceway/factory/IServiceWayAbilityFactory.java`

问题：当前只支持 `DJ/DD/JX/CJ`，default 抛异常。

策略：

1. 如果 `ZF` 不应进入组织能力配置，默认过滤即可。
2. 如果直返机构/渠道要配置到组织服务方式，需要新增 `ZfServiceWayAbility`，并明确其下游服务子方式、机构搜索、地址规则。
3. 禁止让 `ZF` 进入该 factory 后走 default 空异常。

### 4.5 asp-operation-service：B端权益接口

文件：`operation-api/src/main/java/com/mi/xms/operation/api/service/businesscustomer/BizCustomerService.java`

现状：`getGoodsRight(goodsId, serviceType)` 入参只有商品和服务类型。

策略：

1. 保留原接口，只表示“商品是否配置了 B端商品权益服务方式”。
2. 不把它作为“当前调用方可使用 ZF”的授权接口。
3. 新增 `checkDirectReturnAvailable` 或等价接口，入参必须含 `orgId/sapCode/customerCode/goodsId/serviceType`。

### 4.6 asp-aftersale-service：默认全量接口过滤

必须改造点：

1. `maf-service-provider/src/main/java/com/mi/maf/dubbo/service/srv/impl/SrvEnumDubboServiceImpl.java`
   - `getAllServiceWay()` 默认过滤 `ZF`。
   - 新增带 scene 的接口或调用 operation 新接口。
2. `maf-api/src/main/java/com/mi/maf/api/service/CommonApiService.java`
   - `getAllServiceWay()` 默认过滤 `ZF`。
3. `maf-api/src/main/java/com/mi/maf/api/service/SrvServicingApiService.java`
   - deprecated `getAllServiceWay()` 也必须过滤，不能因为 deprecated 漏掉。
4. `maf-service-provider/src/main/java/com/mi/maf/dubbo/service/srv/impl/SrvListDubboServiceImpl.java`
   - `getOrgServiceWay(Long miliao)` 当前客服/平台商直接 `ServiceWayEnum.values()`。
   - 平台商普通场景仍默认过滤 `ZF`；直返专项场景必须新增带参接口，不复用此无商品维度接口。

### 4.7 asp-aftersale-service：平台商二分逻辑

文件：`maf-srv-aftersale/src/main/java/com/mi/maf/srv/aftersale/manager/platform/PlatformPolicyBaseManager.java`

必须改：

1. `isToHomeGoodsId`：当前只接受 `DJ/JX`，遇 `ZF` 抛“未获取政策权益”。应改为显式处理：`DJ=true`、`JX=false`、`ZF` 抛直返专项提示或走新判断方法。
2. `goodsIdsGroupingBySrvWay`：当前非 `DJ` 全归 `JX`。必须改为按实际 `serviceWay` 分组，`ZF` 单独一组，并在平台商普通混单校验中禁止混用。
3. `PlatformRuleService.checkGoodsIdsPolicyNonDiff`：错误提示从“上门/寄修不能一同受理”扩展为“上门/寄修/直返不能一同受理”。

### 4.8 asp-aftersale-service：建单强校验

涉及入口：

- `CreateReq`
- `ThirdServiceCreateReq`
- `SrvCreateServiceOpenApiParam`
- 平台商 `PlatformReq`

规则：

1. 传 `ZF` 时必须调用 direct return availability。
2. OpenAPI/小程序/普通第三方默认拒绝 `ZF`。
3. 平台商直返专项入口允许 `ZF`，但必须校验商品权益和直返链路开关。
4. `ZF` 不允许走寄修受理机构搜索、上门预约、普通网点任务。

### 4.9 asp-b2b-service：B端权益配置

文件：`asp-b2b-web/src/main/java/com/xiaomi/xms/b2b/web/freemarker/controller/BizCustGoodsRightController.java`

必须改：

1. 导入校验从“到家或寄修”扩展到显式允许“直返”。
2. `convertToEntityList` 增加 `ZF` desc 到 id 的转换。
3. 前端/模板服务方式下拉改用显式直返接口，不使用默认全量接口。
4. 导出要支持 `ZF -> 直返`。

### 4.10 asp-third-service / OpenAPI / 小程序

策略：

1. 默认不支持 `ZF`。
2. 如果收到 `ZF`，返回明确不支持错误，不允许默认映射到 `JX`。
3. `EnumUtils.serviceWayToBusinessType` 等映射必须显式处理 `ZF`：要么映射直返业务类型，要么 fail-closed。

## 5. 发版顺序

### 阶段 A：兼容保护先行

1. `asp-operation-service`：默认过滤能力、默认接口过滤、测试。
2. `asp-aftersale-service`：默认接口过滤、平台商二分逻辑保护、建单遇未知服务方式 fail-closed。
3. `asp-b2b-service`：先不暴露 `ZF`，但修复硬编码只认 `DJ/JX` 的准备逻辑。

目标：即使未来 `xms-common` 出现 `ZF`，默认接口也不会把它暴露给老场景。

### 阶段 B：公共枚举发版

1. `xms-common` 新增 `ZF` 并发 API jar。
2. provider 侧升级 `xms-common`。
3. consumer 侧逐步升级 `xms-common`。

门禁：不得有未过滤的 `ServiceWayEnum.values()` 对外返回。

### 阶段 C：显式获取接口发版

1. `operation-api` 发布 `ServiceWayQueryParam/ServiceWaySceneEnum`。
2. `operation-provider` 实现 `getServiceWays(param)`。
3. `aftersale/provider` 和 B2B 前端调用新接口。

### 阶段 D：直返业务链路发版

1. B端权益配置支持 `ZF`。
2. 平台商直返专项页面展示 `ZF`。
3. 建单校验接入 direct return availability。
4. 履约、备件、质检退回链路联调。

### 阶段 E：按商品灰度开放

1. 通过 B端商品权益配置控制开放。
2. 通过直返全局开关和白名单控制入口。
3. 只对白名单商品/机构开放，不做全系统灰度。

## 6. 配置与开关

建议新增：

```text
direct.return.enabled=false
direct.return.visible.scenes=BIZ_CUSTOMER_CONFIG,PLATFORM_DIRECT_RETURN,DIRECT_RETURN_CHANNEL
direct.return.org.whitelist=
direct.return.sap.whitelist=
direct.return.goods.whitelist=
direct.return.openapi.enabled=false
direct.return.third.enabled=false
```

默认值全部保守：不开启、不展示、不允许第三方。

## 7. Fail-Closed 策略

1. `ServiceWayEnum.getById(6)` 返回 `ZF`，但默认展示层过滤。
2. 无 scene、scene 非白名单、无权限、无配置时，不返回 `ZF`。
3. 建单传 `ZF` 但直返能力不可用时，返回错误，不降级。
4. 直返履约依赖未配置时，返回错误，不创建半成品单。
5. 未识别服务方式时，不走 `default -> JX`。
6. 第三方/OpenAPI 默认拒绝 `ZF`。

## 8. 测试与验收清单

### 8.1 单元测试

- `ServiceWayEnumTest`：`ZF` id/name/desc/i18n key。
- `ServiceWayVisibilityServiceTest`：各 scene 是否返回 `ZF`。
- `DirectReturnAvailabilityServiceTest`：配置命中/不命中/开关关闭/白名单未命中。
- `PlatformPolicyBaseManagerTest`：`DJ/JX/ZF` 分组，不再把 `ZF` 归 `JX`。
- `BizCustGoodsRightControllerTest`：导入/导出直返。

### 8.2 接口测试

- 老 `getAllServiceWay()` 不返回 `ZF`。
- `getServiceWays(DEFAULT, includeDirectReturn=true)` 不返回 `ZF`。
- `getServiceWays(BIZ_CUSTOMER_CONFIG, includeDirectReturn=true)` 在有权限时返回 `ZF`。
- `getOrgServiceWay(miliao)` 普通客服/平台商不返回 `ZF`。
- C端 `PolicyService.get/getPolicyRightList` 默认不返回 `ZF`。

### 8.3 建单测试

- 普通 C端建单传 `ZF`：失败。
- OpenAPI 建单传 `ZF`：默认失败。
- 第三方建单传 `ZF`：默认失败。
- 平台商直返商品传 `ZF`：校验通过后进入直返链路。
- 未配置直返商品传 `ZF`：失败。
- 同一工单混 `ZF/JX/DJ`：失败。

### 8.4 回归测试

- C端权益配置页不展示直返。
- 客服普通建单不展示直返。
- 小程序/开放平台服务方式不展示直返。
- 平台商原寄修/到家流程不变。
- B端商品权益原导入导出不变。

## 9. 开发任务拆分

### Task 1：xms-common 新增 ZF

- 责任仓库：`xms-common`
- 文件：`ServiceWayEnum.java`、对应 test/i18n。
- 验收：枚举存在，ID=6，无冲突。

### Task 2：operation 默认过滤与显式查询接口

- 责任仓库：`asp-operation-service`
- 文件范围：`operation-api`、`operation-manage-service`、`operation-dao-service`。
- 目标：新增 `ServiceWaySceneEnum/ServiceWayQueryParam/getServiceWays`，旧接口默认过滤。
- 验收：老接口不返回 `ZF`，显式直返场景可返回。

### Task 3：operation B端直返可用性校验

- 责任仓库：`asp-operation-service`
- 文件范围：businesscustomer domain/service。
- 目标：新增 `checkDirectReturnAvailable`，入参含 `orgId/sapCode/customerCode/goodsId/serviceType`。
- 验收：配置命中才 available。

### Task 4：aftersale 默认接口过滤与平台商保护

- 责任仓库：`asp-aftersale-service`
- 文件范围：`SrvEnumDubboServiceImpl`、`CommonApiService`、`SrvServicingApiService`、`SrvListDubboServiceImpl`、`PlatformPolicyBaseManager`、`PlatformRuleService`。
- 目标：默认不返回 `ZF`；平台商逻辑不再把 `ZF` 当 `JX`。
- 验收：普通入口不展示 `ZF`；`ZF` 单独分组并 fail-closed。

### Task 5：建单入口 ZF 强校验

- 责任仓库：`asp-aftersale-service`
- 文件范围：Create/Third/OpenAPI/Platform create 转换与校验服务。
- 目标：`serviceWay=ZF` 统一走 direct return availability。
- 验收：未配置失败，配置命中进入直返链路。

### Task 6：B2B 商品权益配置支持直返

- 责任仓库：`asp-b2b-service`
- 文件：`BizCustGoodsRightController.java` 及页面模板。
- 目标：导入/导出/新增/编辑支持 `ZF`，但只在直返显式入口展示。
- 验收：直返权益可配置，普通默认页面不误展示。

### Task 7：第三方/OpenAPI 默认拒绝 ZF

- 责任仓库：`asp-third-service`、`asp-open-api`、`asp-aftersale-service`
- 目标：未纳入直返前，收到 `ZF` 明确失败。
- 验收：无默认映射到寄修/到家。

## 10. 上线门禁

上线前必须满足：

1. 全仓扫描无未过滤的外部 `ServiceWayEnum.values()` 返回。
2. 全仓扫描无 `非 DJ -> JX` 的二分逻辑残留在平台商直返链路。
3. 所有无参默认接口不返回 `ZF`。
4. 所有建单入口传 `ZF` 都 fail-closed 或走直返校验。
5. 老消费者升级清单完成，或者保证不会收到 `ZF`。
6. 履约/备件/质检退回依赖可用性确认完成。

## 11. 推荐下一轮 Loop 执行方式

下一轮如进入实现，不建议一次性跨多仓修改。建议按任务分仓执行：

1. 先在 `asp-operation-service` 做 Task 2 的默认过滤和显式查询接口。
2. 再在 `asp-aftersale-service` 做默认接口过滤和平台商 fail-closed。
3. 最后做 B2B 配置和建单链路。

每轮执行前要求：目标 repo 工作树干净或只存在明确允许的 Loop artifacts；先 dry-run，再真实 run。
