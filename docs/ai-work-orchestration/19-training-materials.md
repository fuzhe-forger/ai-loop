# AI 工作编排培训材料

## 培训目标

- 理解 AI 工作编排的价值和原则
- 掌握从 issue 到 evidence 的完整流程
- 能够独立接入新项目到 Multica Loop
- 建立可治理、可审计、可复盘的工作习惯

## 培训对象

- 开发工程师
- 测试工程师
- 项目管理
- 技术 Leader

## 培训时长

- 理论部分：30 分钟
- 实战演练：30 分钟
- 答疑讨论：15 分钟
- 总计：75 分钟

---

## 第一部分：为什么需要 AI 工作编排（10 分钟）

### 现状问题

**场景 1：AI 说完成，但没有证据**
```
开发：ChatGPT 帮我写完了代码
Leader：在哪里？改了什么？
开发：聊天记录没了...
```

**场景 2：失败后无法复盘**
```
开发：AI 改了代码但测试挂了
Leader：为什么挂？改了哪些地方？
开发：不记得了...
```

**场景 3：经验无法复用**
```
新人：这个任务上次怎么做的？
老人：记不清了，你自己试试吧
新人：又踩了一遍同样的坑...
```

### 核心价值

✅ **可审计**：每个 AI 工作都有完整 evidence  
✅ **可复核**：review packet 统一格式  
✅ **可复盘**：失败有原因，成功可复制  
✅ **可治理**：门禁统一，边界清晰  
✅ **可沉淀**：经验进入项目记忆，跨项目复用

### 核心原则

1. **先治理，后自动化**
2. **先 Evidence，后智能调度**
3. **先本地，后远端**
4. **先人控，后策略自动化**

---

## 第二部分：系统架构（10 分钟）

### 三层事实源

```
Multica (任务事实源)
  ↓ issue、状态、评论
Multica Loop (组织与治理层)
  ↓ 编排、证据采集、边界控制
ai-loop (本地执行事实源)
  ↓ task、run、patch、verify、evidence
```

### 核心概念

**Evidence**：
- Core Evidence：summary、stage-report、comment-draft（必需）
- Extended Evidence：patch-summary、review-packet、verification-report（推荐）
- State Evidence：state-evaluation、metadata-draft（Loop 必需）

**Gate**：
- Strict Gate：检查 core evidence
- State Gate：检查 state evidence
- Writeback Gate：检查回写前置条件

**角色**：
- execution_agent (顾实)：执行任务
- reviewer (裴衡)：复核验收
- human (人类)：决策和确认

---

## 第三部分：工作流演示（10 分钟）

### 完整流程

**Step 1: 在 Multica 创建 Issue**
```
标题：更新 XXX 文档
描述：补充 YYY 说明
标签：可执行、低风险
```

**Step 2: 生成本地 Task**
```bash
cat > tasks/FUZ-XXX.md <<TASK
# FUZ-XXX: 更新 XXX 文档

## 目标
补充 YYY 说明

## 范围
- 只改动 docs/XXX.md
- 不涉及代码

## 验收标准
- [ ] 文档清晰易懂
- [ ] Markdown 格式正确
TASK
```

**Step 3: 执行 ai-loop**
```bash
./scripts/multica-loop.sh --issue FUZ-XXX --repo /path
```

**Step 4: 验证 Evidence**
```bash
./scripts/verify-toolchain.sh \
  --case FUZ-XXX \
  --pattern 'FUZ-XXX*' \
  --strict \
  --state-gate
```

**Step 5: 人工复核**
```bash
cat runs/FUZ-XXX-pilot/review-packet.md
```

**Step 6: 回写 Multica（可选）**
```bash
./scripts/writeback-gate.sh --issue FUZ-XXX --type comment
./scripts/multica-loop.sh --issue FUZ-XXX --write-comment
```

### 关键演示点

- 强调 evidence first，不是"AI 说完成"
- 强调 human in command，不是"全自动闭环"
- 强调 local first，不是"先写远端再复盘"
- 强调可治理，不是"单点工具"

---

## 第四部分：实战演练（30 分钟）

### 演练任务

选择一个真实的低风险任务：
- 文档更新
- 配置调整
- 测试用例补充

### 演练步骤

**Step 1: 创建 Issue（5 分钟）**
- 每人在 Multica 创建一个 issue
- 确认标题、描述、标签正确

**Step 2: 编写 Task（5 分钟）**
- 每人生成 task.md
- 包含目标、范围、验收标准

**Step 3: 执行 Dry-Run（10 分钟）**
- 运行 multica-loop.sh
- 生成 evidence
- 验证门禁

**Step 4: 人工复核（5 分钟）**
- 查看 review-packet
- 确认改动范围
- 决定是否回写

**Step 5: 回写和总结（5 分钟）**
- 执行 writeback-gate
- 回写 comment
- 沉淀经验

### 演练检查点

- [ ] Issue 已创建且格式正确
- [ ] Task.md 包含完整信息
- [ ] Evidence 齐全且通过 strict gate
- [ ] Review packet 已复核
- [ ] Writeback gate 通过
- [ ] 经验已沉淀到 memory/

---

## 第五部分：常见问题（10 分钟）

### Q1: 什么任务适合接入？

**适合**：
- 低风险：文档、配置、测试
- 明确范围：改动文件少于 5 个
- 可回滚：不涉及数据库或生产

**不适合**：
- 高风险：生产热修复、数据库迁移
- 模糊需求：需求不明确
- 跨系统：涉及多个系统联动

### Q2: Evidence 不完整怎么办？

```bash
# 查看缺失的 evidence
./scripts/collect-evidence.sh --issue FUZ-XXX --run-id FUZ-XXX-pilot

# 补充缺失文件
cd runs/FUZ-XXX-pilot/
# 手动创建 summary.md / stage-report.md / multica-comment.md

# 重新验证
./scripts/verify-toolchain.sh --case FUZ-XXX --strict --state-gate
```

### Q3: 门禁失败怎么办？

**Strict gate 失败**：
- 补充缺失的 summary / stage-report / comment-draft

**State gate 失败**：
- 运行 `./scripts/refresh-run-evidence.sh` 生成 state evidence

**Writeback gate 失败**：
- 检查 draft 文件是否包含敏感信息
- Metadata 回写需要 `--approved-by`

### Q4: 如何沉淀经验？

```bash
# 成功案例
cat > memory/cases/FUZ-XXX-success.md <<CASE
## 问题
[背景]

## 解决方案
[做法]

## 经验教训
✅ 做对了什么
❌ 踩过的坑
🔄 可复用模式
CASE

# 更新索引
# 编辑 memory/index.json
```

### Q5: 如何跨项目复用？

1. 查询相似案例：`./scripts/memory-query.sh --search "关键词"`
2. 参考架构约束：`./scripts/memory-query.sh --type constraint`
3. 参考验收偏好：`cat memory/review-preferences.md`

---

## 第六部分：答疑讨论（15 分钟）

### 讨论话题

- 团队当前使用 AI 的痛点
- 哪些场景可以先接入
- 如何在团队推广
- 如何衡量效果

### 后续支持

- 文档入口：`docs/ai-work-orchestration/README.md`
- 案例参考：`docs/ai-work-orchestration/share/FUZ-554-one-page.md`
- 技术分享：https://feishu.cn/wiki/TrvIwuNCRiC8xGkdSRwcl9JJn8c
- 接入指南：`docs/ai-work-orchestration/17-onboarding-guide.md`
- 最佳实践：`docs/ai-work-orchestration/18-best-practices.md`

---

## 培训材料清单

### 必备材料

- [ ] 培训 PPT（基于 slides-content.md）
- [ ] 演示环境（ai-loop 仓库 + Multica 测试项目）
- [ ] 演练任务列表（3-5 个低风险任务）
- [ ] 检查清单（纸质或电子）

### 辅助材料

- [ ] 一页式案例：FUZ-554-one-page.md
- [ ] 演示脚本：demo-script.md
- [ ] 接入指南：onboarding-guide.md
- [ ] 最佳实践：best-practices.md

---

## 培训效果评估

### 即时评估

培训结束时，学员应能回答：
- [ ] AI 工作编排的核心价值是什么？
- [ ] Evidence 包含哪些必需文件？
- [ ] 门禁有哪几种？分别检查什么？
- [ ] 如何判断任务是否适合接入？

### 实战评估

培训后 1 周，学员应能：
- [ ] 独立创建 Multica issue
- [ ] 独立编写 task.md
- [ ] 独立执行 multica-loop.sh
- [ ] 独立验证 evidence 和门禁
- [ ] 独立沉淀经验到 memory/

### 持续评估

培训后 1 个月，团队应：
- [ ] 至少完成 3 个接入案例
- [ ] Evidence 完整率 95%+
- [ ] Gate 通过率 90%+
- [ ] 沉淀至少 5 个经验案例

---

## 培训后行动

### 第 1 周

- [ ] 选择 1-2 个低风险试点任务
- [ ] 在导师指导下完成首次接入
- [ ] 沉淀首个经验案例

### 第 2-4 周

- [ ] 独立完成 2-3 个接入任务
- [ ] 补充项目记忆（决策记录、踩坑记录）
- [ ] 在团队内分享经验

### 第 2 个月

- [ ] 成为导师，指导新人
- [ ] 优化团队流程
- [ ] 推广到更多项目

---

**培训材料版本**：v1.0  
**生成时间**：2026-06-16  
**适用范围**：所有需要接入 Multica Loop 的团队
