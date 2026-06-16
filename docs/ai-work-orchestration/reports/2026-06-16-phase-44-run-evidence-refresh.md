# 阶段报告：Phase 44 Run Evidence Refresh

## 目标

把已有 FUZ-554 run 的状态判断和 metadata 草稿批量补齐，让 review packet 不再依赖零散手工刷新。

## 已完成

- 新增 `scripts/refresh-run-evidence.sh`。
- 更新 `scripts/verify-toolchain.sh`，把 refresh 脚本纳入 smoke checks。
- 对 `runs/FUZ-554*` 执行本地批量刷新。

## 刷新内容

每个匹配 run 生成或更新：

- `state-evaluation.json`
- `state-evaluation.md`
- `metadata-draft.json`
- `metadata-draft.md`

这些文件位于 ignored `runs/` 目录，仅作为本地 evidence，不进入 Git 提交。

## 验证结果

已执行：

```bash
./scripts/refresh-run-evidence.sh \
  --pattern 'FUZ-554*' \
  --issue FUZ-554 \
  --output /tmp/fuz554-refresh-all.md

./scripts/review-packet.sh \
  --case FUZ-554 \
  --pattern 'FUZ-554*' \
  --output /tmp/fuz554-review-after-refresh.md

./scripts/verify-toolchain.sh \
  --case FUZ-554 \
  --pattern 'FUZ-554*' \
  --strict
```

结果：

- FUZ-554 共 22 个 run 完成刷新。
- 22 个 run 均生成 `state-evaluation.json`。
- 22 个 run 均生成 `metadata-draft.json`。
- review packet 不再对已刷新 run 显示 `not evaluated`。
- strict toolchain 通过。

## 示例

```text
FUZ-554-scope-split-review -> review_ready / reviewer / Remote Write Done=NO
FUZ-554-toolchain-verify-pilot -> done / human / Remote Write Done=YES
```

## 边界

- 脚本只写本地 `runs/` artifact。
- 不写 Multica。
- 不改变 issue status。
- 不提交刷新生成的 run evidence。

## 下一步

- 让分享预检脚本包含 run evidence refresh 检查。
- 后续再设计 metadata 远端写入审批策略。
