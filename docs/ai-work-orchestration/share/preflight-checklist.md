# 会前预检清单：AI 工作编排技术分享

## 目标

在正式分享前，用 10 分钟确认材料、命令、证据和 fallback 都可用，避免现场依赖临时判断。

## 1. 打开材料

按顺序准备这些文件：

```text
docs/ai-work-orchestration/09-north-star.md
docs/ai-work-orchestration/share/FUZ-554-one-page.md
docs/ai-work-orchestration/share/slides-content.md
docs/ai-work-orchestration/share/speaker-notes.md
docs/ai-work-orchestration/share/demo-script.md
```

用途：

- `09-north-star.md`：开场讲终局。
- `FUZ-554-one-page.md`：快速讲案例。
- `slides-content.md`：PPT 上屏文案。
- `speaker-notes.md`：逐页讲稿和转场。
- `demo-script.md`：现场命令和讲法。

## 2. 确认仓库状态

执行：

```bash
cd /home/user/JAVA/ai/ai-loop
git status -sb
```

预期：

```text
## master
?? tasks/FUZ-560-getSkuMaterialWarranties-loop-plan.md
```

说明：

- `FUZ-560` 是另一条任务草稿。
- 本次分享只讲 `FUZ-554` 链路。
- 如果出现其他未提交文件，先暂停，不要混入分享材料提交。

## 3. 跑 evidence 收集演示

执行：

```bash
./scripts/collect-evidence.sh \
  --issue FUZ-554 \
  --run-id FUZ-554-scope-split-review \
  --output /tmp/fuz554-evidence.json \
  --markdown /tmp/fuz554-evidence.md

sed -n '1,120p' /tmp/fuz554-evidence.md
```

预期：

- 能生成 `/tmp/fuz554-evidence.json`。
- 能生成 `/tmp/fuz554-evidence.md`。
- Markdown 中能看到 core evidence 和 run artifact 信息。

讲法：

- AI 说完成不算，evidence 才算。
- core evidence 是 `summary.md`、`stage-report.md`、`multica-comment.md`。
- 这是从任务走向可复核事实的第一步。

## 4. 跑 strict gate

执行：

```bash
./scripts/verify-toolchain.sh \
  --case FUZ-554 \
  --pattern 'FUZ-554*' \
  --strict \
  --output /tmp/fuz554-strict.md

rg -n "Strict Evidence Gate|strict evidence gate passed" /tmp/fuz554-strict.md
```

预期：

```text
Strict Evidence Gate
Local helper toolchain smoke checks and strict evidence gate passed.
```

讲法：

- strict gate 把证据完整性变成可执行检查。
- 每个 run 都必须齐 `summary.md`、`stage-report.md`、`multica-comment.md`。
- 这条线保证回写和分享不是凭感觉。

## 5. 准备 fallback

如果现场命令失败，不要现场修脚本，直接切到已生成材料：

```text
docs/ai-work-orchestration/reports/2026-06-16-phase-28-demo-rehearsal.md
docs/ai-work-orchestration/reports/2026-06-16-phase-32-slides-content.md
runs/FUZ-554-strict-evidence-gate-pilot/verification-report.md
runs/FUZ-554-scope-split-review/scope-split-report.md
```

讲法：

- 现场失败也可以展示历史 evidence。
- 重点不是命令炫技，而是证明系统有可复核 artifact。
- 这也符合 human in command：不在会场临时扩大变更。

## 6. 最后确认讲述顺序

推荐顺序：

1. 终局：AI 工程团队操作系统。
2. 痛点：多 agent 工作如果没有治理，会变成散乱记录。
3. 架构：Multica、Multica Loop、ai-loop、Agent Network、Artifacts & Memory。
4. 案例：FUZ-554 从任务到 evidence 的闭环。
5. 演示：collect evidence、strict gate、scope split。
6. 路线：evidence 标准、状态机、项目记忆、团队模板。

## 7. 会后动作

分享结束后只做三件事：

- 收集听众最关心的问题。
- 标记哪些内容需要补图或补例子。
- 把下一步工程推进收敛到 Multica Loop 状态机和 evidence 标准。
