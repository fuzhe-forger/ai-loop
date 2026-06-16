# AI 工作编排最佳实践

## 原则

### 1. 先治理，后自动化

❌ **错误做法**：
```bash
# 直接让 AI 自动完成并 push
ai-agent --task "fix bug" --auto-push
```

✅ **正确做法**：
```bash
# 本地 dry-run，人工复核，再决定是否提交
./scripts/multica-loop.sh --issue FUZ-XXX --repo /path
# 查看 runs/*/review-packet.md
# 确认后再 git add / git commit / git push
```

**原因**：自动化必须建立在可控、可审计、可撤销的基础上。

### 2. 先 Evidence，后智能调度

❌ **错误做法**：
```bash
# AI 说"已完成"就算完成
echo "Task done"
```

✅ **正确做法**：
```bash
# 生成完整 evidence 链
runs/YOUR-RUN/
  ├── summary.md
  ├── stage-report.md
  ├── multica-comment.md
  ├── state-evaluation.json
  └── metadata-draft.json

# 通过门禁验证
./scripts/verify-toolchain.sh --strict --state-gate
```

**原因**：Evidence 是复盘、分享和持续改进的基础。

### 3. 先本地，后远端

❌ **错误做法**：
```bash
# 直接改生产或远端 issue
multica issue status X done
git push origin main
```

✅ **正确做法**：
```bash
# 本地执行、本地验证、本地复核
./scripts/multica-loop.sh --issue X --repo /path
# 门禁通过后，人工确认才回写
./scripts/writeback-gate.sh --issue X --type comment
./scripts/multica-loop.sh --issue X --write-comment
```

**原因**：远端副作用必须可控、可追踪、可撤销。

### 4. 先人控，后策略自动化

❌ **错误做法**：
```bash
# 策略自动决定一切
if state == "evidence_ready"; then
  auto_approve_and_merge
fi
```

✅ **正确做法**：
```bash
# 生成建议，人工决策
./scripts/evaluate-state.sh --output state-evaluation.json
# 查看建议：next_actor、next_status
cat runs/*/review-packet.md
# 人工确认后才执行
```

**原因**：AI 给建议，人做决策。

## 工作流最佳实践

### 任务创建

**✅ 推荐**：
- 在 Multica 创建 issue，标题简洁明确
- 描述包含背景、目标、范围、验收标准
- 标签包含"可执行"、风险等级
- 首次接入选择"低风险"任务

**❌ 避免**：
- 任务描述模糊，依赖 AI 自由发挥
- 未定义范围，容易超出预期
- 首次接入选择高风险任务

### Task 编写

**✅ 推荐**：
```markdown
# FUZ-XXX: [任务标题]

## 目标
[具体可验证的目标]

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
```

**❌ 避免**：
```markdown
# FUZ-XXX: 修复 bug
随便改吧
```

### Evidence 生成

**✅ 推荐**：
- 每个 run 都生成 summary、stage-report、comment-draft
- 改动代码的任务生成 patch-summary
- 复杂任务生成 review-packet
- 状态转换生成 state-evaluation
- 元数据更新生成 metadata-draft

**❌ 避免**：
- 只写"已完成"，不生成 evidence
- Evidence 格式不统一
- 缺少关键字段（issue、run_id、timestamp）

### 门禁验证

**✅ 推荐**：
```bash
# 每次执行后验证
./scripts/verify-toolchain.sh \
  --case FUZ-XXX \
  --pattern 'FUZ-XXX*' \
  --strict \
  --state-gate \
  --output verification-report.md

# 回写前验证
./scripts/writeback-gate.sh \
  --issue FUZ-XXX \
  --run-id FUZ-XXX-pilot \
  --type comment
```

**❌ 避免**：
- 跳过门禁直接回写
- 门禁失败后强行绕过
- 不记录验证结果

### 回写策略

**✅ 推荐**：
- Comment 回写：低风险，可频繁同步进展
- Status 回写：中风险，需要门禁验证
- Metadata 回写：高风险，需要人工批准

**❌ 避免**：
- 自动改 status 为 done
- 不经门禁直接回写 metadata
- 回写后不记录 writeback-summary

### 经验沉淀

**✅ 推荐**：
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

**❌ 避免**：
- 只记录成功，不记录失败
- 只记录结果，不记录过程
- 不沉淀可复用模式

## 团队协作最佳实践

### 角色分工

| 角色 | 职责 | 典型动作 |
|-----|------|---------|
| execution_agent (顾实) | 执行任务 | 生成 evidence、写 comment |
| reviewer (裴衡) | 复核验收 | 检查 evidence、改 status |
| human (人类) | 决策确认 | 批准回写、关闭 issue |
| scheduler (黑墙) | 调度分派 | 分配任务、升级阻塞 |

**✅ 推荐**：
- 执行和复核分离
- 复核基于 evidence 而非口头
- 人类保留最终决策权

**❌ 避免**：
- 执行者自己复核自己
- 复核不看 evidence 只看结果
- 自动化替代人工决策

### 沟通协议

**✅ 推荐**：
- 进展同步：写 Multica comment
- 状态转换：基于 state evaluation
- 阻塞升级：记录 blocked_reason
- 经验分享：补 memory/cases/

**❌ 避免**：
- 进展只在聊天工具同步
- 状态随意改，不记录原因
- 阻塞不升级，长时间卡住
- 经验只在口头分享

### 复盘流程

**✅ 推荐**：
```bash
# 1. 收集 evidence
./scripts/collect-evidence.sh --issue FUZ-XXX --output evidence.json

# 2. 查看 review packet
cat runs/FUZ-XXX-*/review-packet.md

# 3. 总结经验教训
cat > memory/cases/FUZ-XXX-retrospective.md <<RETRO
## 做对了什么
- [列举]

## 踩过的坑
- [列举]

## 下次改进
- [列举]
RETRO

# 4. 分享到团队
# 补进飞书文档或内部 wiki
```

**❌ 避免**：
- 完成后不复盘
- 复盘只看结果不看过程
- 复盘结论不沉淀

## 场景最佳实践

### 场景 1：文档更新

**特点**：低风险、改动少、可回滚

**推荐做法**：
```bash
# 1. 创建任务
multica issue create --title "更新 XXX 文档" --label "低风险"

# 2. 本地执行
./scripts/multica-loop.sh --issue FUZ-XXX --repo /path

# 3. 验证
./scripts/verify-toolchain.sh --case FUZ-XXX --strict

# 4. 回写 comment
./scripts/multica-loop.sh --issue FUZ-XXX --write-comment

# 5. 人工复核后提交
git add docs/
git commit -m "Update XXX documentation"
git push
```

### 场景 2：代码重构

**特点**：中风险、改动多、需要测试

**推荐做法**：
```bash
# 1. 创建任务，明确范围
multica issue create --title "重构 XXX 模块" --label "中风险"

# 2. 本地执行 + 测试
./scripts/multica-loop.sh --issue FUZ-XXX --repo /path
cd /path && npm test

# 3. 生成 patch summary
./scripts/patch-summary.sh --repo /path --output patch-summary.md

# 4. 验证门禁
./scripts/verify-toolchain.sh --case FUZ-XXX --strict --state-gate

# 5. 人工复核 review packet
cat runs/FUZ-XXX-*/review-packet.md

# 6. 确认后回写 comment
./scripts/writeback-gate.sh --issue FUZ-XXX --type comment
./scripts/multica-loop.sh --issue FUZ-XXX --write-comment

# 7. 创建 PR，团队 code review
git checkout -b FUZ-XXX-refactor
git add .
git commit -m "Refactor XXX module"
git push origin FUZ-XXX-refactor
gh pr create
```

### 场景 3：生产热修复

**特点**：高风险、时间紧、影响大

**推荐做法**：
```bash
# 1. 创建紧急任务
multica issue create --title "热修复 XXX bug" --label "高风险" --priority high

# 2. 本地验证
./scripts/multica-loop.sh --issue FUZ-XXX --repo /path
cd /path && npm test

# 3. 严格门禁
./scripts/verify-toolchain.sh --case FUZ-XXX --strict --state-gate
./scripts/writeback-gate.sh --issue FUZ-XXX --type comment

# 4. 人工多重复核
# 复核者 1: 查看 patch summary
# 复核者 2: 查看测试结果
# 复核者 3: 查看影响范围

# 5. 批准后合并
git add .
git commit -m "Hotfix: XXX"
git push
# 部署后监控

# 6. 事后复盘
cat > memory/cases/FUZ-XXX-hotfix-retrospective.md <<RETRO
## 问题
[根因]

## 解决方案
[修复方法]

## 预防措施
[如何避免下次]
RETRO
```

## 反模式（要避免的做法）

### 反模式 1：无证据完成

❌ **表现**：
- AI 说"已完成"就关闭 issue
- 没有 summary、stage-report、comment-draft
- 失败后无法复盘

✅ **正确做法**：
- 每个 run 都生成完整 evidence
- 通过 strict gate 验证
- Evidence 提交到 git

### 反模式 2：直接远端副作用

❌ **表现**：
- 跳过本地验证直接 push
- 跳过门禁直接改 Multica status
- 跳过人工批准直接写 metadata

✅ **正确做法**：
- 本地 dry-run 验证
- 门禁通过后才回写
- 人工确认后才执行远端副作用

### 反模式 3：经验不沉淀

❌ **表现**：
- 成功经验只在口头分享
- 失败原因不记录
- 下次遇到同样问题重复踩坑

✅ **正确做法**：
- 补 memory/cases/
- 补 memory/pitfalls/
- 补 memory/decisions/

### 反模式 4：人工环节缺失

❌ **表现**：
- 执行者自己复核自己
- 复核不看 evidence
- 自动化替代人工决策

✅ **正确做法**：
- 执行和复核分离
- 复核基于 evidence
- 人类保留最终决策权

## 检查清单

**接入前**：
- [ ] 已定义任务范围
- [ ] 已选择合适风险等级
- [ ] 已准备回滚方案

**执行中**：
- [ ] 本地 dry-run 验证
- [ ] 生成完整 evidence
- [ ] 通过 strict gate
- [ ] 通过 state gate

**执行后**：
- [ ] 人工复核 review packet
- [ ] 通过 writeback gate
- [ ] 记录 writeback summary
- [ ] 沉淀经验到 memory/

**分享时**：
- [ ] 补 memory/cases/
- [ ] 更新飞书文档
- [ ] 团队复盘会

## 持续改进

### 定期检视

- 每周：检查 evidence 完整率
- 每月：复盘失败案例
- 每季度：更新最佳实践

### 指标监控

- Evidence 完整率：目标 100%
- Gate 通过率：目标 95%+
- 回写失败率：目标 <5%
- 经验沉淀率：目标每个 issue 至少 1 个 case

### 迭代优化

- 从失败案例中提取反模式
- 从成功案例中提取最佳实践
- 从团队反馈中优化流程

---

**文档版本**：v1.0  
**生成时间**：2026-06-16  
**适用范围**：所有使用 Multica Loop 的团队
