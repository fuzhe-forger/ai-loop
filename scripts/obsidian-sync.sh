#!/bin/bash
# Obsidian 聚合同步脚本 v3：从 Multica、Loop、CodeGraph 沉淀到 Obsidian。
# 只写 99-generated/ 目录，不覆盖人工文档。
set -euo pipefail

VAULT_PATH="${VAULT_PATH:-/mnt/d/JAVA/knowledge/tiandao}"
REPO_ROOT="${REPO_ROOT:-/home/user/JAVA/ai/ai-loop}"
JAVA_ROOT="${JAVA_ROOT:-/mnt/d/JAVA}"
DRY_RUN="${DRY_RUN:-true}"
ARCHIVED_ISSUE_RETENTION_DAYS="${ARCHIVED_ISSUE_RETENTION_DAYS:-7}"

echo "Obsidian 聚合同步 v3"
echo "  Vault: $VAULT_PATH"
echo "  Repo: $REPO_ROOT"
echo "  Java root: $JAVA_ROOT"
echo "  DRY_RUN: $DRY_RUN"
echo "  Archived issue retention days: $ARCHIVED_ISSUE_RETENTION_DAYS"

if [[ ! -d "$VAULT_PATH" ]]; then
  echo "ERROR: Vault 不存在: $VAULT_PATH"
  exit 1
fi

if [[ ! -d "$REPO_ROOT" ]]; then
  echo "ERROR: Repo 不存在: $REPO_ROOT"
  exit 1
fi

GENERATED="$VAULT_PATH/99-generated"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p \
  "$GENERATED/multica" \
  "$GENERATED/loop/docs" \
  "$GENERATED/loop/runs" \
  "$GENERATED/agents" \
  "$GENERATED/autopilots" \
  "$GENERATED/codegraph/repositories"

echo ""
echo "## 1. 读取 Multica 快照"
multica project list --output json > "$TMP_DIR/projects.json" 2>/dev/null || echo '[]' > "$TMP_DIR/projects.json"
multica agent list --include-archived --output json > "$TMP_DIR/agents.json" 2>/dev/null || echo '[]' > "$TMP_DIR/agents.json"
multica runtime list --output json > "$TMP_DIR/runtimes.json" 2>/dev/null || echo '[]' > "$TMP_DIR/runtimes.json"
multica autopilot list --output json > "$TMP_DIR/autopilots.json" 2>/dev/null || echo '{"autopilots":[]}' > "$TMP_DIR/autopilots.json"
multica issue list --limit 600 --offset 0 --output json > "$TMP_DIR/issues.json" 2>/dev/null || echo '{"issues":[]}' > "$TMP_DIR/issues.json"

echo ""
echo "## 2. 生成 Multica 快照页"
python3 - <<'PY' "$TMP_DIR/projects.json" "$TMP_DIR/projects.md"
import json
import sys
from pathlib import Path

projects = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8") or "[]")
lines = []
lines.append("---\n")
lines.append("type: multica_snapshot\n")
lines.append("source: multica project list\n")
lines.append("generated: auto\n")
lines.append("---\n\n")
lines.append("# Multica 项目快照\n\n")
lines.append("由 `obsidian-sync.sh` 自动生成，可覆盖。\n\n")
lines.append("| 项目 | 状态 | 优先级 | issue数 | done数 | 更新时间 |\n")
lines.append("|---|---|---|---:|---:|---|\n")
for project in sorted(projects, key=lambda item: (item.get("status") != "in_progress", item.get("title") or "")):
    title = (project.get("title") or "").replace("|", "\\|")
    lines.append(
        f"| {title} | {project.get('status')} | {project.get('priority')} | "
        f"{project.get('issue_count')} | {project.get('done_count')} | {project.get('updated_at')} |\n"
    )
Path(sys.argv[2]).write_text("".join(lines), encoding="utf-8")
print(f"生成: {sys.argv[2]}")
PY

python3 - <<'PY' "$TMP_DIR/issues.json" "$TMP_DIR/projects.json" "$TMP_DIR/agents.json" "$TMP_DIR/active-issues.md" "$TMP_DIR/archived-issues.md" "$ARCHIVED_ISSUE_RETENTION_DAYS"
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

issues_data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8") or "{}")
projects = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8") or "[]")
agents = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8") or "[]")
issues = issues_data.get("issues") or []
project_by_id = {project.get("id"): project.get("title") for project in projects}
agent_by_id = {agent.get("id"): agent.get("name") for agent in agents}
active = [issue for issue in issues if issue.get("status") not in ("done", "cancelled")]
archived = [issue for issue in issues if issue.get("status") in ("done", "cancelled")]
retention_days = int(sys.argv[6])
cutoff = datetime.now(timezone.utc) - timedelta(days=retention_days)


def parse_time(value):
    if not value:
        return datetime.fromtimestamp(0, timezone.utc)
    return datetime.fromisoformat(value).astimezone(timezone.utc)


recent_archived = [issue for issue in archived if parse_time(issue.get("updated_at")) >= cutoff]


def project_name(issue):
    return project_by_id.get(issue.get("project_id")) or "未归属"


def assignee_name(issue):
    if not issue.get("assignee_id"):
        return "未分配"
    if issue.get("assignee_type") == "agent":
        return agent_by_id.get(issue.get("assignee_id")) or issue.get("assignee_id")
    return issue.get("assignee_id")


def write_issue_table(path, heading, rows, note):
    lines = []
    lines.append("---\n")
    lines.append("type: multica_snapshot\n")
    lines.append("source: multica issue list\n")
    lines.append("generated: auto\n")
    lines.append("---\n\n")
    lines.append(f"# {heading}\n\n")
    lines.append("由 `obsidian-sync.sh` 自动生成，可覆盖。\n\n")
    lines.append(f"{note}\n\n")
    lines.append("| Issue | 状态 | 优先级 | 项目 | 负责人 | 更新时间 | 标题 |\n")
    lines.append("|---|---|---|---|---|---|---|\n")
    for issue in rows:
        title = (issue.get("title") or "").replace("|", "\\|")[:100]
        lines.append(
            f"| {issue.get('identifier')} | {issue.get('status')} | {issue.get('priority')} | "
            f"{project_name(issue)} | {assignee_name(issue)} | {issue.get('updated_at')} | {title} |\n"
        )
    Path(path).write_text("".join(lines), encoding="utf-8")


write_issue_table(
    sys.argv[4],
    "Multica 活跃 Issue",
    sorted(active, key=lambda item: (item.get("status"), item.get("updated_at") or "")),
    f"活跃总数：{len(active)}",
)
write_issue_table(
    sys.argv[5],
    "Multica 已归档 Issue",
    sorted(recent_archived, key=lambda item: item.get("updated_at") or "", reverse=True),
    f"已归档总数：{len(archived)}；此页仅保留最近 {retention_days} 天记录，当前展示 {len(recent_archived)} 条。",
)
print(f"生成: {sys.argv[4]}")
print(f"生成: {sys.argv[5]}")
PY

python3 - <<'PY' "$TMP_DIR/agents.json" "$TMP_DIR/runtimes.json" "$TMP_DIR/runtime-status.md"
import json
import sys
from pathlib import Path

agents = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8") or "[]")
runtimes = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8") or "[]")
runtime_by_id = {runtime.get("id"): runtime for runtime in runtimes}
lines = []
lines.append("---\n")
lines.append("type: multica_snapshot\n")
lines.append("source: multica agent/runtime list\n")
lines.append("generated: auto\n")
lines.append("---\n\n")
lines.append("# Runtime 与智能体状态\n\n")
lines.append("由 `obsidian-sync.sh` 自动生成，可覆盖。\n\n")
lines.append("## Runtime 清单\n\n")
lines.append("| Runtime | Provider | 状态 | 设备 | 最后在线 |\n")
lines.append("|---|---|---|---|---|\n")
for runtime in sorted(runtimes, key=lambda item: (item.get("status") != "online", item.get("name") or "")):
    name = (runtime.get("name") or "").replace("|", "\\|")
    device = (runtime.get("device_info") or "").replace("|", "\\|")
    lines.append(f"| {name} | {runtime.get('provider')} | {runtime.get('status')} | {device} | {runtime.get('last_seen_at')} |\n")
lines.append("\n## 智能体状态\n\n")
lines.append("| 智能体 | 状态 | Runtime | 模型 | Skills | 归档 |\n")
lines.append("|---|---|---|---|---:|---|\n")
for agent in sorted(agents, key=lambda item: (bool(item.get("archived_at")), item.get("name") or "")):
    runtime = runtime_by_id.get(agent.get("runtime_id"), {})
    archived = "是" if agent.get("archived_at") else "否"
    name = (agent.get("name") or "").replace("|", "\\|")
    runtime_name = (runtime.get("name") or "").replace("|", "\\|")
    model = (agent.get("model") or "").replace("|", "\\|")
    lines.append(f"| {name} | {agent.get('status')} | {runtime_name} | {model} | {len(agent.get('skills') or [])} | {archived} |\n")
Path(sys.argv[3]).write_text("".join(lines), encoding="utf-8")
print(f"生成: {sys.argv[3]}")
PY

python3 - <<'PY' "$TMP_DIR/autopilots.json" "$TMP_DIR/projects.json" "$TMP_DIR/agents.json" "$TMP_DIR/autopilots.md" "$TMP_DIR/paused-autopilots.md"
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8") or "{}")
projects = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8") or "[]")
agents = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8") or "[]")
autopilots = data.get("autopilots") or []
project_by_id = {project.get("id"): project.get("title") for project in projects}
agent_by_id = {agent.get("id"): agent.get("name") for agent in agents}
active = [autopilot for autopilot in autopilots if autopilot.get("status") == "active"]
paused = [autopilot for autopilot in autopilots if autopilot.get("status") == "paused"]


def agent_name(autopilot):
    return agent_by_id.get(autopilot.get("assignee_id")) or autopilot.get("assignee_id") or "未分配"


def project_name(autopilot):
    return project_by_id.get(autopilot.get("project_id")) or "未指定"


lines = []
lines.append("---\n")
lines.append("type: multica_snapshot\n")
lines.append("source: multica autopilot list\n")
lines.append("generated: auto\n")
lines.append("---\n\n")
lines.append("# Autopilot 定时任务状态\n\n")
lines.append("由 `obsidian-sync.sh` 自动生成，可覆盖。\n\n")
lines.append(f"- active: {len(active)}\n")
lines.append(f"- paused: {len(paused)}\n\n")
lines.append("| Autopilot | 状态 | 绑定智能体 | 项目 | 最近运行 |\n")
lines.append("|---|---|---|---|---|\n")
for autopilot in sorted(autopilots, key=lambda item: (item.get("status") != "active", item.get("title") or "")):
    title = (autopilot.get("title") or "").replace("|", "\\|")
    lines.append(f"| {title} | {autopilot.get('status')} | {agent_name(autopilot)} | {project_name(autopilot)} | {autopilot.get('last_run_at')} |\n")
Path(sys.argv[4]).write_text("".join(lines), encoding="utf-8")
print(f"生成: {sys.argv[4]}")

pause_lines = []
pause_lines.append("---\n")
pause_lines.append("type: multica_snapshot\n")
pause_lines.append("source: multica autopilot list\n")
pause_lines.append("generated: auto\n")
pause_lines.append("---\n\n")
pause_lines.append("# 已暂停 Autopilot\n\n")
pause_lines.append("由 `obsidian-sync.sh` 自动生成，可覆盖。\n\n")
pause_lines.append(f"暂停总数：{len(paused)}\n\n")
for autopilot in sorted(paused, key=lambda item: item.get("title") or ""):
    title = (autopilot.get("title") or "").replace("|", "\\|")
    pause_lines.append(f"- {title}（{agent_name(autopilot)}）\n")
Path(sys.argv[5]).write_text("".join(pause_lines), encoding="utf-8")
print(f"生成: {sys.argv[5]}")
PY

echo ""
echo "## 3. 生成 Loop run 索引"
if [[ -d "$REPO_ROOT/runs" ]]; then
  python3 - <<'PY' "$REPO_ROOT/runs" "$TMP_DIR/runs-index.md"
import json
import sys
from pathlib import Path

runs_dir = Path(sys.argv[1])
runs = []
for run_dir in runs_dir.iterdir():
    if not run_dir.is_dir():
        continue
    summary = run_dir / "summary.md"
    run_json = run_dir / "run.json"
    if run_json.exists():
        try:
            metadata = json.loads(run_json.read_text(encoding="utf-8"))
            runs.append(
                {
                    "id": run_dir.name,
                    "status": metadata.get("status"),
                    "updated": metadata.get("updated_at"),
                    "has_summary": summary.exists(),
                }
            )
        except Exception:
            pass
lines = []
lines.append("---\n")
lines.append("type: loop_snapshot\n")
lines.append("source: loop runs/\n")
lines.append("generated: auto\n")
lines.append("---\n\n")
lines.append("# Loop Run 证据索引\n\n")
lines.append("由 `obsidian-sync.sh` 自动生成，可覆盖。\n\n")
lines.append(f"Run 总数：{len(runs)}\n\n")
lines.append("| Run ID | 状态 | Summary | 更新时间 |\n")
lines.append("|---|---|---|---|\n")
for run in sorted(runs, key=lambda item: item.get("updated") or "", reverse=True)[:100]:
    run_id = str(run["id"]).replace("|", "\\|")
    lines.append(f"| {run_id} | {run.get('status')} | {'✓' if run.get('has_summary') else '✗'} | {run.get('updated')} |\n")
Path(sys.argv[2]).write_text("".join(lines), encoding="utf-8")
print(f"生成: {sys.argv[2]}")
PY
else
  echo "SKIP: runs/ 不存在"
  cat > "$TMP_DIR/runs-index.md" <<'EOF'
# Loop Run 证据索引

runs/ 不存在，未生成。
EOF
fi

echo ""
echo "## 4. 生成 ai-loop 文档镜像"
if [[ -d "$REPO_ROOT/docs/ai-work-orchestration" ]]; then
  python3 - <<'PY' "$REPO_ROOT/docs/ai-work-orchestration" "$TMP_DIR/ai-loop-docs" "$TMP_DIR/ai-loop-docs-index.md"
import sys
from pathlib import Path

docs_dir = Path(sys.argv[1])
out_dir = Path(sys.argv[2])
out_dir.mkdir(parents=True, exist_ok=True)
copied = []
for source in sorted(docs_dir.glob("*.md")):
    if source.name not in ("README.md", "logbook.md"):
        destination = out_dir / source.name
        destination.write_text(source.read_text(encoding="utf-8"), encoding="utf-8")
        copied.append(source.name)
lines = []
lines.append("---\n")
lines.append("type: ai_loop_docs\n")
lines.append("source: docs/ai-work-orchestration\n")
lines.append("generated: auto\n")
lines.append("---\n\n")
lines.append("# AI 工作编排文档索引\n\n")
lines.append("由 `obsidian-sync.sh` 自动生成，可覆盖。\n\n")
lines.append("## 规划与设计\n\n")
for filename in sorted(copied):
    stem = filename.removesuffix(".md")
    lines.append(f"- [[../loop/docs/{filename}|{stem}]]\n")
lines.append("\n## 案例\n\n")
if (docs_dir / "cases").exists():
    for case_dir in sorted((docs_dir / "cases").iterdir()):
        if case_dir.is_dir():
            lines.append(f"- 案例：{case_dir.name}\n")
lines.append("\n## 阶段报告\n\n")
if (docs_dir / "reports").exists():
    for report in sorted((docs_dir / "reports").glob("*.md"), reverse=True)[:30]:
        lines.append(f"- [[../../docs/ai-work-orchestration/reports/{report.name}|{report.stem}]]\n")
Path(sys.argv[3]).write_text("".join(lines), encoding="utf-8")
print(f"镜像沉淀: {len(copied)} 文档")
print(f"生成: {sys.argv[3]}")
PY
else
  echo "SKIP: docs/ai-work-orchestration 不存在"
fi

echo ""
echo "## 5. 生成 CodeGraph 索引与仓库卡片"
python3 - <<'PY' "$JAVA_ROOT" "$TMP_DIR/codegraph-index.md" "$TMP_DIR/codegraph-cards"
import subprocess
import sys
from pathlib import Path

java_root = Path(sys.argv[1])
index_path = Path(sys.argv[2])
cards_dir = Path(sys.argv[3])
cards_dir.mkdir(parents=True, exist_ok=True)

repos = []
for base in [java_root, java_root / "services", java_root / "frontends", java_root / "shared", java_root / "ai"]:
    if not base.exists():
        continue
    for item in sorted(base.iterdir()):
        if (item / ".codegraph").is_dir():
            repos.append(item)


def detect_kind(path):
    value = str(path)
    if "/services/" in value:
        return "后端服务"
    if "/frontends/" in value:
        return "前端项目"
    if "/shared/" in value:
        return "共享库"
    if "/ai/" in value:
        return "AI 工具/基础设施"
    return "根索引/其他"


def git_value(path, args):
    try:
        return subprocess.check_output(["git", "-C", str(path)] + args, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""


def tracked_files(path):
    output = git_value(path, ["ls-files"])
    if output:
        return output.splitlines()
    # fallback: keep shallow and skip heavy generated dirs
    files = []
    skip = {"node_modules", "target", "dist", "build", ".git", ".codegraph"}
    for child in path.iterdir():
        if child.name in skip:
            continue
        if child.is_file():
            files.append(child.name)
        elif child.is_dir():
            for nested in child.rglob("*"):
                if any(part in skip for part in nested.parts):
                    continue
                if nested.is_file():
                    files.append(str(nested.relative_to(path)))
    return files


def count_suffix(files, suffixes):
    return sum(1 for file_name in files if any(file_name.endswith(suffix) for suffix in suffixes))


index_lines = []
index_lines.append("---\n")
index_lines.append("type: codegraph_index\n")
index_lines.append("source: scan codegraph directories\n")
index_lines.append("generated: auto\n")
index_lines.append("---\n\n")
index_lines.append("# CodeGraph 代码索引快照\n\n")
index_lines.append("由 `obsidian-sync.sh` 自动生成，可覆盖。\n\n")
index_lines.append(f"已索引仓库：{len(repos)}\n\n")
index_lines.append("| 仓库 | 类型 | 路径 | 知识卡片 |\n")
index_lines.append("|---|---|---|---|\n")

for repo in repos:
    rel = repo.relative_to(java_root)
    name = repo.name
    kind = detect_kind(repo)
    branch = git_value(repo, ["branch", "--show-current"]) or "未知"
    head = git_value(repo, ["rev-parse", "--short", "HEAD"]) or "未知"
    files = tracked_files(repo)
    java_count = count_suffix(files, [".java", ".kt"])
    ts_count = count_suffix(files, [".ts", ".tsx", ".js", ".jsx", ".vue"])
    md_count = count_suffix(files, [".md"])
    has_pom = "是" if (repo / "pom.xml").exists() else "否"
    has_package = "是" if (repo / "package.json").exists() else "否"
    card_name = f"{name}.md"
    index_lines.append(f"| {name.replace('|','\\|')} | {kind} | {str(rel).replace('|','\\|')} | [[repositories/{card_name}|卡片]] |\n")

    card_lines = []
    card_lines.append("---\n")
    card_lines.append("type: codegraph_repo_card\n")
    card_lines.append(f"name: {name}\n")
    card_lines.append(f"path: {rel}\n")
    card_lines.append(f"kind: {kind}\n")
    card_lines.append("generated: auto\n")
    card_lines.append("---\n\n")
    card_lines.append(f"# {name}\n\n")
    card_lines.append("## 基本信息\n\n")
    card_lines.append(f"- 类型：{kind}\n")
    card_lines.append(f"- 路径：`D:/JAVA/{rel}`\n")
    card_lines.append(f"- CodeGraph：`D:/JAVA/{rel}/.codegraph`\n")
    card_lines.append(f"- Git 分支：`{branch}`\n")
    card_lines.append(f"- Git HEAD：`{head}`\n")
    card_lines.append("\n## 文件画像\n\n")
    card_lines.append(f"- Java/Kotlin 文件：{java_count}\n")
    card_lines.append(f"- TS/JS/Vue 文件：{ts_count}\n")
    card_lines.append(f"- Markdown 文件：{md_count}\n")
    card_lines.append(f"- Maven：{has_pom}\n")
    card_lines.append(f"- Node/package：{has_package}\n")
    card_lines.append("\n## 使用方式\n\n")
    card_lines.append("- 代码结构、符号、调用关系：通过 CodeGraph MCP 查询。\n")
    card_lines.append("- 稳定业务知识：在人工区 `04-项目知识/` 补充。\n")
    card_lines.append("- 本页由 `obsidian-sync.sh` 生成，可覆盖。\n")
    card_lines.append("\n## 待人工补充\n\n")
    card_lines.append("- 项目定位\n")
    card_lines.append("- 核心模块\n")
    card_lines.append("- 关键接口\n")
    card_lines.append("- 常见问题\n")
    card_lines.append("- 关联 Multica 项目/Issue\n")
    (cards_dir / card_name).write_text("".join(card_lines), encoding="utf-8")

index_lines.append("\n## MCP 服务\n\n")
index_lines.append("- CodeGraph MCP 可为智能体提供代码结构、符号、调用关系查询。\n")
index_lines.append("- 启动：`codegraph serve --mcp --no-watch`\n")
index_path.write_text("".join(index_lines), encoding="utf-8")
print(f"扫描仓库: {len(repos)}")
print(f"生成: {index_path}")
print(f"生成 CodeGraph 仓库卡片: {len(repos)}")
PY

echo ""
echo "## 6. 生成 Loop run 证据页"
if [[ -d "$REPO_ROOT/runs" ]]; then
  python3 - <<'PY' "$REPO_ROOT/runs" "$TMP_DIR/loop-runs"
from pathlib import Path
import sys

runs_dir = Path(sys.argv[1])
out_dir = Path(sys.argv[2])
out_dir.mkdir(parents=True, exist_ok=True)
count = 0
for run_dir in sorted(runs_dir.iterdir(), key=lambda item: item.name, reverse=True)[:50]:
    if not run_dir.is_dir():
        continue
    summary = run_dir / "summary.md"
    stage = run_dir / "stage-report.md"
    verify = run_dir / "verification-report.md"
    if not summary.exists():
        continue
    lines = []
    lines.append("---\n")
    lines.append("type: loop_run\n")
    lines.append(f"run_id: {run_dir.name}\n")
    lines.append(f"source: runs/{run_dir.name}\n")
    lines.append("generated: auto\n")
    lines.append("---\n\n")
    lines.append(f"# Loop Run: {run_dir.name}\n\n")
    lines.append("## Summary\n\n")
    lines.append(summary.read_text(encoding="utf-8"))
    if stage.exists():
        stage_text = stage.read_text(encoding="utf-8")
        lines.append("\n\n## Stage Report\n\n")
        lines.append(stage_text[:3000])
        if len(stage_text) > 3000:
            lines.append("\n\n_(摘录前 3000 字符，完整内容见 runs/ 目录)_\n")
    if verify.exists():
        verify_text = verify.read_text(encoding="utf-8")
        lines.append("\n\n## Verification Report\n\n")
        lines.append(verify_text[:2000])
        if len(verify_text) > 2000:
            lines.append("\n\n_(摘录前 2000 字符，完整内容见 runs/ 目录)_\n")
    (out_dir / f"{run_dir.name}.md").write_text("".join(lines), encoding="utf-8")
    count += 1
print(f"生成 run 证据页: {count}")
PY
else
  echo "SKIP: runs/ 不存在"
fi

echo ""
echo "## 7. 写入 99-generated"
if [[ "$DRY_RUN" == "false" ]]; then
  cp "$TMP_DIR/projects.md" "$GENERATED/multica/projects.md"
  cp "$TMP_DIR/active-issues.md" "$GENERATED/multica/active-issues.md"
  cp "$TMP_DIR/archived-issues.md" "$GENERATED/multica/archived-issues.md"
  cp "$TMP_DIR/runtime-status.md" "$GENERATED/agents/runtime-status.md"
  cp "$TMP_DIR/autopilots.md" "$GENERATED/autopilots/autopilots.md"
  cp "$TMP_DIR/paused-autopilots.md" "$GENERATED/autopilots/paused-autopilots.md"
  cp "$TMP_DIR/runs-index.md" "$GENERATED/loop/runs-index.md"
  if [[ -f "$TMP_DIR/ai-loop-docs-index.md" ]]; then
    cp "$TMP_DIR/ai-loop-docs-index.md" "$GENERATED/loop/ai-loop-docs-index.md"
    rsync -a "$TMP_DIR/ai-loop-docs/" "$GENERATED/loop/docs/"
    echo "镜像 ai-loop 文档到: $GENERATED/loop/docs/"
  fi
  if [[ -f "$TMP_DIR/codegraph-index.md" ]]; then
    cp "$TMP_DIR/codegraph-index.md" "$GENERATED/codegraph/repositories.md"
    rsync -a "$TMP_DIR/codegraph-cards/" "$GENERATED/codegraph/repositories/"
    echo "生成 CodeGraph 仓库卡片到: $GENERATED/codegraph/repositories/"
  fi
  if [[ -d "$TMP_DIR/loop-runs" ]]; then
    rsync -a "$TMP_DIR/loop-runs/" "$GENERATED/loop/runs/"
    echo "生成 Loop run 证据页到: $GENERATED/loop/runs/"
  fi
  echo "写入完成: $GENERATED"
else
  echo "DRY_RUN=true，未写入 $GENERATED"
fi

echo ""
echo "完成。DRY_RUN=$DRY_RUN"
