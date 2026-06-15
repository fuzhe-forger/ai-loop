# FUZ-554-P Strict Evidence Gate

## 背景

`FUZ-554` 已经形成多 run 证据链。下一步把“每个 run 是否具备 core evidence”从 review packet 中的人工观察升级为可执行 gate。

## 目标

为 `scripts/verify-toolchain.sh` 增加 `--strict`，要求匹配到的每个 run 都包含 core evidence：`summary.md`、`stage-report.md`、`multica-comment.md`。

## Scope

允许修改：

- `scripts/verify-toolchain.sh`
- `docs/ai-work-orchestration/05-case-playbook.md`
- `docs/ai-work-orchestration/reports/2026-06-15-phase-19-strict-evidence-gate.md`
- `runs/FUZ-554-strict-evidence-gate-pilot/`
- `tasks/FUZ-554-strict-evidence-gate-pilot.md`

## Out of scope

- 不读取 Multica issue
- 不修改 Multica status
- 不 push、不 commit、不创建 MR
- 不访问生产系统

## 验收标准

- `verify-toolchain.sh` 支持 `--strict`。
- strict report 输出 `Strict Evidence Gate` 表格。
- 所有匹配 run 具备 core evidence 时返回 0。
- 任一匹配 run 缺 core evidence 时返回非零。
- 原有非 strict smoke check 行为保持可用。

## 验证命令

```bash
bash -n scripts/verify-toolchain.sh
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --strict --output runs/FUZ-554-strict-evidence-gate-pilot/verification-report.md
rg -n "Strict Evidence Gate|strict evidence gate passed" runs/FUZ-554-strict-evidence-gate-pilot/verification-report.md
mkdir -p /tmp/ai-loop-strict-negative/scripts /tmp/ai-loop-strict-negative/runs/FUZ-554-missing-core
cp scripts/verify-toolchain.sh scripts/multica-loop.sh scripts/evidence-checklist.sh scripts/evidence-index.sh scripts/patch-summary.sh scripts/review-packet.sh /tmp/ai-loop-strict-negative/scripts/
printf '# only summary\n' > /tmp/ai-loop-strict-negative/runs/FUZ-554-missing-core/summary.md
if (cd /tmp/ai-loop-strict-negative && ./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --strict --output /tmp/ai-loop-strict-negative/report.md); then exit 1; else true; fi
```
