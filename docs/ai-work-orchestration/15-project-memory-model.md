# 项目记忆模型

## 目标

建立 L2 项目记忆层，让天道/黑墙经验和每次执行复盘沉淀成可查询、可复用的结构化知识。

## 定位

项目记忆是介于单 issue 工作记忆（L1 issue metadata）和全局经验库（L3 向量库/知识图谱）之间的中间层。

| 层级 | 存储 | 生命周期 | 内容 | 当前状态 |
|---|---|---|---|---|
| L1 工作记忆 | issue metadata | 单 issue | 当前状态、review verdict、blocked reason、run id | ✅ 已实现 |
| L2 项目记忆 | 本地文件 | 跨 issue | 架构约束、决策记录、踩坑、验收偏好 | 🔄 Phase D |
| L3 全局记忆 | 向量库/知识图谱 | 长期 | agent 能力画像、历史方案模板、跨项目经验 | 📋 Phase E+ |

## 设计原则

- **先文件化，再考虑数据库**：MVP 阶段只做文件，不引入外部存储
- **先结构化，后智能检索**：先定义字段和索引，后续再接入向量搜索
- **先人工维护，后自动沉淀**：先手动记录关键决策，再考虑从 evidence 自动提取
- **先项目内，后跨项目**：先在单个项目内复用，再考虑跨项目经验迁移

## 记忆类型

### 1. 架构约束（Architecture Constraints）

记录项目的架构决策和不可变约束。

**示例**：
- 不引入新的 ORM，复用现有 MyBatis
- API 必须支持幂等
- 不允许跨库事务
- 前端必须支持 IE11（如果有）

**用途**：
- AI 执行时自动检查是否违反约束
- 人工复核时确认是否符合架构规范

### 2. 决策记录（Decision Records）

记录重大技术决策的上下文、选项和理由。

**格式参考 ADR（Architecture Decision Record）**：
- 标题
- 状态（提议 / 已接受 / 已废弃）
- 上下文
- 决策
- 后果

**示例**：
- 为什么选择 Redis 而不是 Memcached
- 为什么用事件驱动而不是同步调用
- 为什么不用微服务拆分

### 3. 踩坑记录（Pitfalls）

记录已知的坑和避免方法。

**示例**：
- MySQL 5.7 不支持 `ROW_NUMBER()`
- 某个依赖版本有并发 bug
- 某个 API 有频率限制
- 某个配置项容易写错

**用途**：
- AI 执行前预检是否会踩坑
- 失败后快速定位已知问题

### 4. 验收偏好（Review Preferences）

记录项目的代码风格、命名规范、测试要求等。

**示例**：
- 变量名必须用驼峰而不是下划线
- 所有 public 方法必须有 Javadoc
- 单元测试覆盖率要求 80%
- 不允许 `System.out.println`，必须用日志

**用途**：
- AI 生成代码时遵守规范
- reviewer 复核时对齐验收标准

### 5. 经验案例（Experience Cases）

记录成功和失败的典型案例。

**示例**：
- FUZ-554 如何从想法走到证据链
- 某次 API 改造如何避免了生产故障
- 某次重构如何平滑迁移

**用途**：
- 类似任务时直接参考
- 新人快速了解项目历史

## 存储结构

### 目录结构

```
memory/
├── README.md                      # 项目记忆总入口
├── architecture-constraints.md    # 架构约束
├── decisions/                     # 决策记录
│   ├── 001-redis-vs-memcached.md
│   ├── 002-event-driven-design.md
│   └── README.md
├── pitfalls/                      # 踩坑记录
│   ├── mysql-row-number.md
│   ├── dependency-concurrency-bug.md
│   └── README.md
├── review-preferences.md          # 验收偏好
└── cases/                         # 经验案例
    ├── FUZ-554-evidence-chain.md
    └── README.md
```

### 元数据索引

`memory/index.json`：

```json
{
  "schema_version": 1,
  "project": "ai-loop",
  "updated_at": "2026-06-16T08:00:00Z",
  "constraints": [
    {
      "id": "C001",
      "type": "architecture",
      "title": "不引入新的 ORM",
      "file": "architecture-constraints.md",
      "tags": ["orm", "mybatis"]
    }
  ],
  "decisions": [
    {
      "id": "D001",
      "title": "Redis vs Memcached",
      "status": "accepted",
      "file": "decisions/001-redis-vs-memcached.md",
      "date": "2026-01-15",
      "tags": ["cache", "redis"]
    }
  ],
  "pitfalls": [
    {
      "id": "P001",
      "title": "MySQL 5.7 不支持 ROW_NUMBER()",
      "file": "pitfalls/mysql-row-number.md",
      "severity": "high",
      "tags": ["mysql", "sql"]
    }
  ],
  "cases": [
    {
      "id": "CASE001",
      "issue": "FUZ-554",
      "title": "AI 工作编排证据链",
      "file": "cases/FUZ-554-evidence-chain.md",
      "tags": ["evidence", "loop", "orchestration"]
    }
  ]
}
```

## 查询接口

### 命令行工具

```bash
# 查询架构约束
./scripts/memory-query.sh --type constraint --tag orm

# 查询决策记录
./scripts/memory-query.sh --type decision --status accepted

# 查询踩坑记录
./scripts/memory-query.sh --type pitfall --severity high

# 查询经验案例
./scripts/memory-query.sh --type case --issue FUZ-554

# 全文搜索
./scripts/memory-query.sh --search "Redis"
```

### 输出格式

```json
{
  "query": {
    "type": "constraint",
    "tag": "orm"
  },
  "results": [
    {
      "id": "C001",
      "type": "architecture",
      "title": "不引入新的 ORM",
      "file": "memory/architecture-constraints.md",
      "tags": ["orm", "mybatis"],
      "excerpt": "项目已使用 MyBatis，不引入 JPA/Hibernate..."
    }
  ],
  "count": 1
}
```

## 更新流程

### 人工更新

1. 在 `memory/` 下新增或修改 markdown 文件
2. 更新 `memory/index.json`
3. 提交到 git

### 自动沉淀（后续实现）

1. 从 evidence 中提取关键信息
2. 生成记忆草稿
3. 人工复核后入库
4. 更新索引

## 复用场景

### 场景 1：执行前预检

AI 接到新任务时，先查询项目记忆：

- 是否有架构约束？
- 是否有已知坑？
- 是否有类似案例？

### 场景 2：生成代码时

AI 生成代码时，参考验收偏好：

- 命名规范
- 注释要求
- 测试覆盖

### 场景 3：复核时

Reviewer 复核时，参考决策记录：

- 为什么这样设计？
- 有没有更好方案？
- 是否符合架构约束？

### 场景 4：失败复盘

任务失败时，查询踩坑记录：

- 是否是已知问题？
- 如何避免？
- 是否需要补记忆？

## MVP 实现范围

Phase D 只实现：

- ✅ 目录结构和文件规范
- ✅ 人工维护 markdown 文件
- ✅ 基础索引文件 `index.json`
- ✅ 命令行查询工具 `memory-query.sh`
- ✅ FUZ-554 案例沉淀

暂不实现：

- ❌ 自动从 evidence 提取
- ❌ 向量搜索
- ❌ 跨项目记忆迁移
- ❌ LLM 智能推荐

## 后续演进

Phase E+：

- 自动从 evidence 提取关键决策
- 接入向量库支持语义搜索
- 跨项目经验迁移
- LLM 智能推荐相关记忆

## 价值

项目记忆让 AI 工作从"每次从零开始"升级成"基于项目上下文执行"：

- **减少重复踩坑**
- **加速新人上手**
- **提升验收一致性**
- **沉淀团队经验**

---

**文档状态**：Phase D 设计  
**生成时间**：2026-06-16
