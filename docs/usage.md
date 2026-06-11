# AI Loop 使用手册

## 1. 定位

AI Loop 是一个本地优先的 Agent 工程闭环控制器。它不让 Agent 自由发挥，而是把 Agent 放进确定性的工程管道里：先把不清晰的需求规划成可执行任务，再创建隔离工作区、生成 Prompt、调用 `codex exec`、收集 diff、执行安全检查、运行验证命令、失败后生成下一轮 Prompt、最终产出 patch 和 summary。

当前项目地址：

```bash
/home/user/JAVA/ai/ai-loop
```

默认原则：

- 所有 Loop 任务先走窗口内 Loop 协议，再决定是否调用本地 CLI。
- 只使用本地 Git。
- 不自动 push。
- 不自动创建 MR。
- 不自动发布或部署。
- 不接远程仓库作为 MVP 默认路径。

## 2. 适用场景

适合使用 AI Loop 的任务：

- 目标还不清晰、需要先拆方案的任务，可以先进入 `plan` 阶段。
- 有明确任务文件，例如 `tasks/fix-xxx.md`。
- 可以通过命令验证，例如 lint、单测、编译、脚本检查。
- 希望保留完整执行证据，包括 Prompt、Agent 日志、diff、verify 日志和 summary。
- 希望 Agent 失败后自动带着失败上下文重试。

不适合直接进入真实执行阶段的任务：

- 需要先大量讨论方案、还没有明确验收标准。
- 需要访问生产环境、发布系统或远程 MR。
- 需要交互式人工审批的高风险操作。

这些任务不是排除在 Loop 之外，而是应该先进入 `ai-loop plan` 阶段。规划完成后，再把产出的 `plan.md` 或其中的任务草案转成可执行任务文件，继续 dry-run 或真实执行。

## 3. 核心命令

窗口内 Loop 协议见：`docs/in-window-loop.md`。

进入 AI Loop 项目：

```bash
cd /home/user/JAVA/ai/ai-loop
```

初始化目标仓库：

```bash
./bin/ai-loop init --repo <target-repo>
```

dry-run 检查编排链路：

```bash
./bin/ai-loop run \
  --repo <target-repo> \
  --task <task-file> \
  --dry-run
```

规划不清晰任务：

```bash
./bin/ai-loop plan \
  --repo <target-repo> \
  --task <raw-request-file>
```

规划 dry-run：

```bash
./bin/ai-loop plan \
  --repo <target-repo> \
  --task <raw-request-file> \
  --dry-run
```

真实执行本地 Loop：

```bash
./bin/ai-loop run \
  --repo <target-repo> \
  --task <task-file>
```

查看运行状态：

```bash
./bin/ai-loop status --repo <target-repo> <run-id>
```

## 4. 推荐流程

### 4.1 准备任务文件

在目标仓库创建任务文件，例如：

```bash
mkdir -p tasks
cat > tasks/fix-example.md <<'EOF'
# fix-example

## 目标

修复 example 模块中的失败测试。

## 验收

- `npm test` 通过
- 不修改发布配置
- 不提交代码
EOF
```

如果任务还不清晰，可以先准备原始需求文件，例如：

```bash
mkdir -p tasks
cat > tasks/raw-loop-request.md <<'EOF'
# raw-loop-request

## 原始需求

我们想把某个工程能力接进 AI Loop，但还没有明确方案、范围和验收标准。
EOF
```

然后先跑规划阶段：

```bash
cd /home/user/JAVA/ai/ai-loop
./bin/ai-loop plan --repo <target-repo> --task tasks/raw-loop-request.md
```

规划阶段会产出 `runs/<run-id>/plan.md`，其中包含可保存到 `tasks/` 的任务草案。

### 4.2 确认目标仓库干净

真实执行前建议确认：

```bash
git -C <target-repo> status -sb
```

如果存在未提交改动，先人工确认是提交、stash，还是只跑 dry-run。

### 4.3 先跑 dry-run

```bash
cd /home/user/JAVA/ai/ai-loop
./bin/ai-loop run --repo <target-repo> --task tasks/fix-example.md --dry-run
```

dry-run 只生成编排 artifact，不会调用 Agent，不会执行 verify，不会生成真实 patch。

### 4.4 再跑真实 Loop

```bash
cd /home/user/JAVA/ai/ai-loop
./bin/ai-loop run --repo <target-repo> --task tasks/fix-example.md
```

真实 Loop 会：

1. 读取 `<target-repo>/.ai-loop.yml`。
2. 创建 `<target-repo>/runs/<run-id>/`。
3. 用本地 `git worktree` 创建隔离 workspace。
4. 生成 `prompt.1.md`。
5. 调用 `codex exec`。
6. 收集 `diff.N.patch`。
7. 执行 SafetyChecker。
8. 执行 verify commands。
9. verify 失败时生成下一轮 `prompt.N.md` 并重试。
10. 生成 `summary.md`。

### 4.5 规划阶段

`ai-loop plan` 是 Loop 的第一阶段，专门处理“还不能直接执行”的任务。

它会：

1. 读取原始需求文件。
2. 生成规划 Prompt。
3. 使用只读 sandbox 调用 `codex exec`。
4. 不创建 worktree。
5. 不修改文件。
6. 不执行 verify commands。
7. 生成 `plan.md` 和 `summary.md`。

`plan.md` 应包含问题定义、假设、开放问题、范围、非目标、实现步骤、建议检查文件、预期 artifact、验证命令、安全边界，以及一份可直接进入 `ai-loop run` 的任务 Markdown 草案。

## 5. 配置文件

目标仓库通过 `.ai-loop.yml` 配置 Loop 行为。默认结构：

```yaml
version: 1

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

artifacts:
  root: runs
  log_tail_lines_for_retry: 200
```

注意：YAML 中 `true`、`false`、`on`、`off` 等词可能被解析成布尔值。作为命令或名称时建议加引号，例如：

```yaml
name: "true"
command: "true"
```

## 6. Artifact 说明

每次运行会在目标仓库生成：

```text
runs/<run-id>/
  run.json
  task.md
  config.snapshot.yml
  workspace.txt
  prompt.1.md
  agent.1.log
  agent.1.json
  agent.1.final.md
  diff.1.patch
  diff.1.json
  safety.1.json
  verify.1.json
  verify.1.*.stdout.log
  verify.1.*.stderr.log
  summary.md
```

关键文件：

- `run.json`：运行状态、错误码、workspace、patch 路径。
- `config.snapshot.yml`：本次执行使用的配置快照。
- `prompt.N.md`：给 Agent 的第 N 轮 Prompt。
- `agent.N.log`：Agent 执行日志。
- `agent.N.final.md`：Agent 最终回复。
- `diff.N.patch`：第 N 轮之后的 Git diff。
- `safety.N.json`：安全检查结果。
- `verify.N.json`：验证命令结果。
- `summary.md`：给人看的运行总结。

## 7. 状态与错误码

常见状态：

- `PASSED`：Loop 成功。
- `FAILED`：Loop 失败，具体原因看 `error_code`。
- `PLAN_READY`：规划 Prompt 已生成。
- `PLANNING_AGENT_RUNNING`：规划 Agent 正在执行。
- `CONFIG_LOADED`：配置已加载。
- `WORKSPACE_READY`：worktree 已创建。
- `AGENT_RUNNING`：Agent 正在执行。
- `DIFF_COLLECTED`：已收集 patch。
- `SAFETY_PASSED`：安全检查通过。
- `RETRY_READY`：已生成下一轮 retry prompt。

常见错误码：

- `FAILED_CONFIG`：配置错误。
- `FAILED_WORKSPACE`：工作区创建失败。
- `FAILED_AGENT_TIMEOUT`：Agent 超时。
- `FAILED_AGENT_EXIT`：Agent 非 0 退出。
- `FAILED_SAFETY`：安全检查失败。
- `FAILED_VERIFY`：验证命令失败。
- `FAILED_MAX_ITERATIONS`：超过最大重试次数。

## 8. 后续对话默认约定

以后如果用户说“做一个 Loop 任务”“用 Loop 跑一下”“把这个交给 Loop”，默认按下面方式处理：

1. 优先使用 `/home/user/JAVA/ai/ai-loop`。
2. 默认只用本地 Git，不访问远程。
3. 如果任务不清晰，先用 `ai-loop plan` 产出方案和任务草案。
4. 如果任务已清晰，先确认目标仓库、任务文件和验证命令。
5. 优先 dry-run，再根据情况执行真实 Loop。
6. 结果以 `runs/<run-id>/summary.md`、`plan.md` 或 `diff.N.patch` 为准。

## 9. 排障

### 源仓库不干净

错误表现：

```text
source repo is dirty; commit or stash changes before creating a worktree
```

处理方式：提交、stash，或只跑 dry-run。

### workspace 已存在

错误表现：

```text
workspace already exists
```

处理方式：换一个 `--run-id`，或人工清理 `/tmp/ai-loop/workspaces/<run-id>`。

### verify 命令被 YAML 解析错

错误表现：命令显示成 `True`、`False` 等。

处理方式：给 `name` 和 `command` 加引号。

### Codex 参数不兼容

当前本机 `codex exec` 使用：

```bash
codex exec -s workspace-write -C <workspace> -o <final-message-file> -
```

如果 Codex CLI 升级导致参数变化，优先执行：

```bash
codex exec --help
```

然后更新 `.ai-loop.yml` 的 `agent.args`。
