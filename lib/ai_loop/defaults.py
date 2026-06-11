"""Default files used by `ai-loop init`."""

DEFAULT_CONFIG = """version: 1

workspace:
  provider: git-worktree
  root: /tmp/ai-loop/workspaces
  cleanup: keep-on-failure
  branch_prefix: ai-loop/

agent:
  executor: codex
  command: codex
  args:
    - exec
    - -s
    - workspace-write
  timeout_sec: 1800
  max_iterations: 3

verify:
  commands:
    - name: python syntax
      command: python3 -m py_compile lib/ai_loop/*.py
      shell: true
      cwd: .
      timeout_sec: 120
      required: true
    - name: cli help
      command: ./bin/ai-loop --help
      shell: true
      cwd: .
      timeout_sec: 30
      required: true

safety:
  forbid_paths:
    - .env
    - secrets/
    - "*.pem"
    - id_rsa
  max_changed_files: 50
  max_diff_lines: 3000
  allow_network: false
  allow_push: false
  redact:
    enabled: true
    patterns:
      - "(?i)(token|secret|password|apikey|api_key)\\s*[=:]\\s*\\S+"
      - "AKIA[0-9A-Z]{16}"
      - "Bearer\\s+[A-Za-z0-9._-]+"

artifacts:
  root: runs
  log_tail_lines_for_retry: 200
  max_log_bytes: 10485760
"""

BOOTSTRAP_TASK = """# bootstrap-ai-loop

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

## 不允许做

1. 不自动 commit
2. 不自动 push
3. 不自动创建 MR
4. 不接 Multica
5. 不做发布

## 当前切片验收

第一轮先实现 dry-run 全链路：

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
  summary.md
```
"""
