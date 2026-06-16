# Obsidian 知识库与系统自进化流程

## 目标

把 Multica、Loop、CodeGraph 和项目记忆持续沉淀到 Obsidian，形成团队知识库，并作为系统自进化输入。

## 知识库位置

- Vault：`/mnt/d/JAVA/knowledge/tiandao`
- 自动生成区：`/mnt/d/JAVA/knowledge/tiandao/99-generated`
- 人工维护区：由用户在 Vault 中自行组织，自动脚本不覆盖。

## 同步原则

- 自动脚本只写 `99-generated/`。
- 自动生成内容可覆盖，不放人工编辑内容。
- 人工整理内容写在非 `99-generated/` 区。
- 每次 Loop 完成后，至少执行一次本地同步或记录待同步原因。

## 同步入口

### 手动同步

```bash
cd /home/user/JAVA/ai/ai-loop
DRY_RUN=false ./scripts/obsidian-sync.sh
```

### 每日同步

```bash
cd /home/user/JAVA/ai/ai-loop
./scripts/daily-ops-sync.sh
```

已安装 crontab：

```cron
10 9 * * * /bin/bash /home/user/JAVA/ai/ai-loop/scripts/daily-ops-sync.sh >> /mnt/d/JAVA/logs/ai-loop/daily-ops-sync.cron.log 2>&1
```

## 自动沉淀内容

### Multica

- 项目快照：`99-generated/multica/projects.md`
- 活跃 issue：`99-generated/multica/active-issues.md`
- 归档 issue：`99-generated/multica/archived-issues.md`

### Agent / Runtime

- Runtime 与智能体状态：`99-generated/agents/runtime-status.md`
- Autopilot 状态：`99-generated/autopilots/autopilots.md`
- 已暂停 autopilot：`99-generated/autopilots/paused-autopilots.md`

### Loop

- 文档索引：`99-generated/loop/ai-loop-docs-index.md`
- 文档镜像：`99-generated/loop/docs/`
- run 索引：`99-generated/loop/runs-index.md`
- run evidence 页面：`99-generated/loop/runs/*.md`

### CodeGraph

- 仓库索引：`99-generated/codegraph/repositories.md`
- 仓库卡片：`99-generated/codegraph/repositories/*.md`

## 自进化输入

每个 Loop run 完成后，应该形成以下输入：

1. **Evidence**：run 中的 summary/stage/comment/review/verify。
2. **Experience Draft**：由 `extract-experience.sh` 生成。
3. **Memory Recommendation**：由 `recommend-memory.sh` 生成。
4. **Project Memory Update**：人工确认后写入 `memory/`。
5. **Obsidian Sync**：同步到 `99-generated/`。

## 自进化闭环

```text
Loop Run
  -> Evidence
  -> Experience Draft
  -> Human Review
  -> memory/
  -> Obsidian 99-generated
  -> 下一次任务 recommend-memory
  -> 更稳的 plan / execution / review
```

## 验证命令

```bash
# dry-run，不写入 vault
DRY_RUN=true ./scripts/obsidian-sync.sh

# 实际写入
DRY_RUN=false ./scripts/obsidian-sync.sh

# 检查生成内容
find /mnt/d/JAVA/knowledge/tiandao/99-generated -maxdepth 3 -type f | head

# 检查最新日志
cat /mnt/d/JAVA/logs/ai-loop/daily-ops-sync.latest.log
```

## 注意事项

- Obsidian 同步会调用 Multica CLI，属于外部读取；写入仅发生在本地 Vault。
- 不把 token、cookie、密钥写入 Obsidian。
- 不在 `99-generated/` 中手写重要内容，避免被覆盖。
- 如果 Vault 不存在，同步脚本会失败，不会创建错误目录。

## 当前状态

- `scripts/obsidian-sync.sh` 已支持 Multica、Loop、CodeGraph 聚合。
- `scripts/daily-ops-sync.sh` 已作为每日同步入口。
- 归档 issue 默认只展示最近 7 天。
- 黑墙已迁移到 Codex runtime，后续调度建议由 crontab + ai-loop 承载。

---

**状态**：Obsidian 知识库沉淀流程  
**生成时间**：2026-06-16
