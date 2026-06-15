# FUZ-554-Q Share Refresh Pilot

## 背景

`FUZ-554` 已从文档型试点推进到真实代码门禁试点，当前本地已有 17 个 `FUZ-554*` run。原一页式分享稿仍停留在 13 个 run / 11 个 writeback 的旧口径，且候选池仍推荐已经完成的任务。

## 目标

刷新 `FUZ-554` 分享包和案例入口，让它准确反映当前阶段：Phase 19 截止 17 个 run 全部具备 core evidence，16 个 run 已完成远端 comment 回写，真实代码门禁已覆盖 patch summary、scope check、review packet include patch summary 和 strict evidence gate。本恢复任务新增 Phase 20 run 后，当前本地 `FUZ-554*` run 将变为 18 个。

## Scope

允许修改：

- `docs/ai-work-orchestration/share/FUZ-554-one-page.md`
- `docs/ai-work-orchestration/README.md`
- `docs/ai-work-orchestration/cases/FUZ-554/README.md`
- `docs/ai-work-orchestration/07-next-code-candidates.md`
- `docs/ai-work-orchestration/reports/2026-06-15-phase-20-share-refresh.md`
- `runs/FUZ-554-share-refresh-pilot/`
- `tasks/FUZ-554-share-refresh-pilot.md`

## Out of scope

- 不读取 Multica issue
- 不修改 Multica status
- 不 push、不 commit、不创建 MR
- 不访问生产系统
- 不自动执行远端 comment 回写

## 验收标准

- 一页式分享稿更新为 Phase 19 截止 17 个 run、16 个 writeback，并说明 Phase 20 恢复后当前 18 个本地 run 的口径。
- 分享稿覆盖最新真实代码门禁：patch summary、scope check、review packet include patch summary、strict evidence gate。
- 候选池不再推荐已完成的 A/B/D 作为下一步默认项。
- 总入口和案例复盘能引导读者查看 Phase 19/20 与分享包。
- Phase 20 run 具备 core evidence：`summary.md`、`stage-report.md`、`multica-comment.md`。
- strict verification 对 `FUZ-554*` 通过。

## 验证命令

```bash
test -s docs/ai-work-orchestration/share/FUZ-554-one-page.md
test -s docs/ai-work-orchestration/reports/2026-06-15-phase-20-share-refresh.md
rg -n "17 个 run|18 个|16 个 run|Strict Evidence Gate|review packet|patch summary|scope check" docs/ai-work-orchestration/share/FUZ-554-one-page.md
rg -n "Phase 20|FUZ-554-one-page|17 个 run" docs/ai-work-orchestration/README.md docs/ai-work-orchestration/cases/FUZ-554/README.md
bash -n scripts/verify-toolchain.sh
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --strict --output runs/FUZ-554-share-refresh-pilot/verification-report.md
```
