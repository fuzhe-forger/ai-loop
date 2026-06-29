# 自动化增强模型

## 目标

在已有的治理基础上，引入 AI 能力实现智能判断、自动规划、经验提取和记忆推荐，从"人工+门禁"升级到"AI 辅助+人工决策+门禁保护"。

## 定位

Phase A-F 建立了完整的治理基础：
- Evidence 标准
- 门禁验证
- 回写控制
- 项目记忆
- 团队复制

Phase G（自动化增强）在此基础上引入 AI 能力，但坚持：
- **AI 给建议，人做决策**
- **自动化必须可审计**
- **失败必须可回滚**

## 设计原则

### 1. 可选而非必需

所有自动化功能都是可选的：
- 不用 AI 判断，系统仍可正常工作
- 不用 AI 规划，人工仍可编写 task
- 不用 AI 提取，人工仍可沉淀经验

### 2. 建议而非决策

AI 只提供建议，不替代人工决策：
- 任务类型判断 → 建议，人工确认
- 执行计划生成 → 草稿，人工修改
- 经验提取 → 草稿，人工复核
- 记忆推荐 → 候选，人工筛选

### 3. 可审计而非黑盒

所有 AI 输出都可审计：
- 判断依据记录在 JSON
- 推理过程记录在日志
- 建议理由记录在 draft

### 4. 可降级而非依赖

AI 服务不可用时系统仍可工作：
- 降级到人工判断
- 降级到模板生成
- 降级到人工查询

## 增强功能

### 1. 任务类型自动判断

**输入**：
- Multica issue（标题、描述、标签）
- 项目上下文（仓库、技术栈）

**输出**：
```json
{
  "task_type": "bug_fix",
  "confidence": 0.85,
  "reasoning": "Issue 描述包含'报错'、'异常'等关键词，且有错误日志",
  "risk_level": "medium",
  "requires_clarification": false,
  "suggested_labels": ["bug", "backend"],
  "estimated_complexity": "medium"
}
```

**用途**：
- 帮助 scheduler 快速分类任务
- 路由到合适的 execution_agent
- 预估工作量和风险

**实现**：
- 脚本：`scripts/classify-task.sh`
- 输入：issue JSON
- 输出：classification.json
- 降级：返回 "unknown" + low confidence

### 2. 自动生成执行计划

**输入**：
- Task 描述
- 项目记忆（架构约束、验收偏好）
- 相似案例

**输出**：
```markdown
# FUZ-XXX 执行计划草稿

## 分析

根据任务描述和项目记忆，这是一个 [任务类型]。

参考案例：
- memory/cases/similar-case.md

## 建议步骤

1. [步骤 1]
   - 理由：[...]
   - 风险：[...]

2. [步骤 2]
   - 理由：[...]
   - 风险：[...]

## 需要注意

- 架构约束：[从 memory 提取]
- 验收偏好：[从 memory 提取]
- 已知坑：[从 memory 提取]

## 人工确认

请复核以下内容：
- [ ] 步骤是否完整
- [ ] 风险是否可控
- [ ] 是否遗漏约束
```

**用途**：
- 加速 task 编写
- 减少遗漏约束
- 复用历史经验

**实现**：
- 脚本：`scripts/generate-plan.sh`
- 输入：issue + memory/
- 输出：plan-draft.md
- 降级：返回简单模板

### 3. 自动化 Reviewer 智能体（暂缓）

**原因**：
- Reviewer 职责重大，直接影响质量
- 当前人工复核更可靠
- 可以先实现"复核建议"而非"自动批准"

**替代方案**：
```json
{
  "review_suggestions": [
    {
      "category": "evidence_completeness",
      "status": "passed",
      "note": "Core evidence 齐全"
    },
    {
      "category": "scope_check",
      "status": "warning",
      "note": "改动文件数 8 个，建议确认是否超出预期"
    },
    {
      "category": "test_coverage",
      "status": "failed",
      "note": "缺少单元测试"
    }
  ],
  "overall_recommendation": "request_changes",
  "reasoning": "缺少单元测试，建议补充后再复核"
}
```

### 4. 自动从 Evidence 提取经验

**输入**：
- runs/*/summary.md
- runs/*/stage-report.md
- runs/*/verification-report.md
- git commit message

**输出**：
```markdown
# 经验提取草稿

## 问题

[从 summary 提取]

## 解决方案

[从 stage-report 提取]

## 经验教训

做对了什么：
- [从 verification-report 提取通过项]

踩过的坑：
- [从 verification-report 提取失败项]

可复用模式：
- [从 commit message 和 patch 提取]

## 建议补充

请人工复核并补充：
- [ ] 为什么选择这个方案
- [ ] 有没有其他方案
- [ ] 下次如何避免踩坑
```

**用途**：
- 加速经验沉淀
- 减少遗漏信息
- 提高记忆质量

**实现**：
- 脚本：`scripts/extract-experience.sh`
- 输入：run 目录
- 输出：experience-draft.md
- 降级：返回结构化模板

### 5. 自动推荐相关记忆

**输入**：
- 当前 task 描述
- memory/ 索引

**输出**：
```json
{
  "relevant_constraints": [
    {
      "id": "C001",
      "title": "本地优先",
      "relevance": 0.9,
      "reason": "任务涉及 Multica 回写"
    }
  ],
  "relevant_cases": [
    {
      "id": "CASE001",
      "title": "FUZ-554 证据链建设",
      "relevance": 0.75,
      "reason": "都是基础设施建设类任务"
    }
  ],
  "relevant_pitfalls": [],
  "suggested_reading": [
    "memory/architecture-constraints.md",
    "memory/cases/FUZ-554-evidence-chain.md"
  ]
}
```

**用途**：
- 主动推荐相关约束
- 避免遗漏已知坑
- 加速新人上手

**实现**：
- 脚本：`scripts/recommend-memory.sh`
- 输入：task 描述
- 输出：recommendation.json
- 降级：返回最近 N 条记忆

## 实现策略

### MVP 范围

Phase G 只实现：
- ✅ 任务类型自动判断（classify-task.sh）
- ✅ 自动生成执行计划（generate-plan.sh）
- ✅ 自动从 evidence 提取经验（extract-experience.sh）
- ✅ 自动推荐相关记忆（recommend-memory.sh）

暂不实现：
- ❌ 自动化 reviewer 智能体
- ❌ 自动回写决策
- ❌ 向量搜索
- ❌ LLM 微调

### 自动化边界

- 不做自动 reviewer 结论：自动化只能准备 evidence、候选风险和复核包，最终 reviewer 结论由人或明确授权角色给出。
- 不做自动回写决策：Feishu、Multica、Git remote、部署、工具安装、Codex 配置修改都必须走 approval boundary。
- 不做自动远端副作用：分类、计划生成、经验提取、记忆推荐只产生本地文件或本地建议。
- 不绕过澄清门禁：当任务描述模糊或验收缺失时，preflight 必须阻断而不是自动猜测执行。
- 不把建议当事实：recommend-memory 和 generate-plan 输出是 draft，必须经过执行前复核。

### AI 接入方式

**方式 1：本地 LLM（推荐 MVP）**
```bash
# 使用本地模型 API
curl http://localhost:11434/api/generate \
  -d '{"model":"llama3","prompt":"..."}'
```

**方式 2：云端 API**
```bash
# 使用 OpenAI / Claude API
curl https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{"model":"gpt-4","messages":[...]}'
```

**方式 3：混合（推荐生产）**
- 分类、提取用本地模型（快、便宜）
- 规划、推荐用云端模型（准、贵）

### 降级策略

所有 AI 功能都有降级方案：

| 功能 | 正常 | 降级 |
|-----|------|------|
| 任务分类 | AI 判断 | 返回 unknown + 模板 |
| 执行计划 | AI 生成 | 返回空模板 |
| 经验提取 | AI 提取 | 返回结构化模板 |
| 记忆推荐 | AI 推荐 | 返回最近 N 条 |

## 门禁增强

### AI Output Gate

新增 `scripts/ai-output-gate.sh`，检查 AI 输出：

```bash
./scripts/ai-output-gate.sh \
  --type classification \
  --input classification.json \
  --output gate-report.json
```

**检查项**：
- JSON 格式正确
- 必需字段存在
- confidence 在合理范围
- reasoning 非空
- 不包含敏感信息

### Human Review Required

所有 AI 输出都标记"需人工复核"：

```json
{
  "ai_generated": true,
  "requires_human_review": true,
  "reviewed_by": null,
  "reviewed_at": null
}
```

## 审计日志

### AI Call Log

记录所有 AI 调用：

```json
{
  "timestamp": "2026-06-16T16:00:00Z",
  "function": "classify-task",
  "input": {
    "issue": "FUZ-XXX",
    "title": "..."
  },
  "output": {
    "task_type": "bug_fix",
    "confidence": 0.85
  },
  "model": "llama3",
  "tokens": 1500,
  "latency_ms": 2500,
  "status": "success"
}
```

### Cost Tracking

跟踪 AI 使用成本：

```json
{
  "date": "2026-06-16",
  "calls": 42,
  "tokens": 50000,
  "cost_usd": 0.25,
  "by_function": {
    "classify-task": 10,
    "generate-plan": 15,
    "extract-experience": 12,
    "recommend-memory": 5
  }
}
```

## 价值

自动化增强让系统从"人工+门禁"升级到"AI 辅助+人工决策+门禁保护"：

- **提效**：AI 生成草稿，人工修改确认
- **提质**：AI 推荐记忆，减少遗漏约束
- **提速**：AI 提取经验，加速沉淀
- **可控**：AI 只建议，人做决策
- **可审计**：所有 AI 输出可追踪

---

**文档状态**：Phase G 设计  
**生成时间**：2026-06-16  
**依赖**：Phase A-F 治理基础
