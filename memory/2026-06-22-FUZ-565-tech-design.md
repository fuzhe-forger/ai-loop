# FUZ-565｜sfp-entitlement-config-service 错误日志 Top3 治理技术方案

> **结论**：本方案针对 `sfp-entitlement-config-service` 中“业务无数据/无有效政策”被误记为 ERROR 的 Top3 点位做日志治理。改动不扩大业务能力，只把预期内空结果从异常/ERROR 路径收敛为兼容的空结果语义 + WARN 观测，降低 Hera 收件箱噪音，同时保留排查字段。

---

## 1. 背景与目标

### 1.1 背景

飞书多维表《错误日志分析》中，治理人 `傅喆 / fuzhe1@xiaomi.com` 下共有 29 条记录，总错误次数约 `914,774`，全部集中在 `sfp-entitlement-config-service`。

其中 Top3 点位合计约 97%，优先治理：

| 优先级 | 点位ID | 主要入口 | 错误特征 | 占比 |
|---|---|---|---|---:|
| P0 | `0003-sfp-entitlement-config-service-1afbda9ccf1d95bc` | `getPolicyByGoodsIdAndSaleChannel` | 当前无设备三包时间 | 约 74.59% |
| P1 | `0010-sfp-entitlement-config-service-146eca415f2c7e15` | `getPolicyByGoodsIdAndSaleChannel` | 业务异常 | 约 16.28% |
| P2 | `0017-sfp-entitlement-config-service-38866da3f0c82eaf` | `getComp` | 找不到有效的政策 | 约 6.15% |

### 1.2 治理目标

- 降低 Hera 收件箱中预期内业务无数据场景的 ERROR 噪音。
- 保持上游接口兼容：正常命中仍返回数据，未命中仍走空结果语义。
- 保留可观测性：降级为 WARN 后仍保留 `goodsId`、`sn`、`orderId`、`ruleId`、`version`、response 等关键字段。
- 通过本地单测、测试环境 E2E、发布后 Hera 24h 观测闭环验收。

---

## 2. 问题原因分析

### 2.1 P0/P1：SN 分支缺少三包起保信息被当成系统错误

入口：

- `PolicyQueryServiceImpl#getPolicyByGoodsIdAndSaleChannel`

原逻辑：

1. 请求带 `sn` 时，服务调用 `lifecycleWarrantyService.getRepairStartTimeBySn(sn, goodsId, orderId)` 获取三包起保信息。
2. 若 lifecycle 返回 `null`，或返回对象中 `repairStartTime == null`，原逻辑抛出 `SfpConfigException`。
3. 这类“没有三包起保信息/无法匹配历史政策”的场景在业务上可能是预期空结果，但日志链路会被记为 ERROR。
4. 高调用量叠加后形成 Hera 大量报错。

根因判断：

- 这不是 JVM 异常、RPC 不可用或数据损坏，而是业务数据不存在/未命中。
- 原实现把“业务无结果”用异常表达，导致错误等级过高。

### 2.2 P2：getComp 找不到有效政策被打成 ERROR

入口：

- `PolicyExternalServiceImpl#getDetail`
- 下游调用：`policyService.getComp(param)`

原逻辑：

1. `policyService.getComp` 返回业务失败 Response。
2. 代码使用 `log.error("调用policyService.getComp错误，{}", response)`。
3. 但该失败常见含义是“找不到有效政策”，对上游来说原本就是 `null` 空结果。
4. ERROR 等级与实际业务含义不匹配。

根因判断：

- 返回 `null` 的语义原本已经存在，问题集中在日志等级过高。
- 应把“找不到有效政策”从 ERROR 调整为 WARN，而不是吞掉所有观测。

---

## 3. 改动原则

| 原则 | 说明 |
|---|---|
| 最小改动 | 只处理 Top3 点位，不扩大到其他日志治理。 |
| 保持兼容 | 正常命中政策结果不变；业务无结果保持空结果语义。 |
| 降级不消失 | ERROR 降为 WARN，但保留排查字段。 |
| 测试先行 | 单测覆盖新增空结果分支，MR 后必须 E2E 与 Hera 观测。 |
| 不直接 Done | 未完成测试环境 E2E 与 24h 观测前，FUZ-565 保持 `in_review`。 |

---

## 4. 代码改动点

### 4.1 `PolicyQueryServiceImpl#getPolicyByGoodsIdAndSaleChannel`

文件：

- `sfp-entitlement-config-service-app/src/main/java/com/mi/asp/config/application/rule/service/impl/PolicyQueryServiceImpl.java`

改动内容：

1. SN 分支调用 `resolvePolicyBySnAndRepairInfo` 时新增传入 `orderId`，用于日志排查。
2. `repairInfo == null` 时，不再抛 `SfpConfigException`，改为：
   - 打 WARN：`SN 分支无三包起保信息`
   - 返回 `null`
   - 上层统一转为 `Result.success(null)`
3. `repairInfo.getRepairStartTime() == null` 时，不再抛 `SfpConfigException`，改为：
   - 打 WARN：`三包未返回 repairStartTime`
   - 保留 `goodsId/sn/orderId/ruleId/version`
   - 返回 `null`
4. 修正 Javadoc：明确无法解析时返回 `null`，由上层转为 `Result.success(null)`。
5. 清理 unused import：`SfpConfigBizMessageConstants`、`SfpConfigException`。

伪代码对比：

```java
// 原逻辑
if (repairInfo == null) {
    throw new SfpConfigException(...);
}
if (repairInfo.getRepairStartTime() == null) {
    throw new SfpConfigException(...);
}

// 新逻辑
if (repairInfo == null) {
    log.warn("SN 分支无三包起保信息，goodsId={}, sn={}, orderId={}", goodsId, sn, orderId);
    return null;
}
if (repairInfo.getRepairStartTime() == null) {
    log.warn("三包未返回 repairStartTime，goodsId={}, sn={}, orderId={}, ruleId={}, version={}", ...);
    return null;
}
```

### 4.2 `PolicyExternalServiceImpl#getDetail`

文件：

- `sfp-entitlement-config-service-acl/src/main/java/com/mi/asp/config/acl/policy/PolicyExternalServiceImpl.java`

改动内容：

```java
// 原逻辑
log.error("调用policyService.getComp错误，{}", response);
return null;

// 新逻辑
log.warn("调用policyService.getComp未获取到有效政策，{}", response);
return null;
```

说明：

- 返回值仍为 `null`，保持兼容。
- 仅调整日志等级和文案，使其符合“未获取到有效政策”的业务语义。

### 4.3 单测补充

文件：

- `sfp-entitlement-config-service-app/src/test/java/com/mi/asp/config/application/rule/service/impl/PolicyQueryServiceImplTest.java`

新增用例：

| 用例 | 覆盖场景 | 断言 |
|---|---|---|
| `shouldReturnNullWhenSnRepairInfoAbsent` | lifecycle 返回 `null` | `Result` 非空、`data == null`，不触发 policy 查询 |
| `shouldReturnNullWhenSnRepairStartTimeAbsent` | repairInfo 存在但 `repairStartTime == null` | `Result` 非空、`data == null`，不触发 policy 查询 |

---

## 5. 改动方案与执行流程

### 5.1 分支与提交

- 仓库：`git@git.n.xiaomi.com:mit/after-sales/sfp-entitlement-config-service.git`
- 分支：`feature/error-log-governance`
- 提交：
  - `80def42e fix: 降低错误日志等级，业务无数据不再抛异常`
  - `eb06a9b5 fix: 清理错误日志治理审查问题`

MR 创建入口：

- https://git.n.xiaomi.com/mit/after-sales/sfp-entitlement-config-service/-/merge_requests/new?merge_request%5Bsource_branch%5D=feature%2Ferror-log-governance&merge_request%5Btarget_branch%5D=master

### 5.2 流程图

```mermaid
flowchart TD
    A[请求 getPolicyByGoodsIdAndSaleChannel] --> B{是否传入 SN}
    B -- 否 --> C[按当前 SKU/品类政策查询]
    B -- 是 --> D[查询 lifecycle 三包起保信息]
    D --> E{repairInfo 是否存在}
    E -- 否 --> F[WARN + Result.success(null)]
    E -- 是 --> G{ruleId/version 是否可命中政策}
    G -- 是 --> H[返回命中政策]
    G -- 否 --> I{repairStartTime 是否存在}
    I -- 否 --> J[WARN + Result.success(null)]
    I -- 是 --> K[按起保日期查询历史政策]
    C --> L{是否命中权益}
    H --> L
    K --> L
    L -- 是 --> M[Result.success(data)]
    L -- 否 --> N[Result.success(null)]
```

### 5.3 发布策略

1. MR review：重点看空结果语义是否符合上游契约。
2. 测试环境部署：先覆盖 4 个 E2E 场景。
3. 预发/目标环境灰度：观察接口响应和 WARN/ERROR 变化。
4. Hera 24h 观测：确认 Top3 ERROR 明显下降且无新增异常类型。
5. 飞书治理表 dry-run 回填：仅更新治理状态、源码路径、处理结论，不改原始错误样例和次数。

---

## 6. 兼容性与风险评估

### 6.1 兼容性结论

| 调用链 | 现状 | 兼容性判断 |
|---|---|---|
| `getPolicyByGoodsIdAndSaleChannel` 正常命中 | 返回 `Result.success(data)` | 不变 |
| SN 无三包起保信息 | 原异常/ERROR | 改为 `Result.success(null)`，需要 E2E 验证上游空结果处理 |
| SN 有 ruleId/version 且命中 | 直接返回对应政策 | 不变 |
| `getComp` 找不到有效政策 | 原本返回 `null`，但打 ERROR | 仍返回 `null`，日志降级为 WARN |

### 6.2 主要风险

| 风险 | 影响 | 缓解措施 |
|---|---|---|
| 上游未兼容 `Result.success(null)` | 可能出现 NPE 或错误展示 | E2E 覆盖 B/C 场景，检查调用方响应 |
| ERROR 降级后掩盖真实故障 | 真实 RPC/系统错误可能被误降级 | 本次只处理业务无数据分支；WARN 保留 response 与关键字段 |
| Hera ERROR 降低但 WARN 激增 | 告警噪音迁移 | 观测 WARN 量级，必要时增加采样或业务指标区分 |
| 数据样例不足 | 测试环境无法复现 Top3 | 提前准备 SN/goodsId/saleChannel 测试数据 |

---

## 7. 验收方案

### 7.1 本地单测验收

已执行并通过：

```bash
mvn -pl sfp-entitlement-config-service-app -Dtest=PolicyQueryServiceImplTest test
```

结果：

- `Tests run: 31, Failures: 0, Errors: 0, Skipped: 0`

已执行并通过：

```bash
mvn -pl sfp-entitlement-config-service-acl -Dtest=PolicyExternalServiceImplTest test
```

结果：

- `Tests run: 21, Failures: 0, Errors: 0, Skipped: 0`

已执行并通过：

```bash
mvn -pl sfp-entitlement-config-service-app,sfp-entitlement-config-service-acl -am \
  -Dtest=PolicyQueryServiceImplTest,PolicyExternalServiceImplTest \
  -Dsurefire.failIfNoSpecifiedTests=false -DfailIfNoTests=false test
```

结果：Reactor `BUILD SUCCESS`。

### 7.2 测试环境 E2E 验收

| 场景 | 测试数据 | 入口 | 预期响应 | Hera 预期 |
|---|---|---|---|---|
| A. 正常命中三包政策 | SN + goodsId + saleChannel 有有效 lifecycle 和政策 | `PolicyQueryService#getPolicyByGoodsIdAndSaleChannel` | `Result.success(data)`，权益过滤结果正确 | 无新增 ERROR |
| B. SN 无三包起保信息 | lifecycle 返回空或无 repairInfo | 同上 | `Result.success(null)`，上游无 NPE/异常展示 | P0/P1 ERROR 下降，出现受控 WARN |
| C. SN 有 ruleId/version 但无有效 startTime/政策 | lifecycle 返回 ruleId/version 但无法命中政策或 startTime 缺失 | 同上 | 空结果语义兼容，链路不抛非预期异常 | WARN 包含 `goodsId/sn/orderId/ruleId/version` |
| D. getComp 找不到有效政策 | 商品/类目/渠道当前无有效政策 | `PolicyExternalServiceImpl#getDetail` 调用链 | 返回 `null`，上游按空结果处理 | P2 ERROR 下降，出现 `getComp未获取到有效政策` WARN |

### 7.3 Hera 观测验收

观测窗口：部署后 24 小时。

观测指标：

| 指标 | 查询建议 | 通过标准 |
|---|---|---|
| P0/P1 ERROR | `sfp-entitlement-config-service` + `getPolicyByGoodsIdAndSaleChannel` + `ERROR` | 较基线下降 ≥ 95% |
| P2 ERROR | `sfp-entitlement-config-service` + `getComp` + `ERROR` + `找不到有效的政策` | 较基线下降 ≥ 95% |
| WARN 替代量 | `SN 分支无三包起保信息` / `三包未返回 repairStartTime` / `getComp未获取到有效政策` | WARN 量级与原业务无数据量级匹配 |
| 新增异常 | 服务 ERROR 总览 | 无新增异常类型，无上游 NPE |

### 7.4 回滚方案

触发条件：

- 测试环境或线上出现上游 NPE/错误展示。
- ERROR 未下降或出现新增异常类型。
- 业务方确认 `Result.success(null)` 语义不可接受。

回滚方式：

1. 回滚 MR 对应提交。
2. 恢复 SN 缺三包信息时的原异常路径，或改为明确业务失败码。
3. `getComp` 日志等级恢复 ERROR 或按新错误码分流。
4. 重新执行单测和 E2E。

---

## 8. MR Review Checklist

- [ ] `Result.success(null)` 是否符合 `getPolicyByGoodsIdAndSaleChannel` 上游契约。
- [ ] 上游是否所有路径都检查 `isSuccess()` 与 `getData()`。
- [ ] WARN 日志是否足够定位问题，不遗漏 `goodsId/sn/orderId/ruleId/version`。
- [ ] `getComp` 返回 `null` 是否与原语义完全一致。
- [ ] 单测覆盖新增空结果分支。
- [ ] 测试环境 E2E 数据已准备。
- [ ] Hera 24h 观测负责人和查询口径已确认。

---

## 9. 当前状态与下一步

当前状态：

- 分支已推送：`feature/error-log-governance`
- 最新提交：`eb06a9b5`
- FUZ-565 保持 `in_review`
- GitLab API token 当前失效，CLI 无法自动创建 MR；已提供 MR 创建入口。

下一步：

1. 手动创建 MR 并回填 FUZ-565。
2. Reviewer 重点确认空结果语义与上游兼容性。
3. 测试环境执行 4 个 E2E 场景。
4. Hera 24h 观测达标后回填飞书治理表。
5. 达标后再将 FUZ-565 流转为 `done`。
