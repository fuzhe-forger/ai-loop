# FUZ-554-H 工具链自检试点

## 背景

`FUZ-554` 已沉淀多个本地辅助脚本：Multica wrapper、evidence checklist、evidence index、review packet。为了让后续复用更稳定，需要一个总验证入口。

## 目标

新增本地工具链自检脚本，串联验证现有 helper scripts 的语法和关键本地功能，生成 verification report。

## 交付物

- `scripts/verify-toolchain.sh`
- `docs/ai-work-orchestration/05-case-playbook.md` 补充工具链自检用法
- `runs/FUZ-554-toolchain-verify-pilot/verification-report.md`
- `runs/FUZ-554-toolchain-verify-pilot/stage-report.md`

## 验收标准

- 脚本能验证 helper scripts 的 `bash -n`
- 脚本能验证 `--policy-help`、checklist、index、review packet
- 脚本支持 `--case`、`--pattern`、`--output`
- 无匹配 run 时返回非零退出
- 不访问 Multica，不写远端

## 验证命令

```bash
cd /home/user/JAVA/ai/ai-loop
bash -n scripts/verify-toolchain.sh
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*'
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --output runs/FUZ-554-toolchain-verify-pilot/verification-report.md
test -s runs/FUZ-554-toolchain-verify-pilot/verification-report.md
```

## 安全边界

- 只读本地脚本和 `runs/` 目录
- 只在显式 `--output` 时写本地文件
- 不读取 Multica issue
- 不写 Multica comment/status
- 不 push、不 commit、不创建 MR
