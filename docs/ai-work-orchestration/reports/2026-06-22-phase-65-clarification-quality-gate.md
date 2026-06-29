# 阶段报告：Phase 65 Clarification Quality Gate

## 目标

为 `clarification.md` 增加模板质量检查，确保需求澄清草稿不仅存在，而且足够可回答、可交给人类推进。

## 背景与问题

Phase 61-64 已经让 `clarification.md` 生成、进入 evidence、进入 state gate，并同步到 Obsidian generated run 页面。但仅检查文件存在仍不够：如果问题清单太少、缺少需求骨架、没有下一步或没有副作用说明，人类仍然难以补充需求。

## 核心结论

- 新增 `scripts/clarification-gate.sh`。
- `clarification-gate` 检查摘要、原因、人工确认问题、具体问题数量、需求骨架、下一步和副作用可见性。
- 严格模式要求 10 个标准需求骨架 section 全部存在。
- `verify-toolchain.sh` 已接入 `clarification-gate` 的语法和 help 检查。
- 本阶段 local-only，不读取 Multica，不产生远端副作用。

## 检查项

| 检查 | 要求 |
|---|---|
| Summary | 包含来源、gate 结果或 next state |
| Why needed | 说明为什么不能进入设计 / 开发 |
| Questions | 包含人工确认问题区 |
| Concrete questions | 至少 5 个带问号的具体问题 |
| Requirement skeleton | 包含建议需求骨架 |
| Next step | 明确人类补充后如何继续 |
| Side-effect visibility | 明确 network / remote write / side effect 可见性 |
| Strict skeleton | 严格模式要求 10 个需求 section 全部存在 |

## 验收与验证

验证命令：

```bash
bash -n scripts/clarification-gate.sh
./scripts/clarification-gate.sh --run-id phase-61-clarification-sample --strict --output /tmp/clarification-gate-phase65.md
./scripts/clarification-gate.sh --input /tmp/bad-clarification.md --output /tmp/bad-clarification-gate.md
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --output /tmp/toolchain-phase65.md
```

验证结果：

- `bash -n scripts/clarification-gate.sh`：PASSED。
- `clarification-gate --run-id phase-61-clarification-sample --strict`：PASSED，score `100/100`，question count `10`。
- 坏样例 `/tmp/bad-clarification.md`：FAILED，score `12/100`，question count `0`。
- `verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*'`：PASSED。
- 本阶段报告通过 `deliverable-gate`：PASSED，score `100/100`。

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

- 将 clarification gate 分数展示到 Obsidian generated run 页面。
- 将 requirement/design/deliverable/clarification 四类 gate 结果统一写入 `evidence.json`。
