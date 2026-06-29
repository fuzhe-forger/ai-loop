#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cmd="${1:-help}"
shift || true
case "$cmd" in
  help|-h|--help)
    cat <<'HELP'
Usage: scripts/sinan.sh <command> [args]

Commands:
  capability-check       Run capability registry check
  doctor                 Run local onboarding readiness checks
  fitness-check          Run fitness check, pass remaining args
  flow-advisor           Run flow advisor, pass remaining args
  memory-promote-draft   Promote a validated memory draft, pass remaining args
  memory-review-state    Change memory case review_state, pass remaining args
  next                   Suggest the next local-only Sinan slice
  onboarding-drill-check Validate local onboarding drill outputs
  token-audit            Run token efficiency audit, pass remaining args
  ops-dashboard          Generate ops dashboard, pass remaining args
  phase-d-closeout       Generate Phase D memory closeout, pass remaining args
  phase-d-closeout-check Validate Phase D memory closeout, pass remaining args
  v2-acceptance          Run v2 acceptance, pass remaining args
HELP
    ;;
  capability-check) "$ROOT_DIR/scripts/sinan-capability-check.sh" "$@" ;;
  doctor) "$ROOT_DIR/scripts/sinan-doctor.sh" "$@" ;;
  fitness-check) "$ROOT_DIR/scripts/sinan-fitness-check.sh" "$@" ;;
  flow-advisor) "$ROOT_DIR/scripts/sinan-flow-advisor.sh" "$@" ;;
  memory-promote-draft) "$ROOT_DIR/scripts/memory-promote-draft.sh" "$@" ;;
  memory-review-state) "$ROOT_DIR/scripts/memory-review-state.sh" "$@" ;;
  next) "$ROOT_DIR/scripts/sinan-next.sh" "$@" ;;
  onboarding-drill-check) "$ROOT_DIR/scripts/onboarding-drill-check.sh" "$@" ;;
  token-audit) "$ROOT_DIR/scripts/token-efficiency-audit.sh" "$@" ;;
  ops-dashboard) "$ROOT_DIR/scripts/sinan-ops-dashboard.sh" "$@" ;;
  phase-d-closeout) "$ROOT_DIR/scripts/phase-d-closeout.sh" "$@" ;;
  phase-d-closeout-check) "$ROOT_DIR/scripts/phase-d-closeout-check.sh" "$@" ;;
  v2-acceptance) "$ROOT_DIR/scripts/sinan-v2-acceptance.sh" "$@" ;;
  *) echo "Unknown command: $cmd" >&2; exit 2 ;;
esac
