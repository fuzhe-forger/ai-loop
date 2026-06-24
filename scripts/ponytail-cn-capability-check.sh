#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
missing=0
check_file() {
  local path="$1"
  if [[ -e "$path" ]]; then
    echo "✅ $path"
  else
    echo "❌ missing $path"
    missing=1
  fi
}
check_contains() {
  local path="$1"
  local pattern="$2"
  if grep -q "$pattern" "$path"; then
    echo "✅ $path contains $pattern"
  else
    echo "❌ $path missing $pattern"
    missing=1
  fi
}
check_file "/home/user/.codex/skills/ponytail-cn/SKILL.md"
check_file "/home/user/.codex/skills/ponytail-cn/references/minimal-coding-ladder.md"
check_file "skills/ponytail-cn/SKILL.md"
check_file "skills/ponytail-cn/references/minimal-coding-ladder.md"
check_file "references/ponytail-cn-coding.md"
check_file "memory/templates/ponytail-cn-coding-handoff-template.md"
check_file "scripts/sinan-ponytail-route.sh"
check_file "config/sinan-capabilities.json"
check_contains "config/sinan-capabilities.json" "ponytail_cn_coding"
check_contains "config/sinan-capabilities.json" "sinan-ponytail-route.sh"
check_contains "references/ponytail-cn-coding.md" "Execution Contract"
python3 /home/user/.codex/skills/.system/skill-creator/scripts/quick_validate.py /home/user/.codex/skills/ponytail-cn >/dev/null
python3 /home/user/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/ponytail-cn >/dev/null
python3 -m json.tool config/sinan-capabilities.json >/dev/null
if [[ "$missing" -ne 0 ]]; then
  echo "ponytail-cn capability check failed"
  exit 1
fi
echo "ponytail-cn capability check passed"
