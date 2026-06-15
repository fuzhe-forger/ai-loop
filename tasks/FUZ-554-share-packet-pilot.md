# FUZ-554-G 一页式分享包试点

## 背景

`FUZ-554` 已形成从元流程、文档试点、脚本试点、证据清单、证据索引到复核包的完整样板。下一步需要把这些材料整理成团队可直接阅读的一页式分享稿。

## 目标

新增一份 `FUZ-554` 分享包，用业务和工程都能理解的方式说明：为什么做、怎么做、产出了什么证据、边界在哪里、下一步如何推进。

## 交付物

- `docs/ai-work-orchestration/share/FUZ-554-one-page.md`
- `runs/FUZ-554-share-packet-pilot/stage-report.md`
- `runs/FUZ-554-share-packet-pilot/multica-comment.md`

## 验收标准

- 分享稿包含背景、方法、产物、证据、边界、下一步
- 分享稿能引用 review packet 和 evidence index
- 分享稿明确 dry-run 不等于业务完成
- 本地文件存在性验证通过
- 不访问 Multica，不写远端

## 验证命令

```bash
cd /home/user/JAVA/ai/ai-loop
test -s docs/ai-work-orchestration/share/FUZ-554-one-page.md
test -s runs/FUZ-554-review-packet-pilot/review-packet.md
test -s runs/FUZ-554-evidence-index-pilot/index.md
rg -n "dry-run|Evidence|Human|review packet|evidence index" docs/ai-work-orchestration/share/FUZ-554-one-page.md
```

## 安全边界

- 仅修改本地文档和本地证据
- 不读取 Multica issue
- 不写 Multica comment/status
- 不 push、不 commit、不创建 MR
