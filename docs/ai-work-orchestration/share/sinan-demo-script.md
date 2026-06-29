# 司南 5 分钟演示脚本

## 目标

用一个本地样例演示：任务进入、风险分级、估时、evidence 收口、Obsidian 同步、写回审批门禁。

## 准备

```bash
cd /home/user/JAVA/ai/ai-loop
RUN_ID=$(cat /tmp/FUZ-554-real-run-id-2.txt)
```

预期输出：`RUN_ID` 指向 `runs/FUZ-554-real-multica-loop-gated-20260622-142303` 这类目录。

## 1. 执行前检查

```bash
./scripts/loop-execution-preflight.sh \
  --issue FUZ-554 \
  --task tasks/FUZ-554.md \
  --repo . \
  --run-id "$RUN_ID" \
  --no-phase-report \
  --no-operation-log \
  --output /tmp/sinan-demo-preflight.md \
  --json-output /tmp/sinan-demo-preflight.json
```

预期输出：`Result: PASSED`，并包含 `Memory Recommendations`、`Timebox`、`Forbidden Without Separate Approval`。

失败回滚：这是本地临时文件，删除 `/tmp/sinan-demo-preflight.*` 即可。

## 2. 证据收口

```bash
./scripts/collect-evidence.sh \
  --issue FUZ-554 \
  --run-id "$RUN_ID" \
  --output /tmp/sinan-demo-evidence.json \
  --markdown /tmp/sinan-demo-evidence.md
```

预期输出：生成 `evidence_json` 和 `evidence_markdown`，JSON 中有 `artifact_registry`。

失败回滚：删除 `/tmp/sinan-demo-evidence.*`，不影响 run 目录。

## 3. 严格验证

```bash
./scripts/verify-toolchain.sh \
  --case FUZ-554 \
  --pattern "$RUN_ID" \
  --strict \
  --state-gate \
  --output /tmp/sinan-demo-verification.md
```

预期输出：`verification_report: /tmp/sinan-demo-verification.md`，报告结尾为通过结论。

失败回滚：验证只读本地文件；修复失败项后重跑。

## 4. 分享预检

```bash
./scripts/share-preflight.sh \
  --case FUZ-554 \
  --pattern "$RUN_ID" \
  --golden-run-id "$RUN_ID" \
  --skip-verify \
  --output-dir /tmp/sinan-demo-share
```

预期输出：`share-preflight-summary.md/json`，展示 `Golden path failed checks: 0`、`Approval Boundary`、`Time Contract Gates`。

失败回滚：删除 `/tmp/sinan-demo-share`。

## 5. 写回审批门禁

```bash
./scripts/approval-boundary.sh \
  --action multica-comment \
  --issue FUZ-554 \
  --run-id "$RUN_ID" \
  --json-output /tmp/sinan-demo-approval-required.json || true
```

预期输出：未审批时 `APPROVAL_REQUIRED`，不会执行远端写入。

```bash
./scripts/writeback-gate.sh \
  --issue FUZ-554 \
  --run-id "$RUN_ID" \
  --type comment \
  --approved-by demo-reviewer \
  --output /tmp/sinan-demo-writeback-gate.json
```

预期输出：审批存在时 `allowed=true`，并声明写后 readback 路径。

失败回滚：删除 `/tmp/sinan-demo-approval-required.json` 和 `/tmp/sinan-demo-writeback-gate.json`。

## 6. Obsidian 同步

```bash
WRITE_OPERATION_LOG=false DRY_RUN=false ./scripts/obsidian-sync.sh
```

预期输出：写入 `/mnt/d/JAVA/knowledge/tiandao/99-generated`，包含 Loop run 证据页和 ai-loop 文档镜像。

失败回滚：重新运行 `DRY_RUN=true ./scripts/obsidian-sync.sh` 检查路径；不要手动删除 vault 内容，除非先备份。

## 演示结束语

司南不是自动替人做决策，而是把长任务拆成可验证切片：先估时，再执行，再收 evidence，再受控写回。
