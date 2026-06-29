#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/smoke-multica-writeback.sh [--issue <issue>] [--run-id <run-id>]

Run a local-only Multica writeback smoke test with a fake multica binary.

Options:
  --issue   Issue identifier, default: FUZ-SMOKE
  --run-id  Run identifier, default: <issue>-smoke-writeback
  -h, --help Show this help

This script creates only local temp files and runs/. It never calls the real Multica CLI.
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
issue_id="FUZ-SMOKE"
run_id=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      issue_id="${2:-}"; shift 2 ;;
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -z "$run_id" ]]; then
  run_id="${issue_id}-smoke-writeback"
fi

cd "$ROOT_DIR"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

run_dir="runs/$run_id"
rm -rf "$run_dir"
mkdir -p "$run_dir" "$tmpdir/bin"

cat > "$run_dir/summary.md" <<EOF_SUMMARY
# Summary

- Run ID: \`$run_id\`
- Status: \`PASSED\`
EOF_SUMMARY

cat > "$run_dir/stage-report.md" <<EOF_STAGE
# Stage Report

## Remote Writes

- Write comment requested: false
- Write status requested: false
- Write metadata requested: false
EOF_STAGE

cat > "$run_dir/multica-comment.md" <<EOF_COMMENT
# Multica Comment Draft

Local smoke test draft.
EOF_COMMENT

cat > "$run_dir/verification-report.md" <<'EOF_VERIFY'
# Toolchain Verification: FUZ-SMOKE

## Strict Evidence Gate

| Run | Result | Missing Core Evidence |
|---|---|---|
| smoke | PASSED | |

## State Metadata Gate

| Run | Result | Missing State Evidence |
|---|---|---|
| smoke | PASSED | |
EOF_VERIFY

cat > "$run_dir/state-evaluation.json" <<EOF_STATE
{
  "schema_version": 1,
  "issue": "$issue_id",
  "run_id": "$run_id",
  "to": "done",
  "required_next_actor": "human",
  "reason": "local smoke passed",
  "checks": {
    "remote_write_completed": "NO"
  }
}
EOF_STATE

cat > "$run_dir/metadata-draft.json" <<EOF_METADATA
{
  "schema_version": 1,
  "issue": "$issue_id",
  "run_id": "$run_id",
  "metadata": {
    "pipeline_status": "done",
    "latest_run_id": "$run_id",
    "strict_gate": "PASSED",
    "next_actor": "human",
    "assigned_actor": "黑墙",
    "blocked_reason": ""
  }
}
EOF_METADATA

cat > "$run_dir/writeback-summary.md" <<EOF_WRITEBACK
# Multica Loop Writeback Summary

## Scope

- Issue: $issue_id
- Run ID: $run_id

## Remote Write Requests

- Write comment requested: false
- Write status requested: false
- Write metadata requested: false

## Remote Write Results

- Comment written: false
- Status written: false
- Status write value:
- Metadata written: false
- Metadata write value: not-implemented
EOF_WRITEBACK

cat > "$tmpdir/bin/multica" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

log_file="${MULTICA_FAKE_LOG:?MULTICA_FAKE_LOG is required}"
printf '%s\n' "$*" >> "$log_file"

case "$*" in
  issue\ metadata\ list*)
    printf '{"metadata":[]}\n'
    ;;
  issue\ metadata\ set*)
    printf '{"ok":true,"operation":"set"}\n'
    ;;
  issue\ metadata\ get*)
    printf '{"key":"pipeline_status","value":"done"}\n'
    ;;
  *)
    printf 'unexpected fake multica call: %s\n' "$*" >&2
    exit 9
    ;;
esac
SH
chmod +x "$tmpdir/bin/multica"

fake_log="$tmpdir/multica.log"
: > "$fake_log"

PATH="$tmpdir/bin:$PATH" MULTICA_FAKE_LOG="$fake_log" ./scripts/metadata-writeback.sh \
  --issue "$issue_id" \
  --run-id "$run_id" \
  --approved-by smoke-user \
  --write >/dev/null

test -s "$run_dir/approval-boundary-metadata.md"
test -s "$run_dir/approval-boundary-metadata.json"
test -s "$run_dir/writeback-gate-metadata.json"
test -s "$run_dir/metadata-writeback.json"
test -s "$run_dir/multica-metadata-write-result.json"
test -s "$run_dir/multica-metadata-get-pipeline_status.json"
test -s "$run_dir/multica-metadata-before.json"
test -s "$run_dir/multica-metadata-after.json"

python3 - <<'PY' "$run_dir/approval-boundary-metadata.json" "$run_dir/metadata-writeback.json" "$run_dir/writeback-summary.md" "$fake_log"
import json
import sys
from pathlib import Path

approval_path, report_path, summary_path, fake_log_path = map(Path, sys.argv[1:])
approval = json.loads(approval_path.read_text(encoding="utf-8"))
report = json.loads(report_path.read_text(encoding="utf-8"))
summary = summary_path.read_text(encoding="utf-8")
fake_log = fake_log_path.read_text(encoding="utf-8")

assert approval["action"] == "multica-metadata"
assert approval["result"] == "PASSED"
assert approval["decision"] == "approved_to_proceed"
assert report["write_requested"] is True
assert report["written"] == "true"
assert report["gate"]["status"] == "PASSED"
assert report["approval_boundary"]["status"] == "PASSED"
assert report["approval"]["approved_by"] == "smoke-user"
assert summary.count("- Write metadata requested:") == 1
assert "- Write metadata requested: true" in summary
assert "- Metadata written: true" in summary
assert "- Approval boundary metadata:" in summary
assert "issue metadata list" in fake_log
assert "issue metadata set" in fake_log
assert "issue metadata get" in fake_log
PY

echo "smoke_multica_writeback: PASSED"
echo "run_id: $run_id"
