# 2026-06-18 Multica 收件箱批量报错修复记录

## 现象

Multica 收件箱出现大量 agent run 报错，活跃 issue 上多次出现启动即失败。

## 根因

当前 Codex runtime 通过 `codex app-server --listen stdio://` 启动，模型网关返回：

```text
tool type 'web_search' is not supported by this gateway phase
```

失败发生在模型请求初始化阶段，`tools=0`，不是业务任务执行错误。

## 影响范围

失败主要集中在使用 Codex runtime 的活跃 agent：

- 顾实
- 陆码
- 黑墙
- 颜回
- 简辞
- 裴衡
- 林溪
- 陈码

历史失败 run 主要集中在 2026-06-18 11:17 以及 14:17-14:48 左右。

## 已执行修复

1. 更新 `/home/user/.codex/config.toml`，显式关闭浏览/搜索相关 feature。
2. 批量修补现有 Multica `codex-home/config.toml`，补充同样的 feature 禁用项。
3. 重启 Multica daemon。
4. 发现 Codex app-server 仍会向当前网关暴露不兼容 `web_search`，因此执行运行时路由修复：将受影响活跃 agent 临时切换到本机 Claude runtime `4c3a7f28-e73a-43b7-96ea-34dfbede2396`。
5. 用 `FUZ-565` rerun 验证：切换前仍复现 `web_search` 失败；切换后任务进入 running 并实际执行工具调用，不再启动即失败。
6. 执行 `/home/user/JAVA/ai/ai-loop/scripts/daily-ops-sync.sh` 刷新 Obsidian 快照，成功。

## 证据

- 切换前验证 run：`FUZ-565` / `4a8ee880`，失败原因为 `responses_feature_not_supported` / `web_search`。
- 切换后验证 run：`FUZ-565` / `a3e9735c`，由 Claude runtime 接管并进入 running。
- 同步脚本成功时间：2026-06-18 15:20:13 +0800。

## 后续建议

- 在 Multica/Codex runtime 修复 `web_search` 工具暴露前，不建议把活跃 agent 切回 Codex runtime。
- 若必须恢复 Codex，需要确认 `codex app-server` 是否提供真正可生效的 default tools/native tools 禁用配置，或切换到支持 `web_search` 的网关阶段。
- 历史失败 run 不需要逐个处理；后续任务应使用 Claude runtime 正常执行。

## 验证任务收口

- `FUZ-565` / `a3e9735c` 仅用于验证 Claude runtime 可正常接管；确认无 `web_search` 启动失败后已手动取消，避免它继续推进业务实现。
- 取消后 daemon `active_task_count=0`，最近日志无新的 `responses_feature_not_supported` / `web_search` 报错。
