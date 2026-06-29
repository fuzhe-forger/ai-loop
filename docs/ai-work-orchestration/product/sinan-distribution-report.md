# 司南 v2 分发报告

## 分发目标

让本地所有窗口和 Agent 默认按司南方案执行：任务分级、Loop、证据、计时、副作用门禁、外部写回/readback、Token 使用率治理和 handoff。

## 已分发位置

| 目标 | 路径 | 状态 |
|---|---|---|
| Codex Skill | `/home/user/.codex/skills/sinan/SKILL.md` | 已创建 |
| Agents Skill | `/home/user/.agents/skills/sinan/SKILL.md` | 已同步 |
| Claude Skill | `/home/user/.claude/skills/sinan/SKILL.md` | 已同步 |
| Claude Agent | `/home/user/.claude/agents/sinan-orchestrator.md` | 已创建 |
| 全局 AGENTS | `/home/user/AGENTS.md` | 已写入 SINAN_GLOBAL block |
| Claude 全局规则 | `/home/user/.claude/CLAUDE.md` | 已写入 SINAN_GLOBAL block |
| Xcode/IDE Prompt | `docs/ai-work-orchestration/product/ide-prompts/sinan-xcode-agent-prompt.md` | 已生成 |
| 使用报告 | `docs/ai-work-orchestration/product/sinan-v2-agent-usage-report.md` | 已生成 |

## 验证命令

```bash
python3 /home/user/.codex/skills/.system/skill-creator/scripts/quick_validate.py /home/user/.codex/skills/sinan
python3 /home/user/.codex/skills/.system/skill-creator/scripts/quick_validate.py /home/user/.agents/skills/sinan
python3 /home/user/.codex/skills/.system/skill-creator/scripts/quick_validate.py /home/user/.claude/skills/sinan
rg -n "SINAN_GLOBAL_START|司南|Sinan" /home/user/AGENTS.md /home/user/.claude/CLAUDE.md /home/user/.claude/agents/sinan-orchestrator.md
```

## 使用建议

主路径是自动适配，不要求新窗口粘贴提示：Codex 通过全局 instructions/AGENTS 和 `sinan` Skill 自动加载，Claude 通过 `CLAUDE.md`/Claude Agent/Skill 自动加载，常用工作区通过 `AGENTS.md`、`.cursorrules`、`.windsurfrules` 自动继承。

`ide-prompts/sinan-xcode-agent-prompt.md` 只是 Xcode/未知 IDE 不读取本地规则文件时的兜底提示，不是日常主路径。
