# FUZ-554：AI 工作编排证据链建设

## 案例类型

基础设施建设

## 问题

团队使用 AI 助手效率提升，但存在问题：
- 聊天记录不可审计
- "已完成"没有证据
- 失败原因不结构化
- 状态更新靠感觉
- 经验散在窗口里

需要建立统一的 AI 工作编排系统。

## 解决方案

建设 Multica × ai-loop 先锋实践，分阶段推进：

### Phase A：可审计单任务闭环

- 建立本地执行引擎 ai-loop
- 定义 core evidence：summary、stage-report、comment-draft
- 证明单个 issue 可以生成完整证据链

### Phase B：结构化 evidence 标准

- 统一 evidence.json / evidence.md 格式
- 增加 extended evidence：patch-summary、review-packet、verification-report
- 建立 strict evidence gate

### Phase C：Multica Loop 组织层

- 建立状态机：intake → clarify → planned → dry_run_ready → running → evidence_ready → review_ready → done
- 建立元数据合约：pipeline_status、review_verdict、latest_run_id、strict_gate、blocked_reason
- 建立 Agent Crew 机组模型：黑墙（调度）、顾实（执行）、裴衡（复核）、测真（验证）、简辞（记录）、人类（决策）
- 建立 state gate：检查 state-evaluation 和 metadata-draft

## 关键成果

- 22 个本地 run，全部具备 core evidence
- Strict evidence gate 和 state metadata gate 验证通过
- 完整技术分享材料和彩排
- 飞书文档：https://feishu.cn/wiki/TrvIwuNCRiC8xGkdSRwcl9JJn8c

## 经验教训

### 做对了什么

✅ **先治理，后自动化**：先定义门禁和边界，再考虑智能调度  
✅ **先 evidence，后智能调度**：先保证有证据，再优化流程  
✅ **先本地，后远端**：先在本地验证，再考虑回写  
✅ **单步提交**：每个功能单独提交，便于复盘  
✅ **彩排预检**：分享前彩排，确保命令可用

### 踩过的坑

❌ **scope 混合**：一开始工作树包含多个改动，Phase 23 用 scope split 拆分  
❌ **证据不全**：早期 run 缺少 state evidence，Phase 44 统一刷新  
❌ **频率限制**：飞书写入过快，需要等待间隔

### 可复用模式

- **Evidence first**：每个 run 必须有 summary、stage-report、comment-draft
- **Gate driven**：用门禁保证质量，而不是口头检查
- **Review packet**：统一复核入口，便于人工决策
- **State machine**：明确状态转换，避免即兴判断
- **Agent crew**：抽象角色和具体处理者解耦

## 后续演进

- Phase D：项目记忆，沉淀架构约束、决策记录、踩坑经验
- Phase E：受控回写与多角色协作
- Phase F：团队分享与复制，全员接入 Multica Loop

## 适用场景

所有需要 AI 工作编排的项目都可以参考 FUZ-554 的模式：

- 定义 evidence 标准
- 建立门禁验证
- 状态机驱动
- 机组路由
- 人控回写

---

**Issue**：FUZ-554  
**Runs**：22 个  
**状态**：Phase C 已完成，Phase D 进行中  
**更新时间**：2026-06-16
