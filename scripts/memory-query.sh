#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/memory-query.sh [options]

Query project memory (architecture constraints, decisions, pitfalls, preferences, cases).

Options:
  --type <type>       Memory type: constraint | decision | pitfall | preference | case
  --tag <tag>         Filter by tag
  --id <id>           Query by ID
  --search <keyword>  Full-text search (grep in memory/ files)
  --list              List all memory entries
  -h, --help          Show this help
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEMORY_DIR="$ROOT_DIR/memory"
INDEX_FILE="$MEMORY_DIR/index.json"

query_type=""
query_tag=""
query_id=""
search_keyword=""
list_all="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)
      query_type="${2:-}"; shift 2 ;;
    --tag)
      query_tag="${2:-}"; shift 2 ;;
    --id)
      query_id="${2:-}"; shift 2 ;;
    --search)
      search_keyword="${2:-}"; shift 2 ;;
    --list)
      list_all="true"; shift ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ ! -f "$INDEX_FILE" ]]; then
  echo "Memory index not found: $INDEX_FILE" >&2
  exit 1
fi

if [[ "$list_all" == "true" ]]; then
  echo "# Project Memory Index"
  echo ""
  python3 - <<'PY' "$INDEX_FILE"
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
print(f"Project: {data['project']}")
print(f"Updated: {data['updated_at']}")
print(f"")
print(f"Constraints: {len(data['constraints'])}")
print(f"Decisions: {len(data['decisions'])}")
print(f"Pitfalls: {len(data['pitfalls'])}")
print(f"Preferences: {len(data['preferences'])}")
print(f"Cases: {len(data['cases'])}")
PY
  exit 0
fi

if [[ -n "$search_keyword" ]]; then
  echo "# Full-text search: $search_keyword"
  echo ""
  rg -n -C 2 "$search_keyword" "$MEMORY_DIR" --type md || echo "No results found"
  exit 0
fi

if [[ -n "$query_id" ]]; then
  echo "# Query by ID: $query_id"
  echo ""
  python3 - <<'PY' "$INDEX_FILE" "$query_id"
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
query_id = sys.argv[2]
found = False
for c in data['constraints']:
    if c['id'] == query_id:
        print(f"Type: constraint")
        print(f"ID: {c['id']}")
        print(f"Title: {c['title']}")
        print(f"File: {c['file']}")
        print(f"Tags: {', '.join(c['tags'])}")
        found = True
        break
for d in data['decisions']:
    if d['id'] == query_id:
        print(f"Type: decision")
        print(f"ID: {d['id']}")
        print(f"Title: {d['title']}")
        print(f"Status: {d['status']}")
        print(f"File: {d['file']}")
        print(f"Tags: {', '.join(d['tags'])}")
        found = True
        break
for p in data['pitfalls']:
    if p['id'] == query_id:
        print(f"Type: pitfall")
        print(f"ID: {p['id']}")
        print(f"Title: {p['title']}")
        print(f"Severity: {p['severity']}")
        print(f"File: {p['file']}")
        print(f"Tags: {', '.join(p['tags'])}")
        found = True
        break
for case in data['cases']:
    if case['id'] == query_id:
        print(f"Type: case")
        print(f"ID: {case['id']}")
        print(f"Issue: {case['issue']}")
        print(f"Title: {case['title']}")
        print(f"File: {case['file']}")
        print(f"Status: {case['status']}")
        print(f"Runs: {case['runs']}")
        print(f"Tags: {', '.join(case['tags'])}")
        found = True
        break
if not found:
    print(f"ID {query_id} not found")
    sys.exit(1)
PY
  exit 0
fi

if [[ -n "$query_type" ]]; then
  echo "# Query by type: $query_type"
  if [[ -n "$query_tag" ]]; then
    echo "# Filter by tag: $query_tag"
  fi
  echo ""
  python3 - <<'PY' "$INDEX_FILE" "$query_type" "$query_tag"
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
query_type = sys.argv[2]
query_tag = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] else None

results = []
if query_type == 'constraint':
    results = data['constraints']
elif query_type == 'decision':
    results = data['decisions']
elif query_type == 'pitfall':
    results = data['pitfalls']
elif query_type == 'preference':
    results = data['preferences']
elif query_type == 'case':
    results = data['cases']
else:
    print(f"Unknown type: {query_type}")
    sys.exit(1)

if query_tag:
    results = [r for r in results if query_tag in r.get('tags', [])]

if not results:
    print("No results found")
    sys.exit(0)

for r in results:
    if query_type == 'constraint':
        print(f"ID: {r['id']}")
        print(f"Type: {r['type']}")
        print(f"Title: {r['title']}")
        print(f"File: {r['file']}")
        print(f"Tags: {', '.join(r['tags'])}")
        print("")
    elif query_type == 'decision':
        print(f"ID: {r['id']}")
        print(f"Title: {r['title']}")
        print(f"Status: {r['status']}")
        print(f"File: {r['file']}")
        print(f"Date: {r['date']}")
        print(f"Tags: {', '.join(r['tags'])}")
        print("")
    elif query_type == 'pitfall':
        print(f"ID: {r['id']}")
        print(f"Title: {r['title']}")
        print(f"Severity: {r['severity']}")
        print(f"File: {r['file']}")
        print(f"Tags: {', '.join(r['tags'])}")
        print("")
    elif query_type == 'preference':
        print(f"Category: {r['category']}")
        print(f"File: {r['file']}")
        print(f"Tags: {', '.join(r['tags'])}")
        print("")
    elif query_type == 'case':
        print(f"ID: {r['id']}")
        print(f"Issue: {r['issue']}")
        print(f"Title: {r['title']}")
        print(f"Type: {r['type']}")
        print(f"File: {r['file']}")
        print(f"Status: {r['status']}")
        print(f"Runs: {r['runs']}")
        print(f"Tags: {', '.join(r['tags'])}")
        print("")
PY
  exit 0
fi

echo "Please specify --type, --id, --search, or --list" >&2
show_help
exit 2
