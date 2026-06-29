# Multica Loop 全流程验证任务

## 目标

验证 `scripts/multica-loop.sh` 能否正确完成：
1. 将任务描述转换为本地 task.md
2. 执行 ai-loop dry-run
3. 生成 state-evaluation
4. 生成 metadata-draft
5. 生成 comment-draft
6. 生成完整 evidence 链路

## 任务内容

在 `docs/ai-work-orchestration/` 下新增 `14-multica-loop-validation.md`，记录本次验证的流程、输入、输出和结论。

## 验收标准

- 文档包含验证流程说明
- 文档包含关键输出路径
- 文档包含状态推进建议
- 文档格式规范
- 生成完整 core evidence

## 约束

- 不修改功能代码
- 不访问远端系统
- 不执行 git commit
- 只生成本地文档
