# FUZ-565 推进报告（2026-06-18）

## 核心结论

- 已处理代码审查遗留项：`PolicyQueryServiceImpl` 删除 unused import，并修正 `resolvePolicyBySnAndRepairInfo` Javadoc，使其与 `Result.success(null)` 语义一致。
- 本地单测通过：`PolicyQueryServiceImplTest` 31 个用例、`PolicyExternalServiceImplTest` 21 个用例。
- 当前仍不建议关闭 FUZ-565：代码层本地验证已过，但还缺 MR、测试环境 E2E、部署后 Hera 24h 观测。
- 不执行 Git push、建 MR、部署、生产 Hera 查询或飞书写入。

## 本轮代码变更

- 仓库：`/home/user/JAVA/services/sfp-entitlement-config-service`
- 分支：`feature/error-log-governance`
- 文件：`sfp-entitlement-config-service-app/src/main/java/com/mi/asp/config/application/rule/service/impl/PolicyQueryServiceImpl.java`
- 变更：
  - 删除 `SfpConfigBizMessageConstants` unused import。
  - 删除 `SfpConfigException` unused import。
  - Javadoc 从“由上层转失败 Result”改为“由上层转为 Result.success(null)”。

## 验证结果

### 目标 reactor 测试

```bash
mvn -pl sfp-entitlement-config-service-app,sfp-entitlement-config-service-acl -am \
  -Dtest=PolicyQueryServiceImplTest,PolicyExternalServiceImplTest \
  -Dsurefire.failIfNoSpecifiedTests=false -DfailIfNoTests=false test
```

结果：通过，Reactor `BUILD SUCCESS`。

### app 模块单测

```bash
mvn -pl sfp-entitlement-config-service-app -Dtest=PolicyQueryServiceImplTest test
```

结果：通过，`Tests run: 31, Failures: 0, Errors: 0, Skipped: 0`。

### acl 模块单测

```bash
mvn -pl sfp-entitlement-config-service-acl -Dtest=PolicyExternalServiceImplTest test
```

结果：通过，`Tests run: 21, Failures: 0, Errors: 0, Skipped: 0`。

### 已知非阻塞提示

Maven 输出已有 POM 重复声明 warning，属于既有工程配置问题，本轮未改动：

- `sfp-entitlement-config-service-api` dependencyManagement 重复声明。
- `youpin-infra-rpc` dependencyManagement 重复声明。
- `maven-compiler-plugin` 重复声明。
- bootstrap 模块 `junit:junit` 重复声明。

## E2E/预发验证方案

| 场景 | 测试数据 | 入口 | 预期响应 | Hera 观测 |
|---|---|---|---|---|
| 正常命中三包政策 | SN + goodsId + saleChannel 有有效 lifecycle 和政策 | `PolicyQueryService#getPolicyByGoodsIdAndSaleChannel` | 返回 `Result.success(data)`，权益过滤结果与原逻辑一致 | 无新增 ERROR |
| SN 无三包起保信息 | lifecycle 返回空或无 repairInfo | 同上 | 返回 `Result.success(null)`，调用方不抛非预期异常 | 原 P0/P1 ERROR 下降，出现受控 WARN：`SN 分支无三包起保信息` |
| SN 有 ruleId/version 但无 repairStartTime | lifecycle 有 ruleId/version 但无法拿到 policy 或 startTime | 同上 | 优先 ruleId/version；无法命中时返回 `Result.success(null)` | 无堆栈 ERROR，WARN 包含 goodsId/sn/orderId/ruleId/version |
| getComp 找不到有效政策 | `policyService.getComp` 返回业务失败 | `PolicyExternalServiceImpl#getDetail` 调用链 | 返回 `null`，上游保持兼容空结果语义 | 原 P2 ERROR 下降，出现受控 WARN：`getComp未获取到有效政策` |

## 发布后观测方案

- 观测窗口：测试环境 E2E 通过后，部署目标环境观察 24 小时。
- ERROR 指标：Hera 搜 `sfp-entitlement-config-service` + `getPolicyByGoodsIdAndSaleChannel` + `ERROR`，对比原 Top3 基线。
- WARN 指标：Hera 搜 `SN 分支无三包起保信息`、`三包未返回 repairStartTime`、`getComp未获取到有效政策`。
- 成功阈值：Top3 ERROR 量下降 >= 95%，无新增异常类型；WARN 量与原业务无数据量级大致一致。
- 回滚条件：上游出现空指针/错误码兼容问题、工单链路异常、或 ERROR 未显著下降。

## 下一步

1. 创建 MR 前确认当前本地 diff 只包含目标代码变更和必要 Loop 配置/产物。
2. 创建 MR 并关联 FUZ-565，由非作者 reviewer 复核。
3. 测试环境部署后按 4 个 E2E 场景执行。
4. Hera 观测 24 小时后，再回填飞书 dry-run 清单并流转 FUZ-565。
