# AI 工作编排接入指南

## 目标

帮助新项目快速接入 Multica × ai-loop 工作编排系统，建立从 issue 到 evidence 的完整闭环。

## 适用场景

- 需要 AI 辅助的开发任务
- 需要审计和复盘的 AI 工作
- 需要跨项目沉淀经验的团队

## 前置条件

- Multica 账号和项目权限
- ai-loop 仓库克隆到本地
- 基础 Bash 和 Git 使用经验

## 快速开始（5 步）

### Step 1: 在 Multica 创建 Issue

在你的项目中创建一个 Issue：

```
标题：[你的任务描述]
描述：[任务背景和目标]
标签：可执行、低风险（推荐首次使用）
```

记录 Issue ID，例如：`FUZ-554`

### Step 2: 生成本地 Task

```bash
cd /home/user/JAVA/ai/ai-loop

# 创建 task 文件
cat > tasks/YOUR-ISSUE.md <<TASK
# YOUR-ISSUE: [任务标题]

## 目标

[从 Multica issue 复制描述]

## 范围

- 只改动 X 文件
- 不涉及 Y 依赖
- 不改动 Z 配置

## 验收标准

- [ ] 功能可用
- [ ] 测试通过
- [ ] 文档更新

## 风险控制

- 本地 dry-run 验证
- 人工复核后才提交
TASK
```

### Step 3: 执行 ai-loop Dry-Run

```bash
# 方式 1：使用 multica-loop 脚本（推荐）
./scripts/multica-loop.sh \
  --issue YOUR-ISSUE \
  --repo /path/to/your/repo

# 方式 2：手动执行（更灵活）
cd /path/to/your/repo
# 根据 task 执行改动
# 生成 summary.md、stage-report.md、multica-comment.md
```

### Step 4: 验证 Evidence

```bash
# 收集 evidence
./scripts/collect-evidence.sh \
  --issue YOUR-ISSUE \
  --run-id YOUR-ISSUE-pilot \
  --output /tmp/evidence.json \
  --markdown /tmp/evidence.md

# 验证门禁
./scripts/verify-toolchain.sh \
  --case YOUR-ISSUE \
  --pattern 'YOUR-ISSUE*' \
  --strict \
  --state-gate \
  --output /tmp/verify.md

# 检查结果
cat /tmp/verify.md
```

**期望结果**：
- Core evidence: PASSED
- Strict gate: PASSED
- State gate: PASSED

### Step 5: 人工复核并回写

```bash
# 查看复核包
cat runs/YOUR-ISSUE-pilot/review-packet.md

# 检查回写门禁
./scripts/writeback-gate.sh \
  --issue YOUR-ISSUE \
  --run-id YOUR-ISSUE-pilot \
  --type comment

# 确认后回写 comment
./scripts/multica-loop.sh \
  --issue YOUR-ISSUE \
  --repo /path/to/your/repo \
  --write-comment
```

## 完整工作流

```
1. Multica Issue 创建
   ↓
2. 本地 task.md 编写
   ↓
3. ai-loop dry-run 执行
   ↓
4. Evidence 收集
   - summary.md
   - stage-report.md
   - multica-comment.md
   - patch-summary.md
   ↓
5. State evaluation 生成
   - state-evaluation.json
   - next_actor
   ↓
6. Metadata draft 生成
   - metadata-draft.json
   - assigned_actor
   ↓
7. Review packet 生成
   - review-packet.md
   ↓
8. 门禁验证
   - Strict gate
   - State gate
   - Writeback gate
   ↓
9. 人工复核
   - 查看 review-packet
   - 确认改动范围
   - 决定是否回写
   ↓
10. 回写 Multica（可选）
    - Comment
    - Status
    - Metadata
```

## 关键概念

### Evidence

每个 run 必须具备的证据：

| 文件 | 必需 | 说明 |
|-----|------|------|
| `summary.md` | ✅ | 执行摘要 |
| `stage-report.md` | ✅ | 阶段报告 |
| `multica-comment.md` | ✅ | 评论草稿 |
| `patch-summary.md` | 推荐 | 改动范围 |
| `review-packet.md` | 推荐 | 复核入口 |
| `state-evaluation.json` | ✅ | 状态判断 |
| `metadata-draft.json` | ✅ | 元数据草稿 |

### 门禁

| 门禁 | 检查内容 | 失败后果 |
|-----|---------|---------|
| Strict gate | Core evidence 齐全 | 阻塞回写 |
| State gate | State evaluation + metadata draft | 阻塞回写 |
| Writeback gate | 回写前置条件 | 阻塞远端副作用 |

### 角色

| 角色 | 职责 | 可执行回写 |
|-----|------|-----------|
| execution_agent (顾实) | 执行任务 | comment |
| reviewer (裴衡) | 复核验收 | comment, status |
| human (人类) | 决策和确认 | 全部 |

## 常见问题

### Q1: 如何选择首个接入任务？

**建议**：
- 低风险：文档更新、配置调整、测试用例
- 明确范围：改动文件少于 5 个
- 可回滚：不涉及数据库或生产

### Q2: Evidence 不完整怎么办？

```bash
# 查看缺失的 evidence
./scripts/collect-evidence.sh --issue YOUR-ISSUE --run-id YOUR-RUN

# 补充缺失文件
cd runs/YOUR-RUN/
# 手动创建 summary.md / stage-report.md / multica-comment.md

# 重新验证
./scripts/verify-toolchain.sh --case YOUR-ISSUE --strict --state-gate
```

### Q3: 门禁失败怎么办？

**Strict gate 失败**：
- 检查是否缺少 summary / stage-report / comment-draft
- 补充缺失文件

**State gate 失败**：
- 检查是否缺少 state-evaluation.json / metadata-draft.json
- 运行 `./scripts/refresh-run-evidence.sh`

**Writeback gate 失败**：
- 检查 draft 文件是否包含敏感信息
- Metadata 回写需要 `--approved-by`

### Q4: 如何沉淀经验？

```bash
# 查询项目记忆
./scripts/memory-query.sh --type case

# 添加经验案例
cat > memory/cases/YOUR-ISSUE-experience.md <<CASE
# YOUR-ISSUE: [标题]

## 问题
[遇到的问题]

## 解决方案
[如何解决]

## 经验教训
[做对了什么、踩过的坑、可复用模式]
CASE

# 更新索引
# 编辑 memory/index.json
```

### Q5: 如何跨项目复用？

1. 查询相似案例：`./scripts/memory-query.sh --search "关键词"`
2. 参考架构约束：`./scripts/memory-query.sh --type constraint`
3. 参考验收偏好：`cat memory/review-preferences.md`
4. 复用经验模式：从成功案例中提取可复用流程

## 进阶使用

### 自动化脚本

```bash
# 一键执行 + 验证
./scripts/multica-loop.sh \
  --issue YOUR-ISSUE \
  --repo /path/to/your/repo \
  && ./scripts/verify-toolchain.sh \
       --case YOUR-ISSUE \
       --pattern 'YOUR-ISSUE*' \
       --strict \
       --state-gate
```

### 批量验证

```bash
# 验证所有 YOUR-PROJECT 的 run
./scripts/verify-toolchain.sh \
  --case YOUR-PROJECT \
  --pattern 'YOUR-PROJECT-*' \
  --strict \
  --state-gate \
  --output /tmp/batch-verify.md
```

### 多角色协作

```bash
# 执行者生成 evidence
顾实: ./scripts/multica-loop.sh --issue X --write-comment

# 复核者验证并改状态
裴衡: ./scripts/writeback-gate.sh --issue X --type status
裴衡: multica issue status X in_review

# 人类决策是否回写 metadata
人类: ./scripts/writeback-gate.sh --issue X --type metadata --approved-by "张三"
```

## 检查清单

接入前：
- [ ] 已有 Multica 项目和 issue
- [ ] 已克隆 ai-loop 仓库
- [ ] 已选择低风险试点任务

接入中：
- [ ] task.md 已创建
- [ ] dry-run 已执行
- [ ] Core evidence 齐全
- [ ] Strict gate 通过
- [ ] State gate 通过

接入后：
- [ ] Review packet 已复核
- [ ] Writeback gate 通过
- [ ] Comment 已回写（可选）
- [ ] 经验已沉淀到 memory/

## 支持资源

- 文档入口：`docs/ai-work-orchestration/README.md`
- 案例参考：`docs/ai-work-orchestration/share/FUZ-554-one-page.md`
- 演示脚本：`docs/ai-work-orchestration/share/demo-script.md`
- 技术分享：https://feishu.cn/wiki/TrvIwuNCRiC8xGkdSRwcl9JJn8c
- 项目记忆：`memory/cases/FUZ-554-evidence-chain.md`

## 下一步

接入成功后：
- 补充项目记忆中的决策记录和踩坑记录
- 在团队内分享经验
- 选择第二个任务验证复用性

---

**文档版本**：v1.0  
**生成时间**：2026-06-16  
**适用范围**：所有需要接入 Multica Loop 的项目
