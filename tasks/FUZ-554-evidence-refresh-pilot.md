# FUZ-554-M 证据快照刷新试点

## 背景

`FUZ-554` 已连续产生多个阶段 run，早期 evidence index 和 review packet 已不能代表当前全量状态。需要刷新一份最新全量证据快照。

## 目标

生成当前 `FUZ-554*` 全量 evidence index、review packet、patch summary 和 toolchain verification report。

## 交付物

- `runs/FUZ-554-evidence-refresh-pilot/index.md`
- `runs/FUZ-554-evidence-refresh-pilot/review-packet.md`
- `runs/FUZ-554-evidence-refresh-pilot/patch-summary.md`
- `runs/FUZ-554-evidence-refresh-pilot/verification-report.md`
- `runs/FUZ-554-evidence-refresh-pilot/stage-report.md`

## 验收标准

- 全量 index 包含当前 `FUZ-554*` runs
- review packet 显示核心证据完整度
- patch summary 同时包含 tracked 和 untracked
- toolchain verification 通过
- 不访问 Multica，不写远端，直到 standing policy 回写阶段

## 验证命令

```bash
cd /home/user/JAVA/ai/ai-loop
test -s runs/FUZ-554-evidence-refresh-pilot/index.md
test -s runs/FUZ-554-evidence-refresh-pilot/review-packet.md
test -s runs/FUZ-554-evidence-refresh-pilot/patch-summary.md
test -s runs/FUZ-554-evidence-refresh-pilot/verification-report.md
rg -n "FUZ-554-evidence-refresh-pilot|Runs with core evidence|Tracked Changed Files|patch-summary" runs/FUZ-554-evidence-refresh-pilot/*.md
```
