# AI Loop 项目记忆

这是 ai-loop 项目的 L2 记忆层，用于跨 issue 复用架构约束、决策记录、踩坑经验和验收偏好。

## 记忆类型

- **架构约束**：`architecture-constraints.md`
- **决策记录**：`decisions/*.md`
- **踩坑记录**：`pitfalls/*.md`
- **验收偏好**：`review-preferences.md`
- **经验案例**：`cases/*.md`

## 查询

```bash
./scripts/memory-query.sh --type <type> [--tag <tag>]
./scripts/memory-query.sh --search <keyword>
```

## 维护

人工在 `memory/` 下新增或修改 markdown 文件，并更新 `index.json`。

---

**项目**：ai-loop  
**生成时间**：2026-06-16
