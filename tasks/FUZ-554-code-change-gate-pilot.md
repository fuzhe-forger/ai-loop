# FUZ-554-I 真实代码改动准入门禁试点

## 背景

`FUZ-554` 已形成执行、复核、分享和工具链自检样板。下一步进入真实代码改动前，需要先定义准入门禁，避免从低风险样板直接跳到高风险自动化。

## 目标

新增真实代码改动准入门禁文档，明确什么任务可以进入 patch、必须具备哪些输入、哪些动作仍需人工确认。

## 交付物

- `docs/ai-work-orchestration/06-code-change-gate.md`
- 更新 `docs/ai-work-orchestration/05-case-playbook.md`
- `runs/FUZ-554-code-change-gate-pilot/stage-report.md`
- `runs/FUZ-554-code-change-gate-pilot/multica-comment.md`

## 验收标准

- 准入文档包含原则、推荐任务、禁止任务、必备输入、执行流程、状态策略和检查清单
- 明确 dry-run 不等于业务完成
- 明确 commit/push/MR/生产/数据库/删除仍需人工确认
- 本地文件存在性和关键字检查通过
- 不访问 Multica，不写远端，直到 standing policy 回写阶段

## 验证命令

```bash
cd /home/user/JAVA/ai/ai-loop
test -s docs/ai-work-orchestration/06-code-change-gate.md
rg -n "dry-run|git commit|git push|MR|生产|数据库|conservative|review packet" docs/ai-work-orchestration/06-code-change-gate.md
```

## 安全边界

- 仅修改本地文档和本地证据
- 不读取 Multica issue
- 不写 Multica comment/status，直到阶段证据完成后按 standing policy 回写
- 不 push、不 commit、不创建 MR
