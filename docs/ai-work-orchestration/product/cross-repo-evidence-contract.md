# 多仓库 Evidence Contract

## 目的

让司南在跨仓库任务中统一聚合 repo、分支、变更、验证和审批边界，避免不同仓库 evidence 分散导致复核困难。

## Contract

```json
{
  "schema_version": 1,
  "run_id": "string",
  "generated_at": "ISO-8601",
  "repos": [
    {
      "name": "string",
      "path": "string",
      "git_head": "string",
      "branch": "string",
      "status_short": "string",
      "changed_files": ["string"],
      "verification": [
        {
          "command": "string",
          "result": "PASSED|FAILED|SKIPPED",
          "evidence": "string"
        }
      ],
      "side_effects": "local-only|remote-write|deploy|production"
    }
  ],
  "approval_required": false,
  "notes": []
}
```

## 规则

- 每个 repo 必须记录绝对路径、branch、HEAD、`git status --short`。
- 本地修改只记录事实，不自动提交、不 push。
- 跨仓库任务若涉及远端 Git、部署、生产访问，必须进入 L4 审批边界。
- 总 run 只聚合 evidence 路径，不复制各仓库完整日志。
- CodeGraph 可用于定位，但不是唯一依赖；未初始化时退回 `rg`/文件树审计。
