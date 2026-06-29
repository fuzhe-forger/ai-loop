# 司南 v2 Agent 使用报告

## 1. 目的

本报告用于把司南 v2 的执行方案分发给本地所有 AI 窗口和 Agent。任何窗口只要读到本报告或 `sinan` Skill，就应按同一套流程执行：任务分级、Loop、证据、计时、副作用门禁、外部写回 readback、Token 使用率治理和 handoff。

## 2. 当前状态

| 项 | 状态 | 证据 |
|---|---|---|
| v2 本地验收 | PASSED | `runs/sinan-v2-loop-20260624-143155/v2-acceptance.md` |
| v2 差距审计 | 本地能力无缺口 | `runs/sinan-v2-loop-20260624-143155/v2-gap-audit-after.md` |
| 飞书写回/readback | PASSED | `runs/sinan-v2-writeback-readback-20260624-150135/writeback-summary.md` |
| Multica 写回/readback | PASSED | `runs/sinan-v2-writeback-readback-20260624-150135/writeback-summary.md` |
| CodeGraph | 已初始化 | `.codegraph/` |
| Skill 分发 | Codex / Agents / Claude | `~/.codex/skills/sinan`、`~/.agents/skills/sinan`、`~/.claude/skills/sinan` |

## 3. 所有 Agent 的默认行为

### 3.1 先判断是否启用司南

满足任一条件，应主动启用司南：

- 用户提到 `司南`、`Loop`、`继续推进`、`直到需要审批`、`按系统流程执行`。
- 任务多步骤、长时间、需要跨窗口交接。
- 任务涉及 Feishu、Multica、Obsidian、CodeGraph、外部写回或 readback。
- 任务需要估时、验收、证据、风险控制或 Token 使用率治理。

简单低风险问答可走 fast path，但仍需保持简洁、事实准确。

### 3.2 Loop 流程

1. 明确目标和验收标准。
2. 判断任务等级和副作用。
3. 开工前估时。
4. 列出外部副作用；高风险/未授权副作用必须停下等人类确认。
5. 执行最小可验收切片。
6. 运行验证。
7. 记录 evidence。
8. 关闭计时，报告真实耗时和误差。
9. 判断下一轮：继续、停下、或等待审批。

### 3.3 必须停下的场景

- 部署、生产访问。
- 远端 Git push / merge / MR merge。
- 删除、归档、权限变更。
- 飞书/Multica 写入目标不明确。
- writeback gate 失败。
- 验收标准不清。
- 用户未授权的新增外部副作用。

## 4. 本地命令入口

```bash
cd /home/user/JAVA/ai/ai-loop

# 统一入口
./scripts/sinan.sh help

# 流程建议
./scripts/sinan.sh flow-advisor --task tasks/<task>.md

# Token 审计
./scripts/sinan.sh token-audit --run-id <run-id>

# v2 验收
./scripts/sinan.sh v2-acceptance --run-id <run-id>

# 运营看板
./scripts/sinan.sh ops-dashboard --pattern "sinan-*"

# 工具链验证
./scripts/verify-toolchain.sh --case FUZ-554 --pattern FUZ-554-real-multica-loop-gated-20260622-142303 --strict --state-gate
```

## 5. 外部写回标准

飞书/Multica 写回必须满足：

1. 本地草稿存在。
2. approval boundary 有记录。
3. writeback gate 通过或明确说明为什么被拦截。
4. 写入成功。
5. readback 成功。
6. summary 中给出 URL/ID、marker、证据路径。

已验证样例：

- 飞书文档：`https://feishu.cn/wiki/OGPgwcb8xiMt9ikZuJBcPGAZnDg`
- Multica issue：`FUZ-580`
- 证据：`runs/sinan-v2-writeback-readback-20260624-150135/writeback-summary.md`

## 6. Token 使用率治理

所有窗口遵守：

- 大文件先 `rg`/摘要，不直接整读。
- readback/fetch/after JSON 先摘要字段。
- evidence 用路径引用，不复制全文。
- 长任务阶段性写 md/handoff，新窗口从 artifact 继续。
- 审批、安全、部署、删除、权限边界不压缩关键内容。

详细规约：`docs/ai-work-orchestration/29-token-efficiency.md`。

## 7. 分发位置

| 目标 | 路径 | 用途 |
|---|---|---|
| Codex Skill | `~/.codex/skills/sinan/SKILL.md` | Codex 自动触发司南流程 |
| Agents Skill | `~/.agents/skills/sinan/SKILL.md` | 通用本地 Agent 共享 |
| Claude Skill | `~/.claude/skills/sinan/SKILL.md` | Claude 本地可读技能 |
| Claude Agent | `~/.claude/agents/sinan-orchestrator.md` | Claude 子 Agent/角色入口 |
| 全局 AGENTS | `/home/user/AGENTS.md` | 所有窗口继承的默认规则 |
| Claude 全局规则 | `~/.claude/CLAUDE.md` | Claude Code 全局规则 |

## 8. 自动适配与兜底提示

主路径：新 Codex/Claude/常用 IDE 工作区应自动读取全局规则和 `sinan` Skill，不需要用户粘贴。

兜底：若某个未知 IDE 不读取本地规则文件，再使用 `ide-prompts/sinan-xcode-agent-prompt.md`。

## 9. 当前边界

司南 v2 当前是本地能力闭环，不代表可以自动部署、自动合并 MR、自动生产访问或自动决定业务验收。高风险动作仍由人类最终确认。
