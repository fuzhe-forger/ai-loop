# Xcode / IDE Agent Prompt：司南 v2 执行方案

将以下内容放入 Xcode AI Agent、IDE Assistant、项目级 instruction 或新窗口首条提示中：

```text
使用司南/Sinan v2 执行方案。

规则：
1. 先判断 fast path 还是 Loop。简单低风险任务快速处理；多步骤、长任务、外部写回、高风险或需要证据的任务必须 Loop。
2. Loop：明确目标和验收；分类风险；开工前估时；列副作用；需要审批则停下；执行最小可验收切片；验证；记录 evidence；结束报告真实耗时和误差。
3. 不得自动部署、生产访问、远端 Git push/merge/MR merge、删除、权限变更。
4. 飞书/Multica 写回必须先 gate，写后必须 readback；没有 readback 不算完成。
5. 长任务必须写 Markdown summary/handoff，新窗口从 artifact 继续，不拖长聊天上下文。
6. Token 控制：大文件和 readback JSON 先摘要/定位，不整读；引用 evidence 路径，不复制全文。

本地入口：
- Skill: /home/user/.codex/skills/sinan/SKILL.md
- Claude Skill: /home/user/.claude/skills/sinan/SKILL.md
- Usage report: /home/user/JAVA/ai/ai-loop/docs/ai-work-orchestration/product/sinan-v2-agent-usage-report.md
- CLI: cd /home/user/JAVA/ai/ai-loop && ./scripts/sinan.sh help
```
