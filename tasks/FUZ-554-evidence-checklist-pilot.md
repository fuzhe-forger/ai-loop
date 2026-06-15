# FUZ-554-D 证据标准化试点

## 背景

`FUZ-554` 已形成元流程、文档型和脚本型三个低风险试点。下一步需要让每次案例复盘的证据更加标准化，减少人工翻找成本。

## 目标

新增一个本地 evidence checklist 脚本，根据 `runs/<run-id>/` 生成证据清单，帮助人工复核案例是否具备 summary、stage report、comment draft、writeback 记录和下一步判断。

## 交付物

- `scripts/evidence-checklist.sh`
- `docs/ai-work-orchestration/05-case-playbook.md` 补充证据清单用法
- `runs/FUZ-554-evidence-checklist-pilot/` 记录本轮证据

## 验收标准

- 脚本支持 `--run-id <run-id>` 输出 Markdown 清单
- 脚本支持 `--output <file>` 写入本地文件
- 缺少 run 目录时返回非零退出
- 脚本不访问 Multica，不写远端
- `bash -n scripts/evidence-checklist.sh` 通过

## 验证命令

```bash
cd /home/user/JAVA/ai/ai-loop
bash -n scripts/evidence-checklist.sh
./scripts/evidence-checklist.sh --run-id FUZ-554-script-policy-help-pilot
./scripts/evidence-checklist.sh --run-id FUZ-554-script-policy-help-pilot --output runs/FUZ-554-evidence-checklist-pilot/checklist.md
test -s runs/FUZ-554-evidence-checklist-pilot/checklist.md
```

## 安全边界

- 只读本地 `runs/` 目录
- 只在显式 `--output` 时写本地文件
- 不读取 Multica issue
- 不写 Multica comment/status
- 不 push、不 commit、不创建 MR
