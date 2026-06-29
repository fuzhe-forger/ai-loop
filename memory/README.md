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

经验案例的 `review_state` 使用本地 helper 流转，默认 dry-run：

```bash
./scripts/extract-experience.sh --run-id <run-id> --promote-to-memory
./scripts/phase-d-closeout.sh --run-id <run-id>
./scripts/memory-promote-draft.sh --case-draft <draft.md> --index-entry <entry.json>
./scripts/memory-promote-draft.sh --case-draft <draft.md> --index-entry <entry.json> --execute
./scripts/memory-review-state.sh --case-id <case-id> --from draft --to reviewed
./scripts/memory-review-state.sh --case-id <case-id> --from reviewed --to accepted --execute
```

允许流转由 `config/project-memory-policy.json` 的 `review_state_transitions` 定义；执行后运行 `./scripts/memory-quality-check.sh` 验证索引质量。

---

**项目**：ai-loop  
**生成时间**：2026-06-16
