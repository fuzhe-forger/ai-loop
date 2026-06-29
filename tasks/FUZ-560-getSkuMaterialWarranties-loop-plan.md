# FUZ-560 getSkuMaterialWarranties 复用老接口物料来源方案验证

## Multica 原始需求

# 背景

6/10 群聊定位：新接口 `getSkuMaterialWarranties` 查不到物料 `44451/BS19H53T0938`，老接口 `getSubMaterialsHasWarranty` 正常。

已确认产品口径：新接口物料范围应与老接口一致，即按机型 BOM 子物料范围，而不是只查机型级物料。

# 根因

当前新接口下游物料来源走的是机型级物料/机型物料关系查询，没有复用老接口已经验证可用的“机型 BOM 展开 + 有保修期过滤”链路。

# 推荐改造方向

采用简化方案：不新增运营侧接口，不重做 BOM 查询能力，直接让新接口复用老接口 `GoodsService.getSubMaterialsHasWarranty(...)` 的下游结果。

核心原则：

- 不新增运营侧 Dubbo API。
- 不改变老接口行为。
- 不重写 BOM 展开逻辑。
- 只替换新接口的物料来源。
- 确保新接口外层 DTO 包装和空值转换不异常。

# 目标链路

`PolicyQueryServiceImpl.getSkuMaterialWarranties`
→ `SkuMaterialWarrantiesQueryHandler.handle`
→ 配置侧 `BaseMaterialService` 获取保修物料
→ 调用老接口 `GoodsService.getSubMaterialsHasWarranty(...)`
→ 将 `MaterialBriefDTO` 安全转换为新接口内部需要的 `SkuBomMaterialDTO`
→ 继续走现有权益主体匹配与保修期包装逻辑。

# 参数建议

老接口调用建议使用完整参数版本：

- `orgId`：来自新接口请求，建议必传。
- `goodsId`：使用 `skuId`。
- `orderFrom`：来自请求；为空时使用现有默认值。
- `serviceType`：默认 `ServiceTypeEnum.WX`，除非业务另有要求。
- `isFilteredByOrgLevel`：建议默认 `false`，避免门店维修级别过滤导致 BOM 子物料仍缺失。
- `sn`：来自请求。
- `channelId`：来自请求。

# 转换要求

老接口返回 `Set<MaterialBriefDTO>`，新接口内部转换为 `SkuBomMaterialDTO` 时必须安全处理：

- item 为 `null`：跳过。
- `macno` 为空：跳过。
- `macname` 为空：使用 `macno` 兜底。
- `salePrice` 为空：保持空。
- `macSubType` 为空：保持空。
- `macType` 取不到：保持空，不得抛异常。
- 单个物料异常不影响整体接口返回，应记录日志后跳过。

# 验收标准

- 对目标 SKU/SN/orgId 调用 `getSubMaterialsHasWarranty`，确认返回 `44451/BS19H53T0938`。
- 对同一组参数调用 `getSkuMaterialWarranties`，确认结果包含 `44451/BS19H53T0938`。
- 老接口行为不变。
- 新接口不会因老接口返回字段为空导致 NPE 或包装异常。
- 权益主体匹配优先级不变：物料编码 > 物料子类 > 物料大类 > 整机兜底。
- 政策版本选择、保修天数换算逻辑不变。

# ai-loop 验证要求

先走方案推荐与 dry-run 验证，不直接改业务代码：

- 目标仓库：`/home/user/JAVA/sfp-entitlement-config-service`
- 下游参考仓库：`/home/user/JAVA/asp-operation-service`
- 计划阶段：产出具体改造点、风险点、测试建议。
- dry-run 阶段：验证任务文件、目标仓库、审批策略和验证命令是否清晰。
- 默认不 commit、不 push、不 MR、不部署。

# 安全边界

- 本任务阶段只做方案推荐与验证。
- 不自动修改业务代码。
- 不自动提交 Git。
- 不自动创建 MR。
- 不部署。
- 不访问生产系统。
- 后续代码改造必须再次明确副作用并获得人工批准。

## Loop 执行目标

本轮只做方案推荐与验证，不修改业务代码。请基于目标仓库现状，验证简化方案是否可行，并输出具体改造点、风险点、测试建议和后续执行门禁。

## 目标仓库

- 主仓库：`/home/user/JAVA/sfp-entitlement-config-service`
- 参考仓库：`/home/user/JAVA/asp-operation-service`

## 验收标准

- 产出方案推荐结论：是否采用复用 `getSubMaterialsHasWarranty` 的简化方案。
- 列出配置侧最小改动文件与方法。
- 列出转换 `MaterialBriefDTO` 到 `SkuBomMaterialDTO` 的空值保护要求。
- 列出本地验证命令建议。
- 明确不做代码修改、不提交、不推送、不创建 MR、不部署。

## 安全边界

- 本轮只允许读取代码与生成 ai-loop 本地 artifacts。
- 不修改业务代码。
- 不自动回写 Multica comment/status。
- 后续代码改造必须重新走 in-window Loop 审批。
