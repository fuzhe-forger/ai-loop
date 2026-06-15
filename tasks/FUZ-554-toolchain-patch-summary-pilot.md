# FUZ-554-L Patch Summary 接入工具链自检

## 背景

`FUZ-554-K` 已新增 `scripts/patch-summary.sh`。为了避免新脚本游离于工具链之外，需要将它接入 `verify-toolchain.sh` 的 smoke check。

## 目标

更新 `scripts/verify-toolchain.sh`，把 `patch-summary.sh` 纳入 `--list-checks` 和常规自检报告。

## Scope

允许修改：

- `scripts/verify-toolchain.sh`
- `docs/ai-work-orchestration/reports/2026-06-15-phase-14-toolchain-patch-summary.md`
- `runs/FUZ-554-toolchain-patch-summary-pilot/`

## Out of scope

- 不修改 `patch-summary.sh` 行为
- 不访问 Multica issue
- 不修改 Multica status
- 不 push、不 commit、不创建 MR

## 验收标准

- `./scripts/verify-toolchain.sh --list-checks` 输出包含 `patch-summary.sh`
- 常规自检报告包含 `bash -n scripts/patch-summary.sh`
- 常规自检报告包含 `patch-summary --help`
- 常规自检不依赖工作树必须有 diff
- 不访问 Multica，不写远端，直到 standing policy 回写阶段

## 验证命令

```bash
cd /home/user/JAVA/ai/ai-loop
bash -n scripts/verify-toolchain.sh
./scripts/verify-toolchain.sh --list-checks | rg "patch-summary.sh"
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --output runs/FUZ-554-toolchain-patch-summary-pilot/verification-report.md
rg -n "patch-summary" runs/FUZ-554-toolchain-patch-summary-pilot/verification-report.md
```

## Rollback note

```bash
git diff -- scripts/verify-toolchain.sh
git restore -- scripts/verify-toolchain.sh
```
