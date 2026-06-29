# 阶段报告：Phase 67 Gate Results Evidence

## 目标

将 requirement、design、clarification、deliverable 四类 gate 结果统一写入 `evidence.json`，形成标准质量视图。

## 背景与问题

Phase 60-66 已经逐步建立需求、方案、澄清、产出的质量门禁。但门禁结果此前分散在各自 Markdown 报告里，reviewer 或后续自动化需要分别读取多个文件，难以快速判断当前 run 的质量状态。

## 核心结论

- `collect-evidence.sh` 已新增 `checks.gate_results`。
- `gate_results` 覆盖 `requirement`、`design`、`clarification`、`deliverable` 四类 gate。
- 每个 gate 统一包含：`path`、`present`、`result`、`score`、`required_failures`。
- Markdown evidence 新增 `## Gate Results` 表，方便人类直接阅读。
- 本阶段 local-only，不读取 Multica，不产生远端副作用。

## JSON 结构

```json
{
  "checks": {
    "gate_results": {
      "requirement": {
        "path": "runs/<run-id>/requirement-gate.md",
        "present": true,
        "result": "FAILED",
        "score": 9,
        "required_failures": 10
      },
      "design": {},
      "clarification": {},
      "deliverable": {}
    }
  }
}
```

## 验收与验证

验证命令：

```bash
./scripts/collect-evidence.sh \
  --issue PHASE-61 \
  --run-id phase-61-clarification-sample \
  --output /tmp/phase67-evidence.json \
  --markdown /tmp/phase67-evidence.md

./scripts/verify-toolchain.sh \
  --case FUZ-554 \
  --pattern 'FUZ-554*' \
  --output /tmp/toolchain-phase67.md
```

验证结果：

- `phase-61-clarification-sample` 的 JSON 包含 `checks.gate_results.requirement`。
- `phase-61-clarification-sample` 的 JSON 包含 `checks.gate_results.clarification`。
- requirement gate 结果：`FAILED`，score `9`，required failures `10`。
- clarification gate 结果：`PASSED`，score `100`，required failures `0`。
- Markdown evidence 包含 `## Gate Results` 表。
- `verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*'`：PASSED。

## 负责人 / 角色

- Owner / DRI：傅喆。
- Actor：顾实。
- Reviewer：人工复核；后续可交给裴衡按 evidence 复核。

## 副作用与回写状态

- Network access: false。
- Remote writes: false。
- Multica writeback: none。
- Feishu writeback: none。
- External side effect: none。

## 下一步

- 把 gate score 展示到 review packet。
- 把 gate score 展示到 Obsidian generated run 页面。
- 对不同任务类型配置 gate 权重和最低分。
