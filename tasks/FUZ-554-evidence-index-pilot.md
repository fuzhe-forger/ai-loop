# FUZ-554-E 跨 run 证据索引试点

## 背景

`FUZ-554` 已产生多个 run 证据包。单个 checklist 能检查一个 run，但团队复盘时还需要快速查看同一案例下多个 run 的整体证据状态。

## 目标

新增本地 evidence index 脚本，按 glob pattern 汇总多个 `runs/` 目录的 summary、stage report、comment draft 和 writeback 状态。

## 交付物

- `scripts/evidence-index.sh`
- `docs/ai-work-orchestration/05-case-playbook.md` 补充多 run 索引用法
- `runs/FUZ-554-evidence-index-pilot/index.md`
- `runs/FUZ-554-evidence-index-pilot/stage-report.md`

## 验收标准

- 脚本支持 `--pattern <glob>` 输出 Markdown 表格
- 脚本支持 `--output <file>` 写入本地文件
- 无匹配 run 时返回非零退出
- 脚本不访问 Multica，不写远端
- `bash -n scripts/evidence-index.sh` 通过

## 验证命令

```bash
cd /home/user/JAVA/ai/ai-loop
bash -n scripts/evidence-index.sh
./scripts/evidence-index.sh --pattern 'FUZ-554*'
./scripts/evidence-index.sh --pattern 'FUZ-554*' --output runs/FUZ-554-evidence-index-pilot/index.md
test -s runs/FUZ-554-evidence-index-pilot/index.md
```

## 安全边界

- 只读本地 `runs/` 目录
- 只在显式 `--output` 时写本地文件
- 不读取 Multica issue
- 不写 Multica comment/status
- 不 push、不 commit、不创建 MR
