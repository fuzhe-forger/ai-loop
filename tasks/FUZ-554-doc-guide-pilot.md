# FUZ-554-B 文档型真实低风险试点

## 背景

`FUZ-554` 已完成元流程案例复盘。下一步选择一个真实但低风险的文档改进任务，验证从任务定义、文档产出、本地验证到分享材料沉淀的完整闭环。

## 目标

新增一份面向团队复用的 AI Loop 案例执行指南，帮助后续成员按统一方式选择低风险试点、定义边界、生成证据并完成复盘。

## 交付物

- `docs/ai-work-orchestration/05-case-playbook.md`
- 更新 `docs/ai-work-orchestration/cases/FUZ-554/README.md`，引用该指南
- 更新 `docs/ai-work-orchestration/logbook.md`，记录本次文档型试点

## 验收标准

- 指南包含适用场景、输入、执行步骤、证据包、状态策略和复盘输出
- 指南明确默认只读、显式授权、证据优先原则
- 本地验证命令通过
- 不写 Multica，不改远端状态

## 验证命令

```bash
cd /home/user/JAVA/ai/ai-loop
bash -n scripts/multica-loop.sh
test -s docs/ai-work-orchestration/05-case-playbook.md
test -s docs/ai-work-orchestration/cases/FUZ-554/README.md
```

## 安全边界

- 仅修改本地文档和本地任务文件
- 不执行远端 comment/status 写入
- 不 push、不 commit、不创建 MR
- 不访问生产系统
