#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/route-actor.sh (--next-actor <actor> | --metadata <file>) [--output <file>] [--markdown <file>]

Map an abstract Multica Loop next_actor to a concrete Agent Crew role.

Options:
  --next-actor  Abstract actor, for example reviewer or execution_agent
  --metadata    Optional metadata-draft.json path to read next_actor from
  --output      Optional JSON output path
  --markdown    Optional Markdown output path
  -h, --help    Show this help

This script is local-only. It does not read or write Multica.
HELP
}

next_actor=""
metadata=""
output=""
markdown=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --next-actor)
      next_actor="${2:-}"; shift 2 ;;
    --metadata)
      metadata="${2:-}"; shift 2 ;;
    --output)
      output="${2:-}"; shift 2 ;;
    --markdown)
      markdown="${2:-}"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -n "$metadata" ]]; then
  if [[ ! -s "$metadata" ]]; then
    echo "Metadata file is missing or empty: $metadata" >&2
    exit 1
  fi
  next_actor="$(python3 - <<'PY' "$metadata"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("metadata", {}).get("next_actor") or "unknown")
PY
)"
fi

if [[ -z "$next_actor" ]]; then
  echo "--next-actor or --metadata is required" >&2
  show_help
  exit 2
fi

json_content="$(python3 - <<'PY' "$next_actor" "${metadata:-}"
import json
import sys

next_actor, metadata = sys.argv[1:]

routes = {
    "execution_agent": {
        "assigned_actor": "顾实",
        "role": "工程执行",
        "reason": "需要补执行、补 artifact、补验证",
    },
    "reviewer": {
        "assigned_actor": "裴衡",
        "role": "复核审查",
        "reason": "evidence 已够，进入复核",
    },
    "human": {
        "assigned_actor": "人类",
        "role": "目标/边界/授权/最终决策",
        "reason": "需要授权、验收或最终判断",
    },
    "scheduler": {
        "assigned_actor": "黑墙",
        "role": "调度/总控",
        "reason": "需要重新路由或升级",
    },
    "tester": {
        "assigned_actor": "测真",
        "role": "验证测试",
        "reason": "需要验证、复现或测试判断",
    },
    "scribe": {
        "assigned_actor": "简辞",
        "role": "表达沉淀",
        "reason": "需要沉淀、分享或表达整理",
    },
}

route = routes.get(next_actor, {
    "assigned_actor": "黑墙",
    "role": "调度/总控",
    "reason": "未知 next_actor，交由调度角色判断",
})

data = {
    "schema_version": 1,
    "next_actor": next_actor,
    "assigned_actor": route["assigned_actor"],
    "role": route["role"],
    "reason": route["reason"],
    "source_metadata": metadata,
    "remote_write": False,
}

print(json.dumps(data, ensure_ascii=False, indent=2))
PY
)"

markdown_content="$(python3 - <<'PY' "$json_content"
import json
import sys

data = json.loads(sys.argv[1])
print(f"""# Actor Route

## Route

- Next actor: {data['next_actor']}
- Assigned actor: {data['assigned_actor']}
- Role: {data['role']}
- Reason: {data['reason']}
- Source metadata: {data['source_metadata'] or 'none'}
- Remote write: {str(data['remote_write']).lower()}
""")
PY
)"

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s\n' "$json_content" > "$output"
  echo "route_json: $output"
else
  printf '%s\n' "$json_content"
fi

if [[ -n "$markdown" ]]; then
  mkdir -p "$(dirname "$markdown")"
  printf '%s' "$markdown_content" > "$markdown"
  echo "route_markdown: $markdown"
fi
