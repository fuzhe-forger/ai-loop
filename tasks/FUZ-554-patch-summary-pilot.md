# FUZ-554-K Patch 证据化试点

## 背景

`FUZ-554` 已完成第一条低风险真实代码改动。下一步需要把 patch 本身也纳入证据体系，让复核者能先看改动范围、文件列表和 diff stat，再决定是否深入查看完整 diff。

## 目标

新增本地 `patch-summary.sh`，基于当前 git diff 生成 Markdown patch summary。

## 交付物

- `scripts/patch-summary.sh`
- `docs/ai-work-orchestration/05-case-playbook.md` 补充 patch summary 用法
- `runs/FUZ-554-patch-summary-pilot/patch-summary.md`
- `runs/FUZ-554-patch-summary-pilot/stage-report.md`

## 验收标准

- 脚本支持 `--base <git-ref>`，默认 `HEAD`
- 脚本支持 `--output <file>` 写入本地文件
- 输出包含 changed files 和 diff stat
- 无 diff 时返回非零退出
- invalid git ref 返回非零退出
- 不访问 Multica，不写远端

## 验证命令

```bash
cd /home/user/JAVA/ai/ai-loop
bash -n scripts/patch-summary.sh
./scripts/patch-summary.sh --base HEAD --output runs/FUZ-554-patch-summary-pilot/patch-summary.md
test -s runs/FUZ-554-patch-summary-pilot/patch-summary.md
rg -n "Changed Files|Diff Stat|Review Questions" runs/FUZ-554-patch-summary-pilot/patch-summary.md
```

## 安全边界

- 只读取本地 git diff 元信息
- 只在显式 `--output` 时写本地文件
- 不读取 Multica issue
- 不写 Multica comment/status，直到阶段证据完成后按 standing policy 回写
- 不 push、不 commit、不创建 MR
