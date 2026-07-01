#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

run_id="test-context-artifacts-handoff"
run_dir="runs/$run_id"
rm -rf "$run_dir"
mkdir -p "$run_dir"

cat > "$run_dir/run.json" <<'JSON'
{
  "run_id": "test-context-artifacts-handoff",
  "context_artifact_paths": [
    "graph-context.md",
    "context-pack.md",
    "/absolute-ignored.md",
    "../parent-ignored.md"
  ]
}
JSON
printf '# Summary\n' > "$run_dir/summary.md"
printf '# Graph Context\n' > "$run_dir/graph-context.md"
printf '# Context Pack\n' > "$run_dir/context-pack.md"

output="$run_dir/handoff.md"
scripts/loop-handoff.sh \
  --issue test \
  --run-id "$run_id" \
  --from-role scheduler \
  --to-role execution_agent \
  --state handoff \
  --next-action "Use context artifacts." \
  --output "$output" >/dev/null

grep -q "runs/$run_id/graph-context.md" "$output"
grep -q "runs/$run_id/context-pack.md" "$output"
if grep -q "absolute-ignored\|parent-ignored" "$output"; then
  echo "unsafe context artifact path leaked into handoff" >&2
  exit 1
fi

echo "loop handoff context artifact test passed"
