# 阶段报告：Phase 64 Clarification Obsidian Sync

## 目标

把 `clarification.md` 同步到 Obsidian generated run 页面，让需求澄清状态可以在知识库中被人类直接复盘。

## 背景与问题

Phase 61-63 已经完成需求澄清门禁、澄清草稿生成、run evidence 接入和 state gate 强制校验。但 Obsidian generated run 页面此前只展示 summary、stage report 和 verification report，导致人类在知识库复盘时看不到 `needs_clarification` 的具体问题清单。

## 核心结论

- `obsidian-sync.sh` 的 Loop run 索引新增 `Clarification` 列。
- `obsidian-sync.sh` 的单个 run 页面新增 `## Clarification Draft` section。
- 同步仍只写 `99-generated/`，不覆盖人工维护区。
- 默认 `DRY_RUN=true`，本阶段验证不写入 Obsidian。

## 方案与设计

### runs-index

Loop run 索引增加 `has_clarification` 标记，并在表格中展示 `Clarification` 是否存在。

### run page

当 `runs/<run-id>/clarification.md` 存在时，generated run 页面会在 `Summary` 后追加：

```markdown
## Clarification Draft
```

内容最多摘录前 3000 字符，完整内容仍以本地 `runs/` 目录为事实源。

## 验收与验证

验证命令：

```bash
bash -n scripts/obsidian-sync.sh
DRY_RUN=true ./scripts/obsidian-sync.sh
DRY_RUN=false VAULT_PATH=/tmp/obsidian-phase64-vault ./scripts/obsidian-sync.sh
```

验证结果：

- `bash -n scripts/obsidian-sync.sh`：PASSED。
- `DRY_RUN=true ./scripts/obsidian-sync.sh`：PASSED，未写入真实 Obsidian。
- fake vault 写入验证：PASSED，写入 `/tmp/obsidian-phase64-vault/99-generated`。
- `phase-61-clarification-sample` generated run 页面包含 `## Clarification Draft`、`Questions For Human Confirmation`、`Suggested Requirement Skeleton`。
- generated runs index 包含 `Clarification` 列。
- generated runs index 显示 `phase-61-clarification-sample` 为 `needs_clarification` 且 clarification 为 `✓`。
- generated runs index 显示 `phase-61-missing-clarification-sample` 为 `blocked` 且 clarification 为 `✗`。

## 负责人 / 角色

- Owner / DRI：傅喆。
- Actor：顾实。
- Reviewer：人工复核；后续可交给裴衡按 evidence 复核。

## 副作用与回写状态

- Network access: read-only Multica CLI snapshot attempts in existing sync script。
- Remote writes: false。
- Obsidian write: false in validation because `DRY_RUN=true`。
- Multica writeback: none。
- Feishu writeback: none。

## 下一步

- 为 `clarification.md` 增加模板质量检查。
- 将 requirement/design/deliverable 三类 gate 结果统一写入 `evidence.json`。
- 在 Obsidian generated run 页面展示 gate score 和 next actor。
