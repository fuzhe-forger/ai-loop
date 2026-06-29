# FUZ-565：sfp-entitlement-config-service 错误日志 Top3 治理补齐 Loop

## 原始需求

治理 `sfp-entitlement-config-service` 错误日志 Top 3 点位，并在进入 review/MR 前补齐完整 Loop 规划、测试方案评估、E2E/预发验证方案与日志回归口径。

## 背景

远程 issue：`FUZ-565`，标题：治理 sfp-entitlement-config-service 错误日志 Top 3 点位。

已识别 Top 3 点位：

- P0 `0003-sfp-entitlement-config-service-1afbda9ccf1d95bc`：`getPolicyByGoodsIdAndSaleChannel`，关键词“当前无设备三包时间”。
- P1 `0010-sfp-entitlement-config-service-146eca415f2c7e15`：`getPolicyByGoodsIdAndSaleChannel` 业务异常。
- P2 `0017-sfp-entitlement-config-service-38866da3f0c82eaf`：`getComp`，关键词“找不到有效的政策”。

当前本地已有一个修复草案，但不可直接进入 review：

- `PolicyQueryServiceImpl#getPolicyByGoodsIdAndSaleChannel`：缺少生命周期/三包时间时由抛业务异常改为受控返回 `null` 并降级日志。
- `PolicyExternalServiceImpl#getDetail`：`policyService.getComp` 业务失败日志由 `error` 降为 `warn`。
- 已补单测并本地通过：
  - `mvn -pl sfp-entitlement-config-service-app -Dtest=PolicyQueryServiceImplTest test`
  - `mvn -pl sfp-entitlement-config-service-acl -Dtest=PolicyExternalServiceImplTest test`

## 本轮目标

本轮不是继续扩大代码改动，而是补齐工程化收口材料：

- 明确修复策略是否安全，尤其评估 `success(null)` / `null` 返回语义是否改变上游兼容性。
- 形成可执行的分层测试方案：单测、集成/契约、E2E/预发、Hera 日志回归。
- 明确是否需要调整本地草案，例如保留失败语义仅降级日志、增加开关、或改为明确业务失败码。
- 产出 review 前 checklist 和下一轮执行建议。
- 禁止自动写 Feishu、禁止远程 Git、禁止部署、禁止访问生产系统。

## 验收标准

- 输出一份测试策略评估，覆盖风险、现有单测覆盖、缺口、建议补测项。
- 输出一份 E2E/预发验证计划，包含场景、所需测试数据、入口、预期响应、Hera 观测关键字。
- 输出一份 Loop 收口判断：当前补丁可直接 review / 需调整后再 review / 需阻塞等待环境或数据。
- 如建议调整代码，给出最小改动路径和验证命令。
- 所有远端写回只生成草稿，不执行。

## 目标仓库

`/home/user/JAVA/services/sfp-entitlement-config-service`

## 建议本地验证命令

```bash
mvn -pl sfp-entitlement-config-service-app -Dtest=PolicyQueryServiceImplTest test
mvn -pl sfp-entitlement-config-service-acl -Dtest=PolicyExternalServiceImplTest test
```

## E2E/预发验证草案

### 场景 A：正常命中政策

- 数据要求：存在有效设备生命周期、有效三包时间、有效商品/渠道政策。
- 入口：`PolicyQueryService#getPolicyByGoodsIdAndSaleChannel` 或同等网关/调用链。
- 预期：返回有效政策，业务响应与修复前一致，Hera 无新增 error。

### 场景 B：缺失设备三包时间

- 数据要求：生命周期返回为空，或存在生命周期但 `repairStartTime` 为空。
- 入口：同场景 A。
- 预期：业务按确认后的语义返回；如采用降级方案，应无非预期异常堆栈；Hera 不再出现 P0/P1 的 error 日志。

### 场景 C：找不到有效政策

- 数据要求：商品/类目/渠道在当前时间无有效政策。
- 入口：覆盖 `PolicyExternalServiceImpl#getDetail` / `policyService.getComp` 调用链。
- 预期：业务失败或空结果语义保持兼容；日志由 error 降为 warn；Hera 不再出现 P2 的 error 日志。

## 外部副作用边界

允许：

- 读取本地代码、本地 Git 状态、本地 ai-loop 记忆。
- 执行本地 plan/dry-run。
- 执行本地单测。

不允许，除非用户后续明确批准：

- Feishu 写入。
- Multica 状态/评论写回。
- 远程 Git fetch/push/MR。
- 部署、发布、重启服务。
- 生产 Hera、DB、MQ、网关查询。
