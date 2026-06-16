# PPT 页结构：从 AI 编码助手到可治理的 AI 工作编排

## 使用方式

这不是最终 PPT 文件，而是可直接转成幻灯片的页结构。每页包含：标题、核心信息、建议画面、讲者备注。

建议总时长：20–30 分钟。若压缩到 15 分钟，可保留第 1、2、3、4、6、8、10、12、14 页。

---

## Slide 1：标题页

**标题**：从 AI 编码助手到可治理的 AI 工作编排

**副标题**：Multica × ai-loop 先锋实践

**核心信息**：
- 不是展示一个脚本。
- 是展示一种 AI 进入工程体系的控制结构。

**建议画面**：
- 左侧：聊天式 AI 助手。
- 右侧：任务、执行、证据、复核、记忆闭环。

**讲者备注**：
今天不讲“AI 有多聪明”，讲“AI 怎么进入团队工程系统”。

---

## Slide 2：一句话终局

**标题**：终局不是自动化脚本，而是 AI 工程团队操作系统

**核心信息**：
- 人定义目标、边界和验收。
- AI 拆解、执行、举证、复核、沉淀经验。
- 系统把每一步变成可追踪事实。

**建议画面**：
```text
Goal / Boundary / Acceptance  ← Human
Task / Execute / Evidence      ← AI
Trace / Gate / Memory          ← System
```

**讲者备注**：
先把最终形态讲清楚，否则后面的脚本和案例会显得零散。

---

## Slide 3：为什么单个 AI 助手不够

**标题**：AI 执行很快，但工程团队需要可治理

**核心信息**：
- 聊天记录不可审计。
- “已完成”没有证据。
- 失败原因不结构化。
- 状态更新靠感觉。
- 经验散落在窗口里。

**建议画面**：
| 单次对话 | 工程闭环 |
|---|---|
| 回答 | artifact |
| 口头完成 | evidence |
| 手动复盘 | review packet |
| 即兴状态 | policy gate |

**讲者备注**：
问题不是 AI 不够强，而是缺少控制结构。

---

## Slide 4：系统总架构

**标题**：三层事实源 + 两层能力

**核心信息**：
- Multica：任务事实源。
- ai-loop：本地执行事实源。
- Multica Loop：组织与治理层。
- Agent Network：能力角色层。
- Artifacts & Memory：知识沉淀层。

**建议画面**：
```text
Multica Issue / Status / Comment
          ↓
Multica Loop Policy / Routing / Memory
          ↓
ai-loop Task / Run / Verify / Evidence
          ↓
Agent Network Review / Test / Scribe
          ↓
Artifacts & Memory
```

**讲者备注**：
这五层分清楚，后面才不会把任务系统、执行器、智能体和记忆混成一个大脚本。

---

## Slide 5：原则

**标题**：先治理，后自动化

**核心信息**：
- Local first
- Evidence first
- Human in command
- Explicit side effects
- Small loop before big loop

**建议画面**：
五个原则做成横向卡片。

**讲者备注**：
这五条原则决定了我们为什么不默认写状态、不默认 push、不默认部署。

---

## Slide 6：FUZ-554 案例链路

**标题**：从一个 issue 到一条可复核证据链

**核心信息**：
- issue → task.md
- dry-run / run → summary
- patch summary → scope check
- review packet → human review
- strict gate → core evidence completeness
- state gate → state + metadata evidence

**建议画面**：
```text
FUZ-554
  → task
  → run
  → evidence
  → review packet
  → strict gate + state gate
  → share packet
```

**讲者备注**：
FUZ-554 的价值不是某个功能，而是证明这条链路可以跑通。

---

## Slide 7：Evidence 是事实层

**标题**：AI 说完成不算，Evidence 才算

**核心信息**：
Core evidence：
- `summary.md`
- `stage-report.md`
- `multica-comment.md`

Optional evidence：
- `patch-summary.md`
- `review-packet.md`
- `verification-report.md`
- `writeback-summary.md`

**建议画面**：
金字塔：底层 core evidence，上层 review/patch/strict。

**讲者备注**：
我们不是相信 AI 的结论，而是让 AI 的结论必须落到文件和验证结果里。

---

## Slide 8：工具链不是主角，门禁才是主角

**标题**：把口号变成可执行 gate

**核心信息**：
- `collect-evidence.sh`：收集结构化证据。
- `patch-summary.sh`：检查改动范围。
- `review-packet.sh`：给人看的复核入口。
- `verify-toolchain.sh --strict --state-gate`：证据与状态门禁。

**建议画面**：
```text
collect → summarize → review → strict gate → state gate → human decision
```

**讲者备注**：
脚本只是实现，真正的价值是把“该不该继续”变成可判断的门禁。

---

## Slide 9：黑墙确认与天道经验

**标题**：天道不是代码资产，是编排经验

**核心信息**：
- 不引入 LingTai 代码。
- 不复制外部项目。
- 复用 Multica 里的天道经验：A2A、循环保护、任务路由、metadata、任务确认。

**建议画面**：
| 经验 | 用法 |
|---|---|
| A2A | 分派/回收/验收 |
| 循环保护 | 防死锁 |
| Metadata | L1 记忆 |
| 路由矩阵 | 选 agent |
| 任务确认 | 防误执行 |

**讲者备注**：
这里是方向校准：我们自研 Multica Loop，但不从零发明所有组织经验。

---

## Slide 10：红线

**标题**：哪些事情坚决不自动化

**核心信息**：
- 不自动 done。
- 不存 token / 密钥。
- 不默认远端副作用。
- 不直接访问生产。
- 不跨 workspace 泄露数据。
- 不无限循环。
- 不静默失败。

**建议画面**：
红线列表，配“Stop / Gate / Human Approval”图标。

**讲者备注**：
安全边界不是补充说明，而是系统设计的一部分。

---

## Slide 11：现场 Demo 路径

**标题**：演示 artifacts，不赌 live coding

**核心信息**：
1. 看 North Star。
2. 看 FUZ-554 分享稿。
3. 跑 `collect-evidence`。
4. 跑 `share-preflight.sh` 或 `verify-toolchain --strict --state-gate`。
5. 看 scope split。
6. 看 Multica Loop 重构设计。

**建议画面**：
把 `demo-script.md` 的六步做成流程图。

**讲者备注**：
演示目标是稳定地证明治理结构，不是现场赌模型生成代码。

---

## Slide 12：路线图

**标题**：从单任务闭环到团队级 AI 工作系统

**核心信息**：
- Phase A：可审计单任务闭环。
- Phase B：结构化 evidence 标准。
- Phase C：Multica Loop 组织层。
- Phase D：项目记忆。
- Phase E：受控回写与多角色协作。
- Phase F：团队分享与复制。

**建议画面**：
从左到右的路线图。

**讲者备注**：
我们现在在 A/B/C 交界处：已有 evidence 链路，正在抽象组织层。

---

## Slide 13：北极星指标

**标题**：不只看自动化率，看治理能力

**核心信息**：
- 是否全程有 evidence。
- 人是否能随时接管。
- 失败是否能定位阶段。
- 同类任务第二次是否更稳。
- 远端副作用是否明确。
- 团队是否能只读 artifacts 复盘。

**建议画面**：
雷达图或 checklist。

**讲者备注**：
自动化率越高不一定越好；没有治理的自动化只是更快地失控。

---

## Slide 14：结束页

**标题**：让 AI 的工作变成工程事实

**核心信息**：
- 可见
- 可验证
- 可接管
- 可复盘
- 可复制

**建议画面**：
```text
AI Output → Evidence → Review → Decision → Memory
```

**讲者备注**：
最后落到一句话：我们不是让 AI 替代工程流程，而是让 AI 进入工程流程。
