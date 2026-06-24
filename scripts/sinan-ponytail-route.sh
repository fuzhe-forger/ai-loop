#!/usr/bin/env bash
set -euo pipefail
show_help() {
  cat <<'HELP'
Usage: scripts/sinan-ponytail-route.sh --run-id <run-id> --task <text> [options]

Create a Ponytail-CN coding handoff for a scoped Sinan/Loop implementation slice.

Options:
  --run-id <run-id>       Target run directory under runs/
  --task <text>           One-sentence scoped coding task
  --acceptance <text>     Acceptance criteria summary
  --files <text>          Likely touched files or modules
  --output <file>         Output handoff path, default runs/<run-id>/ponytail-cn-coding-handoff.md
  -h, --help              Show help
HELP
}
run_id=""
task=""
acceptance=""
files=""
output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id) run_id="${2:-}"; shift 2 ;;
    --task) task="${2:-}"; shift 2 ;;
    --acceptance) acceptance="${2:-}"; shift 2 ;;
    --files) files="${2:-}"; shift 2 ;;
    --output) output="${2:-}"; shift 2 ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; show_help; exit 2 ;;
  esac
done
if [[ -z "$run_id" || -z "$task" ]]; then
  echo "--run-id and --task are required" >&2
  show_help
  exit 2
fi
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
run_dir="runs/$run_id"
mkdir -p "$run_dir"
if [[ -z "$output" ]]; then
  output="$run_dir/ponytail-cn-coding-handoff.md"
fi
latest_summary="$run_dir/summary.md"
cat > "$output" <<HANDOFF
# Ponytail-CN Coding Handoff

## Scope

- Task: $task
- Acceptance: ${acceptance:-TBD by current Loop acceptance criteria}
- Non-goals: no broad refactor, no new dependency, no unrelated cleanup
- Side-effect boundary: local code/docs/tests only unless explicitly approved

## Starting Context

- Latest summary/handoff: ${latest_summary}
- Canonical evidence: ${latest_summary}
- Files not to reread: large logs/readbacks unless named by summary
- Assumptions to verify: inspect existing patterns before writing code

## Minimality Plan

- Existing helper/pattern to reuse: search first
- Standard library/platform feature: prefer before custom code
- New code needed: only the smallest acceptance-driven delta
- What not to build: new framework, generic abstraction, config layer, or dependency
- Dependencies not to add: any new dependency without explicit approval

## Implementation Slice

- Files likely touched: ${files:-TBD after targeted search}
- Narrow change: implement one smallest verifiable slice
- Stop condition: task expands beyond scope, safety/side-effect gate appears, or acceptance is unclear

## Validation

- Narrow validation command: choose closest existing test/check
- Broader validation command: run project standard verification when appropriate
- Evidence output path: ${run_dir}/

## Skill

Use local Codex skill: /home/user/.codex/skills/ponytail-cn/SKILL.md
HANDOFF
echo "ponytail-cn handoff: $output"
