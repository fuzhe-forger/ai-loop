# 正式演示文稿内容草案

## 说明

这份文档是可直接制作 PPT 的页面内容。每页只放上屏文字和图示说明，讲法见 `speaker-notes.md`。

---

## 01 标题页

**标题**
从 AI 编码助手到可治理的 AI 工作编排

**副标题**
Multica × ai-loop 先锋实践

**页脚**
Local first · Evidence first · Human in command

**图示**
左：聊天式 AI；右：任务 → 执行 → 证据 → 复核 → 记忆

---

## 02 一句话终局

**标题**
终局：AI 工程团队操作系统

**正文**
- 人定义目标、边界和验收
- AI 负责拆解、执行、举证、复核
- 系统把每一步变成可追踪事实

**图示**
```text
Human: Goal / Boundary / Acceptance
AI:    Plan / Execute / Evidence / Review
System: Trace / Gate / Memory
```

---

## 03 为什么需要工作编排

**标题**
单个 AI 助手很快，但不可治理

**正文**
- 聊天记录不可审计
- “已完成”没有证据
- 失败原因不结构化
- 状态更新靠感觉
- 经验散在窗口里

**对比表**
| 单次对话 | 工程闭环 |
|---|---|
| 回答 | Artifact |
| 口头完成 | Evidence |
| 手动复盘 | Review Packet |
| 即兴状态 | Policy Gate |

---

## 04 系统分层

**标题**
三层事实源 + 两层能力

**正文**
- Multica：任务事实源
- Multica Loop：组织与治理层
- ai-loop：本地执行事实源
- Agent Network：能力角色层
- Artifacts & Memory：知识沉淀层

**图示**
```text
Multica
  ↓
Multica Loop
  ↓
ai-loop
  ↓
Agent Network
  ↓
Artifacts & Memory
```

---

## 05 设计原则

**标题**
先治理，后自动化

**正文卡片**
- Local first
- Evidence first
- Human in command
- Explicit side effects
- Small loop before big loop

**强调句**
自动化不是目标，可控的工程闭环才是目标。

---

## 06 FUZ-554 案例

**标题**
从一个 issue 到一条可复核证据链

**正文**
- issue → task.md
- run → summary / stage report
- patch → scope check
- review → review packet
- strict gate → core evidence completeness
- state gate → state + metadata evidence

**数字**
- 22 个本地 run
- 22/22 core evidence 完整
- strict gate + state gate 通过

---

## 07 Evidence 是事实层

**标题**
AI 说完成不算，Evidence 才算

**Core Evidence**
- `summary.md`
- `stage-report.md`
- `multica-comment.md`

**Extended Evidence**
- `patch-summary.md`
- `review-packet.md`
- `verification-report.md`
- `writeback-summary.md`

**强调句**
Evidence 让 AI 工作可审计、可复核、可分享。

---

## 08 工具链与门禁

**标题**
工具不是主角，门禁才是主角

**正文**
- `collect-evidence.sh`：结构化证据
- `patch-summary.sh`：改动范围
- `review-packet.sh`：人工复核入口
- `verify-toolchain.sh --strict --state-gate`：证据与状态门禁

**流程**
```text
Collect → Summarize → Review → Strict Gate → State Gate → Human Decision
```

---

## 09 黑墙确认：天道经验

**标题**
天道不是代码资产，是编排经验

**正文**
- 不引入 LingTai 代码
- 不复制外部项目
- 复用 Multica 内部编排经验

**可复用经验**
- A2A 协议
- 循环保护
- 任务路由
- Issue Metadata
- 任务确认规则

---

## 10 机组路由

**标题**
从 `next_actor` 到 `assigned_actor`

**正文**
- 状态机输出抽象下一角色
- 机组模型映射到具体 agent
- Review Packet 展示 `Assigned Actor`

**路由表**
| next_actor | assigned_actor |
|---|---|
| `execution_agent` | 顾实 |
| `reviewer` | 裴衡 |
| `human` | 人类 |
| `scheduler` | 黑墙 |
| `tester` | 测真 |
| `scribe` | 简辞 |

**流程**
```text
state-evaluation → metadata-draft → route-actor → Assigned Actor
```

---

## 11 红线

**标题**
哪些事情坚决不自动化

**正文**
- 不自动 done
- 不存 token / 密钥
- 不默认远端副作用
- 不直接访问生产
- 不跨 workspace 泄露数据
- 不无限循环
- 不静默失败

**强调句**
安全边界是系统设计，不是事后提醒。

---

## 12 Demo 路径

**标题**
演示 artifacts，不赌 live coding

**步骤**
1. 看 North Star
2. 看 FUZ-554 一页稿
3. 跑 `collect-evidence`
4. 跑 `share-preflight.sh` 或 `verify-toolchain --strict --state-gate`
5. 看 scope split
6. 看 Multica Loop 重构设计

**强调句**
演示目标是证明治理结构稳定，而不是现场赌模型生成。

---

## 13 路线图

**标题**
从单任务闭环到团队级 AI 工作系统

**路线**
- Phase A：可审计单任务闭环
- Phase B：结构化 evidence 标准
- Phase C：Multica Loop 组织层
- Phase D：项目记忆
- Phase E：受控回写与多角色协作
- Phase F：团队分享与复制

**当前位置**
A/B/C 交界：证据链已跑通，组织层开始抽象。

---

## 14 北极星指标

**标题**
不只看自动化率，看治理能力

**Checklist**
- 全程是否有 evidence？
- 人是否能随时接管？
- 失败是否能定位阶段？
- 同类任务第二次是否更稳？
- 远端副作用是否明确？
- 团队是否能只读 artifacts 复盘？

**强调句**
没有治理的自动化，只是更快地失控。

---

## 15 结束页

**标题**
让 AI 的工作变成工程事实

**关键词**
- 可见
- 可验证
- 可接管
- 可复盘
- 可复制

**结束句**
我们不是让 AI 替代工程流程，而是让 AI 进入工程流程。
