# FUZ-554-J 低风险真实代码改动试点：list checks

## 背景

`FUZ-554` 已建立真实代码改动准入门禁。现在选择一个低风险脚本增强作为第一条真实代码改动试点，验证从 patch 到本地验证、证据包、回写草稿的闭环。

## Repo

`/home/user/JAVA/ai/ai-loop`

## Scope

允许修改：

- `scripts/verify-toolchain.sh`
- `docs/ai-work-orchestration/05-case-playbook.md`
- `docs/ai-work-orchestration/reports/2026-06-15-phase-12-real-code-list-checks.md`
- `runs/FUZ-554-real-code-list-checks-pilot/`

## Out of scope

不允许修改：

- 生产配置、密钥、远端仓库配置
- `lib/ai_loop/` 业务实现
- git commit / push / MR
- Multica status

## 目标

为 `scripts/verify-toolchain.sh` 增加 `--list-checks`，让使用者在不读取 `runs/` 的情况下查看工具链 smoke check 列表。

## Acceptance criteria

- `./scripts/verify-toolchain.sh --list-checks` 可直接运行
- `--list-checks` 不要求存在匹配 run
- 输出包含 `multica-loop.sh`、`evidence-checklist.sh`、`evidence-index.sh`、`review-packet.sh`
- 常规 `verify-toolchain` 仍然通过
- 不访问 Multica，不写远端

## Verification command

```bash
cd /home/user/JAVA/ai/ai-loop
bash -n scripts/verify-toolchain.sh
./scripts/verify-toolchain.sh --list-checks
./scripts/verify-toolchain.sh --list-checks | rg "multica-loop.sh|evidence-checklist.sh|evidence-index.sh|review-packet.sh"
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --output runs/FUZ-554-real-code-list-checks-pilot/verification-report.md
test -s runs/FUZ-554-real-code-list-checks-pilot/verification-report.md
```

## Approval policy

- 本地文档、脚本、证据文件：允许执行
- Multica 阶段性 comment 回写：按 standing policy 执行
- git commit / push / MR / 生产访问 / 数据库写入 / 删除：仍需人工确认

## Rollback note

可通过以下命令查看并回退本次脚本改动：

```bash
git diff -- scripts/verify-toolchain.sh
git restore -- scripts/verify-toolchain.sh
```
