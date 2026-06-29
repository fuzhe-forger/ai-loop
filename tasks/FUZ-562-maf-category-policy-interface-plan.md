# FUZ-562 MAF 品类建单：政策主数据三级品类查询接口配合方案（草案）

更新时间：2026-06-16

## 1. 背景

小程序品类建单场景希望用户选择空调、冰箱等二级类目下的三级品类后直接进入建单页。此时 MAF 尚未拿到具体 SKU，但需要判断该三级品类是否支持建单、支持哪些服务类型/服务方式/服务子方式，以及三包和非三包政策信息。

参考资料：

- MAF 接口依赖 Operation 中台接口梳理文档：`https://mi.feishu.cn/wiki/YN7Rw7jzyiPh6xkOIU2clAXonVd`
- 会议纪要：`https://mi.feishu.cn/docx/UVxwd5AQNoa5MDxiDyrcKDAWnuO`
- Multica 追踪：`FUZ-562`

会议已达成初步共识：政策主数据侧需要支持基于三级品类 ID 查询政策，返回完整政策信息；三级品类下 SKU 政策差异导致派单错误的风险由业务侧知晓并接受，通过转单机制兜底。

## 2. 已确认代码位置

### 2.1 老 Operation 接口

仓库：`/mnt/d/JAVA/services/asp-operation-service`

关键文件：

| 类型 | 路径 |
|---|---|
| Dubbo 接口定义 | `operation-api/src/main/java/com/mi/xms/operation/api/service/policy/PolicyService.java` |
| Dubbo 实现 | `operation-external-service/src/main/java/com/mi/xms/operation/policy/impl/PolicyServiceImpl.java` |
| Provider 注册 | `operation-external-service/src/main/resources/dubbo/cn/dubbo-api-provider.xml` |
| 老返回 DTO | `operation-api/src/main/java/com/mi/xms/operation/api/dto/response/policy/PolicyDTO.java` |
| 老权益项 DTO | `operation-api/src/main/java/com/mi/xms/operation/api/dto/response/policy/PolicyItemDTO.java` |

已确认现有能力：

1. `PolicyService#get(...)`
   - 入参：`orgId + goodsId + orderFrom + country + channelId + orderExt`
   - 语义：按 SKU 维度查询政策。
   - 实现：`PolicyServiceImpl#get`。

2. `PolicyService#getPolicyRightList(PolicyDetailParam)`
   - 语义：优先按 `goodsId` 查 SKU 权益；无 SKU 权益时按 `trademarkId-brandClassId` 查品类权益。
   - 返回：`Response<List<RightDTO>>`。

3. `PolicyService#getByTrademarkAndBrandClasses(...)`
   - 入参：`orgId + trademarkId + brandClassIds + orderFrom + country + channelId + orderExt`
   - 语义：按品牌 + 三级品类列表批量查询品类政策。
   - 返回：`Map<Integer, PolicyDTO>`，key 为三级品类 ID。
   - 这是与本需求最接近的老接口能力。

### 2.2 新政策配置接口

仓库：`/mnt/d/JAVA/services/sfp-entitlement-config-service`

关键文件：

| 类型 | 路径 |
|---|---|
| Dubbo 接口定义 | `sfp-entitlement-config-service-api/src/main/java/com/mi/asp/config/api/service/rule/PolicyQueryService.java` |
| Dubbo 实现 | `sfp-entitlement-config-service-app/src/main/java/com/mi/asp/config/application/rule/service/impl/PolicyQueryServiceImpl.java` |
| 查询入参 | `sfp-entitlement-config-service-api/src/main/java/com/mi/asp/config/api/service/rule/dto/comp/PolicyRightsQueryDTO.java` |
| 新返回 DTO | `sfp-entitlement-config-service-api/src/main/java/com/mi/asp/config/api/service/rule/dto/comp/PolicyExternalDTO.java` |

已确认现有能力：

- `PolicyQueryService#getCompPoliciesByBrandClasses(PolicyRightsQueryDTO)`
  - 入参：`orgId + trademarkId + brandClassIds + orderFrom + country + channelId + orderExt + callerSource`
  - 返回：`Result<Map<Integer, PolicyExternalDTO>>`
  - 实现内部 dispatch `CompPolicyDetailByBrandClassIdsQuery`。

## 3. 需求理解

MAF 的核心诉求不是单纯查询某个 SKU 的政策，而是在只有三级品类 ID 的情况下返回可用于建单页判断的信息。

最低需要支持：

| 信息 | 用途 | 当前 DTO 支撑情况 |
|---|---|---|
| 三级品类 ID | 请求和响应映射 | 已支持，brandClassIds / map key |
| 服务类型 | 决定建单服务类型 | `PolicyItemDTO.serviceType` / `PolicyExternalDTO.RightItem.serviceType` |
| 服务方式 | 决定到家/到店/寄修等 | `serviceWays` |
| 服务子方式 | 决定免费到家、付费到家、上门取件等 | `serviceWays` value list |
| 三包/非三包政策 | 区分售后保障/服务产品 | `policyType`、`productType`、`items` |
| 保外支持 | 维修场景建单判断 | `outWarrantySupport` |
| 机构支持 | 是否受 org 限制 | `orgSupport`、`orgIds` |
| 官网/前台提示 | 页面提示/高亮 | `webSiteDesc`、`tips`、`RightDTO.tips` |

## 4. 推荐方案

### 4.1 推荐选择

推荐以**新政策配置接口 `sfp-entitlement-config-service` 为主承接**，同时保留老接口兼容判断。

理由：

1. 新接口已存在 `getCompPoliciesByBrandClasses`，与需求的“按三级品类查询政策”高度匹配。
2. 新接口返回 `Result<Map<Integer, PolicyExternalDTO>>`，标准化程度更好，适合作为新项目对接面。
3. `PolicyExternalDTO` 已把枚举值转成 Integer / String / Map 结构，外部消费比老 `PolicyDTO` 中 Java enum 更友好。
4. 老 `asp-operation-service` 也已有类似能力，但是老 DTO、老 `Response`、老政策实现，若继续扩展会增加后续迁移成本。

### 4.2 方案分层

#### 方案 A：直接复用新接口（优先）

MAF 接入：

```java
PolicyQueryService#getCompPoliciesByBrandClasses(PolicyRightsQueryDTO queryDTO)
```

请求示例：

```java
PolicyRightsQueryDTO query = new PolicyRightsQueryDTO();
query.setOrgId(orgId);
query.setTrademarkId(trademarkId);
query.setBrandClassIds(thirdBrandClassIds);
query.setOrderFrom(orderFrom);
query.setCountry(CountryCodeEnum.CHN);
query.setChannelId(channelId);
query.setOrderExt(orderExt);
query.setCallerSource("MAF_CATEGORY_CREATE_ORDER");
```

响应：

```java
Result<Map<Integer, PolicyExternalDTO>>
```

适用条件：

- MAF 可以引入新接口 jar。
- MAF 可以消费 `PolicyExternalDTO`。
- 当前环境可直接调用 `sfp-entitlement-config-service`。

#### 方案 B：新增 MAF 专用轻量接口（推荐评审备用）

如果 MAF 不希望消费过重的 `PolicyExternalDTO`，可以在新服务上新增面向建单的轻量接口。

建议接口：

```java
Result<Map<Integer, CategoryPolicyCreateOrderDTO>> queryCreateOrderPolicyByBrandClass(CategoryPolicyQueryRequest request);
```

请求 DTO：

```java
public class CategoryPolicyQueryRequest implements Serializable {
    private String orgId;
    private Integer trademarkId;
    private List<Integer> thirdBrandClassIds;
    private OrderFromEnum orderFrom;
    private CountryCodeEnum country;
    private Integer channelId;
    private Map<String, String> orderExt;
    private String callerSource;
}
```

响应 DTO：

```java
public class CategoryPolicyCreateOrderDTO implements Serializable {
    private Integer brandClassId;
    private Boolean supportCreateOrder;
    private List<ServicePolicyDTO> servicePolicies;
    private List<String> warnings;
}

public class ServicePolicyDTO implements Serializable {
    private Integer serviceType;
    private Map<Integer, List<Integer>> serviceWays;
    private String policyType;
    private Boolean outWarrantySupport;
    private Boolean orgSupport;
    private List<String> orgIds;
    private String webSiteDesc;
}
```

优点：

- 字段最小化，贴合建单页。
- 屏蔽政策内部 DTO 演进。
- 可以明确 `supportCreateOrder` 与 `warnings`，处理三级品类下 SKU 差异风险。

缺点：

- 需要新增 API / DTO / 实现 / 测试。
- 需要和 MAF 约定字段口径。

#### 方案 C：继续复用老接口（兼容方案）

复用：

```java
PolicyService#getByTrademarkAndBrandClasses(...)
```

返回：

```java
Map<Integer, PolicyDTO>
```

适用条件：

- MAF 当前只依赖老 `PolicyService` jar，短期无法切换新服务。
- 7 月上线时间紧，需要最小改造。

风险：

- 老接口返回不是 `Response`，异常语义需要调用方处理。
- 老 DTO 使用 enum，跨团队消费成本更高。
- 后续政策平台迁移时可能还要再改一次。

## 5. 三级品类 SKU 差异处理

会议已确认业务接受“三级品类下部分 SKU 政策差异导致派单错误”的风险，并通过转单机制兜底。因此本接口不建议为了完全准确而强依赖 SKU 明细展开。

建议返回策略：

1. 查询三级品类政策作为建单初筛依据。
2. 返回该品类支持的服务类型/服务方式/服务子方式集合。
3. 若存在无法完全代表 SKU 级差异的情况，在响应中增加 `warnings` 或文档注明风险。
4. 真正派单前或 SKU 确认后，仍以 SKU 维度政策接口做最终校验。

## 6. 参数口径建议

| 参数 | 建议 | 说明 |
|---|---|---|
| `orgId` | 必传 | 现有政策逻辑会校验机构状态和机构是否支持政策 |
| `trademarkId` | 必传 | 老品类政策 key 依赖 `trademarkId-brandClassId` |
| `thirdBrandClassIds` | 必传 | 支持批量，建议限制数量 |
| `orderFrom` | 必传 | 现有逻辑 `checkOrderFrom` 要求非空，且不能为 XMS 特殊值 |
| `country` | 可默认 CHN | 国内小程序场景默认 CHN |
| `channelId` | 待确认 | 如果涉及特殊销售渠道匹配则需传 |
| `orderExt` | 可选 | 兼容后续扩展 |
| `callerSource` | 建议传 | 便于灰度、日志、治理和问题追踪 |

## 7. 返回字段口径建议

推荐 MAF 建单页只依赖以下稳定字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `brandClassId` | Integer | 三级品类 ID |
| `supportCreateOrder` | Boolean | 是否支持建单 |
| `serviceType` | Integer | 服务类型：如维修、换货、退货等 |
| `serviceWays` | Map<Integer, List<Integer>> | 服务方式到服务子方式映射 |
| `policyType` | String | 三包/非三包、服务产品/售后保障等政策类型 |
| `outWarrantySupport` | Boolean | 是否支持保外 |
| `orgSupport` | Boolean | 是否受机构支持限制 |
| `orgIds` | List<String> | 商家支持机构列表 |
| `webSiteDesc` | String | 页面提示文案 |
| `warnings` | List<String> | 风险提示，如品类政策不代表 SKU 个性化差异 |

## 8. 影响范围

### 8.1 如果复用新接口

- 主要影响：MAF 引入新服务 API 并调用 `PolicyQueryService#getCompPoliciesByBrandClasses`。
- 政策侧可能只需补文档、联调和测试，不一定需要代码改造。

### 8.2 如果新增轻量接口

影响文件预计在：

- `sfp-entitlement-config-service-api/.../PolicyQueryService.java`
- 新增 `CategoryPolicyQueryRequest`
- 新增 `CategoryPolicyCreateOrderDTO`
- `PolicyQueryServiceImpl`
- 对应单元测试

### 8.3 如果复用老接口

影响文件预计在：

- `asp-operation-service/operation-api/.../PolicyService.java`
- `asp-operation-service/operation-external-service/.../PolicyServiceImpl.java`
- 可能新增 wrapper DTO / Response 包装方法
- 对应单元测试

## 9. 测试方案

### 9.1 单测

覆盖场景：

1. 入参为空：`brandClassIds` 为空、`trademarkId` 为空、`orgId` 为空。
2. 单三级品类有政策：返回服务类型和服务方式。
3. 多三级品类批量查询：按品类 ID 返回 Map。
4. 无政策：返回空 Map 或 `supportCreateOrder=false`，需按最终口径确认。
5. 机构异常：沿用现有机构状态校验逻辑。
6. 销售渠道特殊匹配：覆盖 `channelId` 有/无两种情况。
7. 三级品类 SKU 差异：返回 warning 或文档约束。

### 9.2 联调

需要 MAF 提供：

- 灰度三级品类 ID 清单。
- 至少 3 组真实入参：有政策、无政策、SKU 差异明显。
- 期望建单页展示/判断结果。

## 10. 排期建议

在接口归属和字段口径确认后：

| 阶段 | 时间 | 内容 |
|---|---|---|
| D0 | 0.5 天 | 确认 MAF 依赖新/老 Dubbo 接口、字段口径、灰度品类清单 |
| D1 | 1 天 | 方案评审，确认复用新接口还是新增轻量接口 |
| D2-D3 | 2 天 | 接口开发/包装、单测补充 |
| D4 | 1 天 | MAF 联调、修正字段口径 |
| D5 | 0.5-1 天 | 提测、灰度观察、输出遗留项 |

总计约 4-5 个工作日；如果直接复用 `getCompPoliciesByBrandClasses`，政策侧开发成本可降到 1-2 天，主要工作变为联调和文档确认。

## 11. 待确认清单

1. MAF 当前希望接老 `PolicyService` 还是新 `PolicyQueryService`？
2. MAF 是否能引入 `sfp-entitlement-config-service-api`？
3. 灰度涉及的 6 个二级类目及三级品类 ID 清单是什么？
4. `trademarkId` 从哪里获取？MAF 入参是否已有？
5. `orgId` 是固定值、用户定位机构，还是建单页选择机构？
6. `orderFrom` / `channelId` 在小程序品类建单场景如何取值？
7. 返回“完整政策信息”是否接受 `PolicyExternalDTO`，还是需要建单专用 DTO？
8. 无政策时返回空 Map、null，还是 `supportCreateOrder=false`？
9. 三级品类下 SKU 政策差异是否需要在接口响应中显式返回 `warnings`？
10. 7 月上线的提测时间和联调环境是什么？

## 12. 初步结论

当前代码已存在按三级品类查询政策的能力，分别位于老 `asp-operation-service` 和新 `sfp-entitlement-config-service`。本次技术方案的关键不在于“有没有能力”，而在于选择对外承接接口、明确 MAF 建单页需要的字段口径，以及处理三级品类与 SKU 政策差异的业务风险。

推荐优先复用或包装新 `PolicyQueryService#getCompPoliciesByBrandClasses`，若 MAF 对 DTO/依赖有顾虑，再新增一个面向品类建单的轻量接口。
