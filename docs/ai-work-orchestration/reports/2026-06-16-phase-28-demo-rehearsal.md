# 阶段报告：Phase 28 Demo Rehearsal

## 目标

按 `share/demo-script.md` 做一次本地彩排，确认技术分享现场命令可运行、输出可解释、风险可控。

## 彩排命令

- `git status -sb`
- `scripts/collect-evidence.sh --issue FUZ-554 --run-id FUZ-554-scope-split-review`
- `scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --strict`
- `sed` 查看 scope split report 摘要

## 彩排结果

- `collect-evidence`：PASSED
- `verify-toolchain --strict`：PASSED
- scope split report 可展示：PASSED

## 现场注意点

1. 当前工作树可能出现已知未跟踪草稿：`tasks/FUZ-560-getSkuMaterialWarranties-loop-plan.md`。演示时要说明这是另一个任务草稿，不影响 FUZ-554 证据链。
2. `FUZ-554-scope-split-review/scope-split-report.md` 是提交前历史 artifact，里面记录的是当时混合工作树的拆分情况。现在已经完成拆分提交，所以演示时应称为“历史 scope split 证据”，不要说它代表当前 git 状态。
3. `collect-evidence` 对 `FUZ-554-scope-split-review` 显示 run.json 缺失、patch summary 缺失、review packet 缺失，但 core evidence 和 strict gate 通过。演示时应强调 collector 能区分 core evidence 与 optional artifacts。

## 建议话术

- “这里我们演示的是 evidence 机制，不是 live coding。”
- “strict gate 检查的是 core evidence：summary、stage report、comment draft。”
- “scope split 是当时提交前防止混合提交的历史证据。”
- “未跟踪 FUZ-560 草稿属于另一条任务，不纳入本次分享链路。”

## 结论

演示命令可用，但 demo script 需要补充上述注意事项，避免现场误解当前工作树状态和历史 artifact 的含义。
