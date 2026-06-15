#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/patch-summary.sh [--base <git-ref>] [--allow-prefix <path>]... [--output <file>]

Generate a local Markdown summary for the current git diff.

Options:
  --base    Git ref to compare against, default: HEAD
  --allow-prefix
            Allowed changed-file path prefix. Can be passed multiple times.
  --output  Optional file path to write the summary
  -h, --help Show this help

This script is local-only. It reads git diff metadata and never performs remote writes.
HELP
}

base="HEAD"
output=""
allow_prefixes=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      base="${2:-}"; shift 2 ;;
    --allow-prefix)
      allow_prefixes+=("${2:-}"); shift 2 ;;
    --output)
      output="${2:-}"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if ! git rev-parse --verify "$base" >/dev/null 2>&1; then
  echo "Invalid git ref: $base" >&2
  exit 1
fi

name_status="$(git diff --name-status "$base" --)"
stat="$(git diff --stat "$base" --)"
untracked="$(git ls-files --others --exclude-standard)"
tracked_count="$(printf '%s\n' "$name_status" | sed '/^$/d' | wc -l | tr -d ' ')"
untracked_count="$(printf '%s\n' "$untracked" | sed '/^$/d' | wc -l | tr -d ' ')"
changed_count=$((tracked_count + untracked_count))

if [[ "$changed_count" == "0" ]]; then
  echo "No diff found against $base" >&2
  exit 1
fi

changed_files="$(
  {
    printf '%s\n' "$name_status" | awk 'NF >= 2 {print $NF}'
    printf '%s\n' "$untracked"
  } | sed '/^$/d'
)"

scope_status="NOT_CHECKED"
out_of_scope=""
if [[ ${#allow_prefixes[@]} -gt 0 ]]; then
  scope_status="PASSED"
  while IFS= read -r changed_file; do
    [[ -z "$changed_file" ]] && continue
    in_scope="false"
    for prefix in "${allow_prefixes[@]}"; do
      if [[ "$changed_file" == "$prefix"* ]]; then
        in_scope="true"
        break
      fi
    done
    if [[ "$in_scope" == "false" ]]; then
      scope_status="FAILED"
      out_of_scope+="${changed_file}"$'\n'
    fi
  done <<< "$changed_files"
fi

allow_prefix_list=""
if [[ ${#allow_prefixes[@]} -gt 0 ]]; then
  allow_prefix_list="$(printf '%s\n' "${allow_prefixes[@]}")"
fi

summary="# Patch Summary

## Scope

- Base: ${base}
- Changed files: ${changed_count}
- Tracked changed files: ${tracked_count}
- Untracked files: ${untracked_count}
- Remote writes: false

## Tracked Changed Files

\`\`\`text
${name_status}
\`\`\`

## Untracked Files

\`\`\`text
${untracked}
\`\`\`

## Diff Stat

\`\`\`text
${stat}
\`\`\`

## Scope Check

- Status: ${scope_status}
- Allow prefixes:

\`\`\`text
${allow_prefix_list}
\`\`\`

- Out of scope files:

\`\`\`text
${out_of_scope}
\`\`\`

## Review Questions

- Are all changed files in the approved scope?
- Are untracked files intentional evidence or source files?
- Are generated evidence files separated from functional script changes?
- Is there a verification command for the functional change?
- Are git commit, push, MR, deployment, and production access still pending human approval?
"

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s' "$summary" > "$output"
  echo "patch_summary: $output"
else
  printf '%s' "$summary"
fi
