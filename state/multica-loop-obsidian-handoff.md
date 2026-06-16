# Multica × ai-loop × Obsidian 当前交接

更新时间：2026-06-16 14:40 +08:00

## 当前目标

治理 Multica 当前项目 issue 与智能体运行方式，逐步停用 Claude runtime，改为 Codex runtime + 本地 crontab + ai-loop 编排，并把 Multica / Loop / CodeGraph 信息沉淀到本地 Obsidian 知识库。

## 用户已确认的治理口径

- 删除/归档：黑墙-Opus、流窜AI。
- 保留：陆码、陈码、傅喆的虾、文渊、颜回。
- 先迁移核心调度智能体：黑墙。
- 目标 runtime：Codex。
- 新建/保留项目：运营巡检与效能报告。
- 保留记录类型：巡检报告、效能日报、智能体自检。
- 归档口径：保留最近 7 天记录。
- 同步频率：每日 1 次。
- 写入策略：每次执行完自动写入 Obsidian。
- 调度策略：不再使用 Multica 内置调度承载 ai-loop 编排，推荐 crontab + ai-loop。

## 已执行状态

### 智能体

- 黑墙已迁移到 Codex runtime：`6c8a154b-504d-4aad-94a6-fe7e2a537621`。
- `黑墙-Opus` 已归档：`c0e22dac-fed1-48d0-8219-5691bf5d12de`。
- `流窜AI` 已归档：`a5c71bc5-90c3-4c07-b976-db7f13798e75`。
- `陆码`、`陈码`、`傅喆的虾`、`文渊`、`颜回` 保留未归档。

### Multica runtime

- 当前可用在线 Codex runtime：`6c8a154b-504d-4aad-94a6-fe7e2a537621`，名称 `Codex (5423225PE00307)`。
- 仍可见 Claude runtime 在线，但治理方向是不再作为主要调度运行时。

### Multica autopilot

- 多数内置 autopilot 已 paused。
- 验证时仍 active 的 autopilot：`每日文档聚合汇总`，负责人 `文渊`。
- 如后续要彻底关闭 Multica 内置调度，需要单独确认是否也暂停该 active 项。

### Obsidian / 知识库

- Vault：`/mnt/d/JAVA/knowledge/tiandao`
- 自动生成区：`/mnt/d/JAVA/knowledge/tiandao/99-generated`
- 已生成内容：
  - `99-generated/multica/projects.md`
  - `99-generated/multica/active-issues.md`
  - `99-generated/multica/archived-issues.md`
  - `99-generated/agents/runtime-status.md`
  - `99-generated/autopilots/autopilots.md`
  - `99-generated/autopilots/paused-autopilots.md`
  - `99-generated/loop/ai-loop-docs-index.md`
  - `99-generated/loop/runs-index.md`
  - `99-generated/loop/runs/*.md`
  - `99-generated/codegraph/repositories.md`
  - `99-generated/codegraph/repositories/*.md`
- CodeGraph 仓库卡片验证数量：25。
- archived issue 页面验证：已归档总数 70，最近 7 天展示 13 条。

### ai-loop 脚本

新增：

- `scripts/daily-ops-sync.sh`

修改：

- `scripts/obsidian-sync.sh`
  - 支持 `ARCHIVED_ISSUE_RETENTION_DAYS`，默认 7 天。
  - 已归档 issue 输出只展示最近 7 天。
  - 写入 Obsidian `99-generated/`，不覆盖人工文档区。

### crontab

已安装每日任务：

```cron
10 9 * * * /bin/bash /home/user/JAVA/ai/ai-loop/scripts/daily-ops-sync.sh >> /mnt/d/JAVA/logs/ai-loop/daily-ops-sync.cron.log 2>&1
```

日志：

- 最新日志：`/mnt/d/JAVA/logs/ai-loop/daily-ops-sync.latest.log`
- cron 追加日志：`/mnt/d/JAVA/logs/ai-loop/daily-ops-sync.cron.log`

### Windows 侧同步

- `daily-ops-sync.sh` 执行后会同步脚本到：`/mnt/d/JAVA/ai/ai-loop/scripts/`
- Windows 可见路径等价于：`D:\JAVA\ai\ai-loop\scripts\`

## 推荐下一步

1. 确认是否暂停 Multica 里仍 active 的 `每日文档聚合汇总`。
2. 把 `运营巡检与效能报告` 项目作为日报/巡检/自检沉淀入口。
3. 后续所有自动报告由 crontab 调 `daily-ops-sync.sh`，不要再恢复 Claude autopilot。
4. 人工整理内容写入 Obsidian 非 `99-generated/` 区；自动生成内容只放 `99-generated/`。
5. 若其他窗口接手，先读取本文件，然后运行：

```bash
cd /home/user/JAVA/ai/ai-loop
./scripts/daily-ops-sync.sh
```

## 验证命令

```bash
multica agent list --include-archived
multica runtime list
multica autopilot list
crontab -l | grep daily-ops-sync
find /mnt/d/JAVA/knowledge/tiandao/99-generated/codegraph/repositories -type f -name '*.md' | wc -l
grep -n '仅保留最近 7 天' /mnt/d/JAVA/knowledge/tiandao/99-generated/multica/archived-issues.md
```
