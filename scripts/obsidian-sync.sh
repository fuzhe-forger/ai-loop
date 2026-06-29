#!/bin/bash
# Obsidian 聚合同步脚本 v3：从 Multica、Loop、CodeGraph 沉淀到 Obsidian。
# 只写 99-generated/ 目录，不覆盖人工文档。
set -euo pipefail

export HOME="${HOME:-/home/user}"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/user/.local/bin:${PATH:-}"

VAULT_PATH="${VAULT_PATH:-/mnt/d/JAVA/knowledge/tiandao}"
REPO_ROOT="${REPO_ROOT:-/home/user/JAVA/ai/ai-loop}"
JAVA_ROOT="${JAVA_ROOT:-/mnt/d/JAVA}"
DRY_RUN="${DRY_RUN:-true}"
ARCHIVED_ISSUE_RETENTION_DAYS="${ARCHIVED_ISSUE_RETENTION_DAYS:-7}"
WRITE_OPERATION_LOG="${WRITE_OPERATION_LOG:-true}"
OPERATION_LOG_DIR="${OPERATION_LOG_DIR:-$REPO_ROOT/state/operations}"
SYNC_STARTED_AT="$(date '+%F %T %z')"

echo "Obsidian 聚合同步 v3"
echo "  Vault: $VAULT_PATH"
echo "  Repo: $REPO_ROOT"
echo "  Java root: $JAVA_ROOT"
echo "  DRY_RUN: $DRY_RUN"
echo "  Archived issue retention days: $ARCHIVED_ISSUE_RETENTION_DAYS"
echo "  Operation log: $WRITE_OPERATION_LOG"

if [[ ! -d "$VAULT_PATH" ]]; then
  echo "ERROR: Vault 不存在: $VAULT_PATH"
  exit 1
fi

if [[ ! -d "$REPO_ROOT" ]]; then
  echo "ERROR: Repo 不存在: $REPO_ROOT"
  exit 1
fi

if ! command -v multica >/dev/null 2>&1; then
  echo "ERROR: multica CLI 不在 PATH 中，停止同步以避免写入空快照。"
  exit 1
fi

GENERATED="$VAULT_PATH/99-generated"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p \
  "$GENERATED/multica" \
  "$GENERATED/multica/issues" \
  "$GENERATED/loop/docs" \
  "$GENERATED/loop/docs/config" \
  "$GENERATED/loop/runs" \
  "$GENERATED/agents" \
  "$GENERATED/autopilots" \
  "$GENERATED/governance" \
  "$GENERATED/codegraph/repositories"

echo ""
echo "## 1. 读取 Multica 快照"
multica project list --output json > "$TMP_DIR/projects.json" 2>/dev/null || echo '[]' > "$TMP_DIR/projects.json"
multica agent list --include-archived --output json > "$TMP_DIR/agents.json" 2>/dev/null || echo '[]' > "$TMP_DIR/agents.json"
multica runtime list --output json > "$TMP_DIR/runtimes.json" 2>/dev/null || echo '[]' > "$TMP_DIR/runtimes.json"
multica autopilot list --output json > "$TMP_DIR/autopilots.json" 2>/dev/null || echo '{"autopilots":[]}' > "$TMP_DIR/autopilots.json"

ISSUE_PAGE_LIMIT=100
ISSUE_STATUSES=(backlog todo in_progress in_review blocked done cancelled)
mkdir -p "$TMP_DIR/issue-pages"
for issue_status in "${ISSUE_STATUSES[@]}"; do
  issue_offset=0
  while true; do
    issue_page="$TMP_DIR/issue-pages/${issue_status}-${issue_offset}.json"
    if ! multica issue list --status "$issue_status" --limit "$ISSUE_PAGE_LIMIT" --offset "$issue_offset" --output json > "$issue_page" 2>/dev/null; then
      echo '{"issues":[]}' > "$issue_page"
      break
    fi
    issue_page_count=$(python3 - <<'PY' "$issue_page"
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8") or "{}")
print(len(data.get("issues") or []))
PY
)
    if (( issue_page_count < ISSUE_PAGE_LIMIT )); then
      break
    fi
    issue_offset=$((issue_offset + ISSUE_PAGE_LIMIT))
  done
done
python3 - <<'PY' "$TMP_DIR/issue-pages" "$TMP_DIR/issues.json"
import json
import sys
from pathlib import Path

pages_dir = Path(sys.argv[1])
out_path = Path(sys.argv[2])
issues_by_key = {}
for page in sorted(pages_dir.glob("*.json")):
    data = json.loads(page.read_text(encoding="utf-8") or "{}")
    for issue in data.get("issues") or []:
        key = issue.get("id") or issue.get("identifier") or str(issue.get("number") or "")
        if key:
            issues_by_key[key] = issue

issues = sorted(
    issues_by_key.values(),
    key=lambda issue: (issue.get("updated_at") or "", issue.get("identifier") or ""),
    reverse=True,
)
out_path.write_text(json.dumps({"issues": issues}, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"读取 issue: {len(issues)}")
PY

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

echo ""
echo "## 2.1 生成 Multica 可读摘要卡与外链索引"
python3 - <<'PY' "$TMP_DIR/issues.json" "$TMP_DIR/projects.json" "$TMP_DIR/agents.json" "$TMP_DIR/readable-summaries.md" "$TMP_DIR/issue-cards" "$TMP_DIR/external-links.md" "$ARCHIVED_ISSUE_RETENTION_DAYS"
import json
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

issues_data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8") or "{}")
projects = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8") or "[]")
agents = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8") or "[]")
index_path = Path(sys.argv[4])
cards_dir = Path(sys.argv[5])
links_path = Path(sys.argv[6])
retention_days = int(sys.argv[7])

cards_dir.mkdir(parents=True, exist_ok=True)
issues = issues_data.get("issues") or []
project_by_id = {project.get("id"): project.get("title") for project in projects}
agent_by_id = {agent.get("id"): agent.get("name") for agent in agents}
cutoff = datetime.now(timezone.utc) - timedelta(days=retention_days)


def parse_time(value):
    if not value:
        return datetime.fromtimestamp(0, timezone.utc)
    return datetime.fromisoformat(value).astimezone(timezone.utc)


def project_name(issue):
    return project_by_id.get(issue.get("project_id")) or "未归属"


def assignee_name(issue):
    if not issue.get("assignee_id"):
        return "未分配"
    if issue.get("assignee_type") == "agent":
        return agent_by_id.get(issue.get("assignee_id")) or issue.get("assignee_id")
    return issue.get("assignee_id")


def esc(value):
    return str(value or "").replace("|", "\\|").replace("\n", " ")


def section(markdown, heading):
    marker = f"## {heading}"
    start = markdown.find(marker)
    if start < 0:
        return ""
    body_start = markdown.find("\n", start)
    if body_start < 0:
        return ""
    next_heading = re.search(r"\n##\s+", markdown[body_start + 1:])
    if next_heading:
        end = body_start + 1 + next_heading.start()
    else:
        end = len(markdown)
    return markdown[body_start:end].strip()


def bullets_from_section(text, limit=5):
    bullets = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("- "):
            bullets.append(stripped)
        elif re.match(r"^\d+\.\s+", stripped):
            bullets.append("- " + re.sub(r"^\d+\.\s+", "", stripped))
        if len(bullets) >= limit:
            break
    return bullets


def fallback_summary(issue):
    title = issue.get("title") or issue.get("identifier") or "未命名 issue"
    return [f"- {title}", f"- 当前状态：{issue.get('status')}", "- 详情见 Evidence Links 或原始 issue 描述。"]


url_re = re.compile(r"https?://[^\s\])>\"']+")
path_re = re.compile(r"(?:(?:/home/user|/mnt/d|/tmp)/[^\s`|)]+|(?:tasks|runs|docs|scripts)/[^\s`|)]+)")


def extract_links(text):
    found = []
    seen = set()
    for kind, regex in (("url", url_re), ("path", path_re)):
        for match in regex.finditer(text):
            value = match.group(0).rstrip(".,;，。；")
            if value in seen:
                continue
            seen.add(value)
            found.append((kind, value))
    return found


visible = []
for issue in issues:
    status = issue.get("status")
    if status not in ("done", "cancelled") or parse_time(issue.get("updated_at")) >= cutoff:
        visible.append(issue)

visible = sorted(visible, key=lambda item: (item.get("status") in ("done", "cancelled"), item.get("updated_at") or ""), reverse=True)
all_links = []

for issue in visible:
    identifier = issue.get("identifier") or str(issue.get("number") or issue.get("id") or "unknown")
    description = issue.get("description") or ""
    core = bullets_from_section(section(description, "核心结论")) or fallback_summary(issue)
    pending = bullets_from_section(section(description, "待确认"), limit=10)
    next_steps = bullets_from_section(section(description, "下一步"), limit=10)
    links = extract_links(description)
    for kind, value in links:
        all_links.append((identifier, issue.get("title"), kind, value, issue.get("status")))

    lines = []
    lines.append("---\n")
    lines.append("type: multica_issue_summary\n")
    lines.append(f"issue: {identifier}\n")
    lines.append(f"status: {issue.get('status')}\n")
    lines.append("generated: auto\n")
    lines.append("---\n\n")
    lines.append(f"# {identifier} {issue.get('title') or ''}\n\n")
    lines.append("## 一句话结论\n\n")
    lines.append((core[0][2:] if core and core[0].startswith("- ") else core[0] if core else issue.get("title") or identifier) + "\n\n")
    lines.append("## 核心结论\n\n")
    lines.extend(line + "\n" for line in core)
    lines.append("\n## 当前状态\n\n")
    lines.append(f"- Status: {issue.get('status')}\n")
    lines.append(f"- Priority: {issue.get('priority')}\n")
    lines.append(f"- Project: {project_name(issue)}\n")
    lines.append(f"- Assignee: {assignee_name(issue)}\n")
    lines.append(f"- Updated: {issue.get('updated_at')}\n")
    lines.append("\n## Evidence Links\n\n")
    if links:
        lines.append("| 类型 | 链接/路径 |\n")
        lines.append("|---|---|\n")
        for kind, value in links[:30]:
            lines.append(f"| {kind} | {esc(value)} |\n")
        if len(links) > 30:
            lines.append(f"| more | 另有 {len(links) - 30} 条链接，见 external-links 索引 |\n")
    else:
        lines.append("- 暂无可提取链接。\n")
    lines.append("\n## 待确认\n\n")
    if pending:
        lines.extend(line + "\n" for line in pending)
    else:
        lines.append("- 暂无。\n")
    lines.append("\n## 下一步\n\n")
    if next_steps:
        lines.extend(line + "\n" for line in next_steps)
    else:
        lines.append("- 查看 Multica 原始 issue 判断下一步。\n")
    lines.append("\n## 原始描述摘录\n\n")
    excerpt = description[:1200]
    lines.append(excerpt if excerpt else "暂无描述。")
    if len(description) > 1200:
        lines.append("\n\n_(摘录前 1200 字符，完整内容见 Multica issue)_\n")
    (cards_dir / f"{identifier}.md").write_text("".join(lines), encoding="utf-8")

index_lines = []
index_lines.append("---\n")
index_lines.append("type: readable_summary_index\n")
index_lines.append("source: multica issue list\n")
index_lines.append("generated: auto\n")
index_lines.append("---\n\n")
index_lines.append("# Multica Issue 可读摘要索引\n\n")
index_lines.append("由 `obsidian-sync.sh` 自动生成，可覆盖。\n\n")
index_lines.append(f"摘要卡数量：{len(visible)}\n\n")
index_lines.append("| Issue | 状态 | 优先级 | 项目 | 一句话结论 | 摘要卡 |\n")
index_lines.append("|---|---|---|---|---|---|\n")
for issue in visible:
    identifier = issue.get("identifier") or str(issue.get("number") or issue.get("id") or "unknown")
    description = issue.get("description") or ""
    core = bullets_from_section(section(description, "核心结论")) or fallback_summary(issue)
    one_liner = core[0][2:] if core and core[0].startswith("- ") else core[0] if core else issue.get("title") or identifier
    index_lines.append(
        f"| {identifier} | {issue.get('status')} | {issue.get('priority')} | {esc(project_name(issue))} | "
        f"{esc(one_liner[:90])} | [[issues/{identifier}.md|卡片]] |\n"
    )
index_path.write_text("".join(index_lines), encoding="utf-8")

link_lines = []
link_lines.append("---\n")
link_lines.append("type: external_links_index\n")
link_lines.append("source: multica issue descriptions\n")
link_lines.append("generated: auto\n")
link_lines.append("---\n\n")
link_lines.append("# 外部产物链接索引\n\n")
link_lines.append("由 `obsidian-sync.sh` 自动生成，可覆盖。\n\n")
link_lines.append(f"链接数量：{len(all_links)}\n\n")
link_lines.append("| Issue | 状态 | 类型 | 链接/路径 | 标题 |\n")
link_lines.append("|---|---|---|---|---|\n")
for identifier, title, kind, value, status in all_links:
    link_lines.append(f"| {identifier} | {status} | {kind} | {esc(value)} | {esc(title)[:80]} |\n")
links_path.write_text("".join(link_lines), encoding="utf-8")

print(f"生成 issue 可读摘要卡: {len(visible)}")
print(f"生成: {index_path}")
print(f"生成: {links_path}")
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


def gate_summary(path):
    if not path.exists() or path.stat().st_size == 0:
        return "MISSING"
    text = path.read_text(encoding="utf-8", errors="replace")
    result = "UNKNOWN"
    score = "UNKNOWN"
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("- Result:"):
            result = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("- Score:"):
            score = stripped.split(":", 1)[1].strip()
    return f"{result} {score}" if score != "UNKNOWN" else result



def policy_summary(path):
    if not path.exists() or path.stat().st_size == 0:
        return "MISSING"
    text = path.read_text(encoding="utf-8", errors="replace")
    result = "UNKNOWN"
    task_type = "UNKNOWN"
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("- Result:"):
            result = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("- Task type:"):
            task_type = stripped.split(":", 1)[1].strip()
    return f"{result} {task_type}" if task_type != "UNKNOWN" else result


def exception_summary(path):
    if not path.exists() or path.stat().st_size == 0:
        return "MISSING"
    text = path.read_text(encoding="utf-8", errors="replace")
    status = "UNKNOWN"
    approved_by = "UNKNOWN"
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("- Status:"):
            status = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("- Approved by:"):
            approved_by = stripped.split(":", 1)[1].strip()
    return f"{status} {approved_by}" if approved_by != "UNKNOWN" else status


def latest_time_contract(run_dir):
    paths = []
    primary = run_dir / "execution-time-contract.json"
    if primary.is_file():
        paths.append(primary)
    for path in sorted(run_dir.glob("execution-time-contract-*.json")):
        if path not in paths:
            paths.append(path)
    latest = None
    for path in paths:
        try:
            latest = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
    if latest is None:
        return {"within_one_minute": "n/a", "elapsed_minutes": "n/a", "absolute_error_minutes": "n/a", "next_estimate": "n/a"}
    return {
        "within_one_minute": latest.get("within_one_minute") if latest.get("within_one_minute") is not None else "n/a",
        "elapsed_minutes": latest.get("elapsed_minutes") if latest.get("elapsed_minutes") is not None else "n/a",
        "absolute_error_minutes": latest.get("absolute_error_minutes") if latest.get("absolute_error_minutes") is not None else "n/a",
        "next_estimate": latest.get("recommended_next_estimate_minutes") or latest.get("next_estimate_minutes") or "n/a",
    }

runs = []
for run_dir in runs_dir.iterdir():
    if not run_dir.is_dir():
        continue
    summary = run_dir / "summary.md"
    clarification = run_dir / "clarification.md"
    clarification_gate = run_dir / "clarification-gate.md"
    requirement_gate = run_dir / "requirement-gate.md"
    design_gate = run_dir / "design-gate.md"
    deliverable_gate = run_dir / "deliverable-gate.md"
    gate_policy = run_dir / "gate-policy-check.md"
    gate_exception = run_dir / "gate-policy-exception.md"
    run_json = run_dir / "run.json"
    state_json = run_dir / "state-evaluation.json"
    if not any(path.exists() for path in (run_json, state_json, summary)):
        continue
    metadata = {}
    state = {}
    if run_json.exists():
        try:
            metadata = json.loads(run_json.read_text(encoding="utf-8"))
        except Exception:
            metadata = {}
    if state_json.exists():
        try:
            state = json.loads(state_json.read_text(encoding="utf-8"))
        except Exception:
            state = {}
    updated = metadata.get("updated_at")
    if not updated:
        updated = __import__("datetime").datetime.fromtimestamp(run_dir.stat().st_mtime, tz=__import__("datetime").timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    time_contract = latest_time_contract(run_dir)
    runs.append(
        {
            "id": run_dir.name,
            "status": state.get("to") or metadata.get("status") or "unknown",
            "updated": updated,
            "has_summary": summary.exists(),
            "has_clarification": clarification.exists(),
            "has_clarification_gate": clarification_gate.exists(),
            "gate_scores": " / ".join([
                f"R:{gate_summary(requirement_gate)}",
                f"D:{gate_summary(design_gate)}",
                f"C:{gate_summary(clarification_gate)}",
                f"O:{gate_summary(deliverable_gate)}",
            ]),
            "gate_policy": policy_summary(gate_policy),
            "gate_exception": exception_summary(gate_exception),
            "within_one_minute": time_contract["within_one_minute"],
            "elapsed_minutes": time_contract["elapsed_minutes"],
            "absolute_error_minutes": time_contract["absolute_error_minutes"],
            "next_estimate": time_contract["next_estimate"],
        }
    )
lines = []
lines.append("---\n")
lines.append("type: loop_snapshot\n")
lines.append("source: loop runs/\n")
lines.append("generated: auto\n")
lines.append("---\n\n")
lines.append("# Loop Run 证据索引\n\n")
lines.append("由 `obsidian-sync.sh` 自动生成，可覆盖。\n\n")
lines.append(f"Run 总数：{len(runs)}\n\n")
lines.append("| Run ID | 状态 | Summary | Clarification | Clarification Gate | Gate Scores | Gate Policy | Gate Exception | within_one_minute | Elapsed | Absolute Error | Next Estimate | 更新时间 |\n")
lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|\n")
for run in sorted(runs, key=lambda item: item.get("updated") or "", reverse=True)[:100]:
    run_id = str(run["id"]).replace("|", "\\|")
    gate_scores = str(run.get("gate_scores") or "").replace("|", "\\|")
    gate_policy = str(run.get("gate_policy") or "").replace("|", "\\|")
    gate_exception = str(run.get("gate_exception") or "").replace("|", "\\|")
    lines.append(f"| {run_id} | {run.get('status')} | {'✓' if run.get('has_summary') else '✗'} | {'✓' if run.get('has_clarification') else '✗'} | {'✓' if run.get('has_clarification_gate') else '✗'} | {gate_scores} | {gate_policy} | {gate_exception} | {run.get('within_one_minute')} | {run.get('elapsed_minutes')} | {run.get('absolute_error_minutes')} | {run.get('next_estimate')} | {run.get('updated')} |\n")
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
  python3 - <<'PY' "$REPO_ROOT/docs/ai-work-orchestration" "$REPO_ROOT/config" "$TMP_DIR/ai-loop-docs" "$TMP_DIR/ai-loop-docs-index.md"
import sys
from pathlib import Path

docs_dir = Path(sys.argv[1])
config_dir = Path(sys.argv[2])
out_dir = Path(sys.argv[3])
out_dir.mkdir(parents=True, exist_ok=True)
copied = []
for source in sorted(docs_dir.glob("*.md")):
    if source.name != "logbook.md":
        destination = out_dir / source.name
        destination.write_text(source.read_text(encoding="utf-8"), encoding="utf-8")
        copied.append(source.name)
copied_reports = []
reports_out_dir = out_dir / "reports"
if (docs_dir / "reports").exists():
    reports_out_dir.mkdir(parents=True, exist_ok=True)
    for report in sorted((docs_dir / "reports").glob("*.md"), reverse=True)[:30]:
        (reports_out_dir / report.name).write_text(report.read_text(encoding="utf-8"), encoding="utf-8")
        copied_reports.append(report.name)
copied_share_docs = []
share_out_dir = out_dir / "share"
if (docs_dir / "share").exists():
    share_out_dir.mkdir(parents=True, exist_ok=True)
    for share_doc in sorted((docs_dir / "share").glob("*.md")):
        (share_out_dir / share_doc.name).write_text(share_doc.read_text(encoding="utf-8"), encoding="utf-8")
        copied_share_docs.append(share_doc.name)
copied_configs = []
config_out_dir = out_dir / "config"
if config_dir.exists():
    config_out_dir.mkdir(parents=True, exist_ok=True)
    for config_doc in sorted(config_dir.glob("*.json")):
        (config_out_dir / config_doc.name).write_text(config_doc.read_text(encoding="utf-8"), encoding="utf-8")
        copied_configs.append(config_doc.name)
capability_registry = config_dir / "sinan-capabilities.json"
if capability_registry.exists():
    import json
    def md_cell(value):
        text = str(value or "")
        return text.replace("|", "-").replace("<", "&lt;").replace(">", "&gt;")
    def md_list(values):
        return "<br>".join(md_cell(value) for value in (values or []))
    data = json.loads(capability_registry.read_text(encoding="utf-8"))
    cap_lines = []
    cap_lines.append("---\n")
    cap_lines.append("type: sinan_capability_registry\n")
    cap_lines.append("source: config/sinan-capabilities.json\n")
    cap_lines.append("generated: auto\n")
    cap_lines.append("---\n\n")
    cap_lines.append("# 司南能力目录\n\n")
    cap_lines.append("由 `obsidian-sync.sh` 从 `config/sinan-capabilities.json` 自动生成，可覆盖。\n\n")
    cap_lines.append(f"能力数量：{len(data.get('capabilities') or [])}\n\n")
    cap_lines.append("| 能力 | 状态 | 阶段 | 入口 | 外部工具 | 证据 | 验证 | 策略 |\n")
    cap_lines.append("|---|---|---|---|---|---|---|---|\n")
    for capability in data.get("capabilities") or []:
        entrypoints = md_list(capability.get("entrypoints") or [])
        external_tools = md_list(capability.get("external_tools") or [])
        evidence = md_list(capability.get("evidence_outputs") or [])
        verification = md_list(capability.get("verification") or [])
        policy = md_cell(capability.get("side_effect_policy") or "")
        cap_lines.append(f"| {md_cell(capability.get('name'))} (`{md_cell(capability.get('id'))}`) | {md_cell(capability.get('status'))} | {md_cell(capability.get('phase') or '')} | {entrypoints} | {external_tools} | {evidence} | {verification} | {policy} |\n")
    (out_dir / "sinan-capabilities.md").write_text("".join(cap_lines), encoding="utf-8")
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
for report_name in copied_reports:
    report_stem = report_name.removesuffix(".md")
    lines.append(f"- [[../loop/docs/reports/{report_name}|{report_stem}]]\n")
lines.append("\n## 分享材料\n\n")
for share_name in copied_share_docs:
    share_stem = share_name.removesuffix(".md")
    lines.append(f"- [[../loop/docs/share/{share_name}|{share_stem}]]\n")
lines.append("\n## 配置与能力注册表\n\n")
for config_name in copied_configs:
    config_stem = config_name.removesuffix(".json")
    lines.append(f"- [[../loop/docs/config/{config_name}|{config_stem}]]\n")
if (out_dir / "sinan-capabilities.md").exists():
    lines.append("- [[../loop/docs/sinan-capabilities.md|司南能力目录]]\n")
Path(sys.argv[4]).write_text("".join(lines), encoding="utf-8")
print(f"镜像沉淀: {len(copied)} 文档, {len(copied_reports)} 报告, {len(copied_share_docs)} 分享材料, {len(copied_configs)} 配置")
print(f"生成: {sys.argv[4]}")
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
import json
from pathlib import Path
import sys

runs_dir = Path(sys.argv[1])
out_dir = Path(sys.argv[2])
out_dir.mkdir(parents=True, exist_ok=True)


def gate_summary(path):
    if not path.exists() or path.stat().st_size == 0:
        return ("MISSING", "MISSING", "MISSING")
    text = path.read_text(encoding="utf-8", errors="replace")
    result = "UNKNOWN"
    score = "UNKNOWN"
    failures = "UNKNOWN"
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("- Result:"):
            result = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("- Score:"):
            score = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("- Required failures:"):
            failures = stripped.split(":", 1)[1].strip()
    return (result, score, failures)




def policy_summary(path):
    if not path.exists() or path.stat().st_size == 0:
        return ("MISSING", "MISSING")
    text = path.read_text(encoding="utf-8", errors="replace")
    result = "UNKNOWN"
    task_type = "UNKNOWN"
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("- Result:"):
            result = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("- Task type:"):
            task_type = stripped.split(":", 1)[1].strip()
    return (result, task_type)


def exception_summary(path):
    if not path.exists() or path.stat().st_size == 0:
        return ("MISSING", "MISSING", "MISSING")
    text = path.read_text(encoding="utf-8", errors="replace")
    status = "UNKNOWN"
    approved_by = "UNKNOWN"
    expires = "UNKNOWN"
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("- Status:"):
            status = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("- Approved by:"):
            approved_by = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("- Expires:"):
            expires = stripped.split(":", 1)[1].strip()
    return (status, approved_by, expires)


def omit_stage_remote_writes(text):
    lines = text.splitlines(keepends=True)
    output = []
    skipping = False
    omitted = False
    for line in lines:
        if line.startswith("## Remote Writes"):
            skipping = True
            omitted = True
            continue
        if skipping and line.startswith("## "):
            skipping = False
        if not skipping:
            output.append(line)
    if omitted:
        output.append("\n## Remote Writes\n\n")
        output.append("_See the latest Writeback Summary section above for authoritative remote write results._\n")
    return "".join(output)


count = 0
for run_dir in sorted(runs_dir.iterdir(), key=lambda item: item.name, reverse=True):
    if not run_dir.is_dir():
        continue
    summary = run_dir / "summary.md"
    stage = run_dir / "stage-report.md"
    verify = run_dir / "verification-report.md"
    execution_preflight = run_dir / "execution-preflight.md"
    closeout_summary = run_dir / "closeout" / "closeout-summary.md"
    continuation_gate = run_dir / "continuation-gate.md"
    execution_time_contract = run_dir / "execution-time-contract.md"
    time_calibration = run_dir / "time-estimation-calibration.md"
    clarification = run_dir / "clarification.md"
    clarification_gate = run_dir / "clarification-gate.md"
    writeback = run_dir / "writeback-summary.md"
    share_preflight = run_dir / "share-preflight-summary.md"
    gate_policy = run_dir / "gate-policy-check.md"
    gate_exception = run_dir / "gate-policy-exception.md"
    gate_paths = {
        "Requirement": run_dir / "requirement-gate.md",
        "Design": run_dir / "design-gate.md",
        "Clarification": clarification_gate,
        "Deliverable": run_dir / "deliverable-gate.md",
    }
    if not summary.exists():
        continue
    if count >= 50:
        break
    lines = []
    lines.append("---\n")
    lines.append("type: loop_run\n")
    lines.append(f"run_id: {run_dir.name}\n")
    lines.append(f"source: runs/{run_dir.name}\n")
    lines.append("generated: auto\n")
    lines.append("---\n\n")
    lines.append(f"# Loop Run: {run_dir.name}\n\n")
    lines.append("## Gate Results\n\n")
    lines.append("| Gate | Result | Score | Required Failures |\n")
    lines.append("|---|---|---|---|\n")
    for gate_name, gate_path in gate_paths.items():
        result, score, failures = gate_summary(gate_path)
        lines.append(f"| {gate_name} | {result} | {score} | {failures} |\n")
    policy_result, policy_task_type = policy_summary(gate_policy)
    exception_status, exception_approved_by, exception_expires = exception_summary(gate_exception)
    lines.append("\n")
    lines.append("## Gate Policy\n\n")
    lines.append("| Item | Value |\n")
    lines.append("|---|---|\n")
    lines.append(f"| Policy result | {policy_result} |\n")
    lines.append(f"| Task type | {policy_task_type} |\n")
    lines.append(f"| Exception status | {exception_status} |\n")
    lines.append(f"| Exception approved by | {exception_approved_by} |\n")
    lines.append(f"| Exception expires | {exception_expires} |\n")
    lines.append("\n")
    lines.append("## Summary\n\n")
    lines.append(summary.read_text(encoding="utf-8"))
    if execution_preflight.exists():
        execution_preflight_text = execution_preflight.read_text(encoding="utf-8")
        lines.append("\n\n## Execution Preflight\n\n")
        lines.append(execution_preflight_text[:2000])
        if len(execution_preflight_text) > 2000:
            lines.append("\n\n_(摘录前 2000 字符，完整内容见 runs/ 目录)_\n")
    if closeout_summary.exists():
        closeout_summary_text = closeout_summary.read_text(encoding="utf-8")
        lines.append("\n\n## Closeout Summary\n\n")
        lines.append(closeout_summary_text[:2000])
        if len(closeout_summary_text) > 2000:
            lines.append("\n\n_(摘录前 2000 字符，完整内容见 runs/ 目录)_\n")
    if continuation_gate.exists():
        continuation_gate_text = continuation_gate.read_text(encoding="utf-8")
        lines.append("\n\n## Continuation Gate\n\n")
        lines.append(continuation_gate_text[:2000])
        if len(continuation_gate_text) > 2000:
            lines.append("\n\n_(摘录前 2000 字符，完整内容见 runs/ 目录)_\n")
    if execution_time_contract.exists():
        execution_time_contract_text = execution_time_contract.read_text(encoding="utf-8")
        lines.append("\n\n## Execution Time Contract\n\n")
        lines.append(execution_time_contract_text[:2000])
        if len(execution_time_contract_text) > 2000:
            lines.append("\n\n_(摘录前 2000 字符，完整内容见 runs/ 目录)_\n")
    if time_calibration.exists():
        time_calibration_text = time_calibration.read_text(encoding="utf-8")
        lines.append("\n\n## Time Estimation Calibration\n\n")
        lines.append(time_calibration_text[:2000])
        if len(time_calibration_text) > 2000:
            lines.append("\n\n_(摘录前 2000 字符，完整内容见 runs/ 目录)_\n")
    if clarification.exists():
        clarification_text = clarification.read_text(encoding="utf-8")
        lines.append("\n\n## Clarification Draft\n\n")
        lines.append(clarification_text[:3000])
        if len(clarification_text) > 3000:
            lines.append("\n\n_(摘录前 3000 字符，完整内容见 runs/ 目录)_\n")
    if clarification_gate.exists():
        clarification_gate_text = clarification_gate.read_text(encoding="utf-8")
        lines.append("\n\n## Clarification Gate\n\n")
        lines.append(clarification_gate_text[:2000])
        if len(clarification_gate_text) > 2000:
            lines.append("\n\n_(摘录前 2000 字符，完整内容见 runs/ 目录)_\n")
    if writeback.exists():
        writeback_text = writeback.read_text(encoding="utf-8")
        lines.append("\n\n## Writeback Summary\n\n")
        lines.append(writeback_text[:2000])
        if len(writeback_text) > 2000:
            lines.append("\n\n_(摘录前 2000 字符，完整内容见 runs/ 目录)_\n")
    if share_preflight.exists():
        share_preflight_text = share_preflight.read_text(encoding="utf-8")
        lines.append("\n\n## Share Preflight Summary\n\n")
        lines.append(share_preflight_text[:2000])
        if len(share_preflight_text) > 2000:
            lines.append("\n\n_(摘录前 2000 字符，完整内容见 runs/ 目录)_\n")
    share_preflight_json = run_dir / "share-preflight-summary.json"
    if share_preflight_json.exists():
        try:
            share_data = json.loads(share_preflight_json.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            share_data = {}
        time_gates = (share_data.get("golden_path") or {}).get("time_contract_gates") or []
        if time_gates:
            lines.append("\n\n## Share Time Contract Gate Snapshot\n\n")
            lines.append("| Gate | Status | Detail |\n")
            lines.append("|---|---|---|\n")
            for item in time_gates:
                name = str(item.get("name") or "")
                status = str(item.get("status") or "")
                detail = str(item.get("detail") or "").replace("|", "\\|")
                lines.append(f"| {name} | {status} | {detail} |\n")
    if stage.exists():
        stage_text = omit_stage_remote_writes(stage.read_text(encoding="utf-8"))
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
  cp "$TMP_DIR/readable-summaries.md" "$GENERATED/multica/readable-summaries.md"
  rsync -a "$TMP_DIR/issue-cards/" "$GENERATED/multica/issues/"
  cp "$TMP_DIR/external-links.md" "$GENERATED/governance/external-links.md"
  cp "$TMP_DIR/runtime-status.md" "$GENERATED/agents/runtime-status.md"
  cp "$TMP_DIR/autopilots.md" "$GENERATED/autopilots/autopilots.md"
  cp "$TMP_DIR/paused-autopilots.md" "$GENERATED/autopilots/paused-autopilots.md"
  cp "$TMP_DIR/runs-index.md" "$GENERATED/loop/runs-index.md"
  echo "生成 Multica 可读摘要卡到: $GENERATED/multica/issues/"
  echo "生成外部产物链接索引到: $GENERATED/governance/external-links.md"
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

if [[ "$WRITE_OPERATION_LOG" == "true" ]]; then
  mkdir -p "$OPERATION_LOG_DIR"
  operation_log="$OPERATION_LOG_DIR/obsidian-sync-$(date '+%Y%m%d-%H%M%S').md"
  latest_operation_log="$OPERATION_LOG_DIR/obsidian-sync.latest.md"
  python3 - <<'PY' "$operation_log" "$latest_operation_log" "$SYNC_STARTED_AT" "$(date '+%F %T %z')" "$VAULT_PATH" "$REPO_ROOT" "$JAVA_ROOT" "$GENERATED" "$DRY_RUN" "$ARCHIVED_ISSUE_RETENTION_DAYS"
import shutil
import sys
from pathlib import Path

(
    operation_log,
    latest_operation_log,
    started_at,
    finished_at,
    vault_path,
    repo_root,
    java_root,
    generated,
    dry_run,
    archived_retention_days,
) = sys.argv[1:]

text = f"""# Operation Log — Obsidian Sync

## Scope

- Started at: {started_at}
- Finished at: {finished_at}
- Vault: {vault_path}
- Repo: {repo_root}
- Java root: {java_root}
- Generated root: {generated}
- Dry run: {dry_run}
- Archived issue retention days: {archived_retention_days}

## Side Effects

- Obsidian generated filesystem write: {"yes" if dry_run == "false" else "no"}
- Multica/Feishu/Git remote/deploy writes: no

## Recursive Sync Guard

- This operation log is written under state/operations.
- state/operations is local audit evidence and is intentionally not mirrored by obsidian-sync.
- Do not create a phase report only to record that an Obsidian sync happened; batch sync logs with the next substantive documentation update if needed.
"""

path = Path(operation_log)
path.write_text(text, encoding="utf-8")
shutil.copyfile(path, latest_operation_log)
print(f"operation_log: {operation_log}")
print(f"latest_operation_log: {latest_operation_log}")
PY
fi
