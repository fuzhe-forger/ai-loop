"""Local discovery command for AI Loop."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .artifacts import now_iso, write_text
from .config import ConfigError, load_config
from .memory import read_index
from .shell import run_command
from .workspace import loop_artifact_prefixes


class DiscoverError(Exception):
    """Raised when discovery cannot run."""


@dataclass(frozen=True)
class DiscoverRequest:
    repo: Path
    output: Path | None = None
    limit: int = 20


def discover(request: DiscoverRequest) -> Path:
    repo = request.repo.resolve()
    if request.limit < 1:
        raise DiscoverError("limit must be greater than 0")
    if not repo.exists():
        raise DiscoverError(f"repo does not exist: {repo}")
    if not (repo / ".git").exists():
        raise DiscoverError(f"repo is not a git repository: {repo}")
    try:
        config = load_config(repo)
    except ConfigError as exc:
        raise DiscoverError(str(exc)) from exc

    artifacts_root = repo / config.get("artifacts", {}).get("root", "runs")
    output_path = resolve_output_path(repo, artifacts_root, request.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    status = git_status(repo, loop_artifact_prefixes(repo, artifacts_root))
    records = read_index(artifacts_root / "index.jsonl")
    recent = list(reversed(records[-request.limit :]))
    failed = [item for item in recent if item.get("status") != "PASSED"]

    content = build_discovery_report(repo, status, recent, failed)
    write_text(output_path, content)
    return output_path


def resolve_output_path(repo: Path, artifacts_root: Path, output: Path | None) -> Path:
    if output is None:
        return artifacts_root / "discover.md"
    if output.is_absolute():
        return output
    return repo / output


def git_status(repo: Path, ignored_prefixes: tuple[str, ...] = ()) -> list[str]:
    result = run_command(["git", "status", "--short"], cwd=repo, check=False)
    return [line for line in result.stdout.splitlines() if line.strip() and not is_ignored_status_line(line, ignored_prefixes)]


def is_ignored_status_line(line: str, ignored_prefixes: tuple[str, ...]) -> bool:
    path = line[3:] if len(line) > 3 else line
    return any(path == prefix.rstrip("/") or path.startswith(prefix.rstrip("/") + "/") for prefix in ignored_prefixes)


def build_discovery_report(
    repo: Path,
    status_lines: list[str],
    recent: list[dict[str, Any]],
    failed: list[dict[str, Any]],
) -> str:
    lines = [
        "# AI Loop Discovery",
        "",
        f"Repo: `{repo}`",
        f"Generated: {now_iso()}",
        "",
        "## Findings",
        "",
    ]
    findings = discovery_findings(status_lines, failed)
    lines.extend(findings or ["- No local findings."])

    lines.extend(["", "## Git Working Tree", ""])
    if status_lines:
        lines.extend(f"- `{line}`" for line in status_lines)
    else:
        lines.append("- Clean working tree.")

    lines.extend(["", "## Recent Non-Passing Runs", ""])
    if failed:
        lines.extend(format_run_lines(failed))
    else:
        lines.append("- No recent non-passing runs recorded.")

    lines.extend(["", "## Recent Runs", ""])
    if recent:
        lines.extend(format_run_lines(recent))
    else:
        lines.append("- No runs recorded yet.")

    return "\n".join(lines) + "\n"


def discovery_findings(status_lines: list[str], failed: list[dict[str, Any]]) -> list[str]:
    findings: list[str] = []
    if status_lines:
        findings.append("- Working tree has local changes; review before starting a real Loop run.")
    if failed:
        findings.append("- Recent Loop runs include failures; inspect summaries before retrying.")
    return findings


def format_run_lines(records: list[dict[str, Any]]) -> list[str]:
    lines: list[str] = []
    for item in records:
        error = f", error={item.get('error_code')}" if item.get("error_code") else ""
        lines.append(
            f"- `{item.get('run_id')}` [{item.get('mode')}] {item.get('status')}{error} "
            f"summary=`runs/{item.get('summary_path')}`"
        )
    return lines
