# Phase 79：Obsidian 写回摘要同步修复

## Summary

本阶段在用户审批后执行真实 Obsidian generated sync，并修复生成 run 详情页时展示旧 `stage-report.md` 远端写入状态的问题。

## Scope

- Vault generated target: `/mnt/d/JAVA/knowledge/tiandao/99-generated`
- Run ID: `FUZ-554-real-multica-loop-gated-20260622-142303`
- Remote side effect: Obsidian generated files write only
- Not performed: Multica status writeback, Multica metadata writeback, Feishu write, Git remote operation, deployment

## Finding

首次真实同步成功写入 `99-generated`，但验证发现 run 详情页中的 `## Remote Writes` 段来自早期 `stage-report.md`，仍显示：

- `Write comment requested: false`
- `Comment written: false`

这与最新 `writeback-summary.md` 中的真实结果不一致。

## Fix

- `scripts/obsidian-sync.sh`：run 详情页新增 `## Writeback Summary` 段，直接读取最新 `writeback-summary.md`。
- `scripts/obsidian-sync.sh`：嵌入 `stage-report.md` 时省略旧 `## Remote Writes` 段，并提示以最新 `Writeback Summary` 为准。

## Verification

真实同步命令：

```bash
DRY_RUN=false ./scripts/obsidian-sync.sh
```

验证结果：

- Generated run detail: `/mnt/d/JAVA/knowledge/tiandao/99-generated/loop/runs/FUZ-554-real-multica-loop-gated-20260622-142303.md`
- Generated index: `/mnt/d/JAVA/knowledge/tiandao/99-generated/loop/runs-index.md`
- Detail page includes: `Write comment requested: true`
- Detail page includes: `Comment written: true`
- Detail page includes comment ID: `3acf2bab-52d6-41be-b800-5c1e82c5e65b`
- Stage report stale remote-write section is replaced with an authority note.

## Side Effects

- Obsidian generated sync: completed with explicit user approval.
- Multica writes in this phase: none.
- Feishu writes: none.
- Git commit/push: none.

## Next Decision

后续如继续推进，需要单独审批：

1. 是否创建 gate-policy exception。
2. 是否补齐 requirement/deliverable evidence。
3. 是否允许 Multica status 或 metadata 写回。
