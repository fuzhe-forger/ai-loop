# FUZ-554-C 脚本型真实低风险试点

## 背景

`FUZ-554` 已完成元流程案例、文档型试点和总入口索引。下一步选择一个真实但低风险的脚本增强任务，验证“本地脚本改动 → 本地验证 → 证据沉淀”的闭环。

## 目标

为 `scripts/multica-loop.sh` 增加本地 `--policy-help` 入口，让使用者无需触发 Multica 网络读取，就能理解三种状态策略和远端写入边界。

## 交付物

- `scripts/multica-loop.sh` 支持 `--policy-help`
- `docs/ai-work-orchestration/05-case-playbook.md` 引用该本地自查入口
- `runs/FUZ-554-script-policy-help-pilot/` 记录试点证据

## 验收标准

- `./scripts/multica-loop.sh --policy-help` 不需要 `--issue` / `--repo`
- `--policy-help` 不访问 Multica 网络
- 输出包含 `conservative`、`validation`、`no-status`
- 输出说明 comment/status 写入必须显式开关
- `bash -n scripts/multica-loop.sh` 通过

## 验证命令

```bash
cd /home/user/JAVA/ai/ai-loop
bash -n scripts/multica-loop.sh
./scripts/multica-loop.sh --policy-help
./scripts/multica-loop.sh --policy-help | rg "conservative|validation|no-status|--write-comment|--write-status"
```

## 安全边界

- 只改本地脚本帮助能力和文档
- 不读取 Multica issue
- 不写 Multica comment/status
- 不 push、不 commit、不创建 MR
