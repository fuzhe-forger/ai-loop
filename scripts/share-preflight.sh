#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/share-preflight.sh [--case <case-id>] [--pattern <glob>] [--output-dir <dir>]

Run the local sharing preflight pipeline: refresh run evidence, verify gates, and build a review packet.

Options:
  --case        Case identifier, default: FUZ-554
  --pattern     Run glob pattern under runs/, default: '<case>*'
  --output-dir  Directory for generated reports, default: /tmp/ai-loop-share-preflight-<case>
  -h, --help    Show this help

This script is local-only. It writes reports to --output-dir and state artifacts under matching runs/ directories. It never writes Multica.
HELP
}

case_id="FUZ-554"
pattern=""
output_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case)
      case_id="${2:-}"; shift 2 ;;
    --pattern)
      pattern="${2:-}"; shift 2 ;;
    --output-dir)
      output_dir="${2:-}"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -z "$pattern" ]]; then
  pattern="${case_id}*"
fi

if [[ -z "$output_dir" ]]; then
  output_dir="/tmp/ai-loop-share-preflight-${case_id}"
fi

mkdir -p "$output_dir"

refresh_report="$output_dir/refresh-report.md"
verify_report="$output_dir/verification-report.md"
review_packet="$output_dir/review-packet.md"
summary_report="$output_dir/share-preflight-summary.md"

./scripts/refresh-run-evidence.sh \
  --pattern "$pattern" \
  --issue "$case_id" \
  --output "$refresh_report"

./scripts/verify-toolchain.sh \
  --case "$case_id" \
  --pattern "$pattern" \
  --strict \
  --state-gate \
  --output "$verify_report"

./scripts/review-packet.sh \
  --case "$case_id" \
  --pattern "$pattern" \
  --output "$review_packet"

generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

cat > "$summary_report" <<REPORT
# Sharing Preflight Summary: ${case_id}

## Metadata

- Generated at: ${generated_at}
- Case: ${case_id}
- Pattern: runs/${pattern}
- Output directory: ${output_dir}
- Network access: false
- Remote writes: false

## Reports

- Refresh report: ${refresh_report}
- Verification report: ${verify_report}
- Review packet: ${review_packet}

## Result

Sharing preflight completed locally.
REPORT

echo "refresh_report: $refresh_report"
echo "verification_report: $verify_report"
echo "review_packet: $review_packet"
echo "summary_report: $summary_report"
