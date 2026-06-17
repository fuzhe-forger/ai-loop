# FUZ-564 Phase 3 Obsidian 可读摘要同步报告

## 核心结论

- 已将 Multica issue 可读摘要层真实写入 Obsidian 自动生成区。
- 已发现并修复 `multica issue list` 默认快照不包含 `backlog` 且最多返回 100 条的问题。
- 修复后同步脚本按状态分页汇总，当前读取 issue 数从 100/默认快照提升到 555。
- Obsidian 生成区当前生成 84 张可读摘要卡，包含 `FUZ-564`。
- `FUZ-561`、`FUZ-562` 的飞书链接已进入外部产物链接索引。

## 变更范围

- `scripts/obsidian-sync.sh`
  - 将单次 `multica issue list --limit 600` 改为按状态分页拉取。
  - 覆盖状态：`backlog`、`todo`、`in_progress`、`in_review`、`blocked`、`done`、`cancelled`。
  - 按 issue `id/identifier/number` 去重后生成统一 `issues.json`。

## 写入位置

- `/mnt/d/JAVA/knowledge/tiandao/99-generated/multica/readable-summaries.md`
- `/mnt/d/JAVA/knowledge/tiandao/99-generated/multica/issues/`
- `/mnt/d/JAVA/knowledge/tiandao/99-generated/governance/external-links.md`
- `/mnt/d/JAVA/knowledge/tiandao/99-generated/loop/docs/`
- `/mnt/d/JAVA/knowledge/tiandao/99-generated/codegraph/repositories/`
- `/mnt/d/JAVA/knowledge/tiandao/99-generated/loop/runs/`

## 验证命令

```bash
cd /home/user/JAVA/ai/ai-loop
bash -n scripts/obsidian-sync.sh
DRY_RUN=true ./scripts/obsidian-sync.sh | tee /tmp/FUZ-564-phase3-obsidian-dry-run-after-fix.log
DRY_RUN=false ./scripts/obsidian-sync.sh | tee /tmp/FUZ-564-phase3-obsidian-write-after-fix.log
```

## 验证结果

- `bash -n scripts/obsidian-sync.sh`：通过。
- 干跑：读取 issue `555`，生成可读摘要卡 `84`。
- 真实写入：完成写入 `/mnt/d/JAVA/knowledge/tiandao/99-generated`。
- 关键文件存在：
  - `/mnt/d/JAVA/knowledge/tiandao/99-generated/multica/readable-summaries.md`
  - `/mnt/d/JAVA/knowledge/tiandao/99-generated/multica/issues/FUZ-561.md`
  - `/mnt/d/JAVA/knowledge/tiandao/99-generated/multica/issues/FUZ-562.md`
  - `/mnt/d/JAVA/knowledge/tiandao/99-generated/multica/issues/FUZ-564.md`
  - `/mnt/d/JAVA/knowledge/tiandao/99-generated/governance/external-links.md`
- 关键链接存在：
  - `FUZ-562`：`https://mi.feishu.cn/wiki/FC53w6cJviMJfrkPL4WcfnadnMg`
  - `FUZ-561`：`https://mi.feishu.cn/docx/BgWjdUX0OoxNuXx8YUdcwFxHncd`

## 风险与后续

- 当前生成区为自动覆盖区，符合“不写人工区”的规约。
- 后续若 Multica 新增状态，需要同步更新 `ISSUE_STATUSES`。
- 建议将本次结果写回 `FUZ-564` comment，作为 Phase 3 完成证据。
