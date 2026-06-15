# FUZ-554-F 复核包生成试点

## 背景

`FUZ-554` 已具备多个 run 的证据索引，但团队复核时仍需要一份更面向人的 review packet：包含范围、证据摘要、复核问题和建议决策。

## 目标

新增本地 review packet 脚本，基于 run pattern 生成案例级复核包，帮助人类快速判断是否可分享、是否需要补证据、是否需要远端回写。

## 交付物

- `scripts/review-packet.sh`
- `docs/ai-work-orchestration/05-case-playbook.md` 补充复核包用法
- `runs/FUZ-554-review-packet-pilot/review-packet.md`
- `runs/FUZ-554-review-packet-pilot/stage-report.md`

## 验收标准

- 脚本支持 `--case <case-id>` 和 `--pattern <glob>` 输出 Markdown 复核包
- 脚本支持 `--output <file>` 写入本地文件
- 无匹配 run 时返回非零退出
- 脚本不访问 Multica，不写远端
- `bash -n scripts/review-packet.sh` 通过

## 验证命令

```bash
cd /home/user/JAVA/ai/ai-loop
bash -n scripts/review-packet.sh
./scripts/review-packet.sh --case FUZ-554 --pattern 'FUZ-554*'
./scripts/review-packet.sh --case FUZ-554 --pattern 'FUZ-554*' --output runs/FUZ-554-review-packet-pilot/review-packet.md
test -s runs/FUZ-554-review-packet-pilot/review-packet.md
```

## 安全边界

- 只读本地 `runs/` 目录
- 只在显式 `--output` 时写本地文件
- 不读取 Multica issue
- 不写 Multica comment/status
- 不 push、不 commit、不创建 MR
