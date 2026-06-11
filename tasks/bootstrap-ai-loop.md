# bootstrap-ai-loop

## 目标

实现 AI Loop MVP，让 Loop 系统可以跑自己的下一轮任务。

## 必须支持

1. `ai-loop init`
2. `ai-loop run --repo <path> --task <file> [--dry-run]`
3. `ai-loop status <run-id>`
4. 读取 `.ai-loop.yml`
5. 创建 `runs/<run-id>/`
6. 使用 git worktree 创建 workspace
7. 调用 codex exec
8. 执行 verify commands
9. 验证失败后最多重试 max_iterations
10. 生成 patch 和 summary

## 当前切片验收

dry-run 冒烟验证：

```bash
./bin/ai-loop run \
  --repo /home/user/JAVA/ai/ai-loop \
  --task tasks/bootstrap-ai-loop.md \
  --dry-run
```

必须生成：

```text
runs/<run-id>/
  run.json
  task.md
  config.snapshot.yml
  prompt.1.md
  workspace.txt
  summary.md
```

本地 Git 闭环验证：

```bash
./bin/ai-loop run \
  --repo /home/user/JAVA/ai/ai-loop \
  --task tasks/bootstrap-ai-loop.md
```

非 dry-run 应在本地 `git worktree` 中执行 Agent，收集 `diff.N.patch`，通过 SafetyChecker 后运行 verify commands，失败时生成下一轮 `prompt.N.md` 并重试。
