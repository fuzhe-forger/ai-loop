"""Command-line interface for AI Loop."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .artifacts import read_json
from .config import ConfigError, load_config
from .discover import DiscoverError, DiscoverRequest, discover
from .init_project import InitError, init_repo
from .memory import read_index
from .planner import PlanError, PlanRequest, plan
from .runner import RunError, RunRequest, run


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ai-loop", description="Local-first AI engineering loop controller")
    subcommands = parser.add_subparsers(dest="command", required=True)

    init_parser = subcommands.add_parser("init", help="Initialize AI Loop config and bootstrap task")
    init_parser.add_argument("--repo", default=".", help="Repository path, defaults to current directory")
    init_parser.add_argument("--force", action="store_true", help="Overwrite generated files")

    run_parser = subcommands.add_parser("run", help="Run an AI Loop task")
    run_parser.add_argument("--repo", required=True, help="Repository path")
    run_parser.add_argument("--task", required=True, help="Task markdown file, relative to repo or absolute")
    run_parser.add_argument("--dry-run", action="store_true", help="Generate orchestration artifacts without Agent or verify")
    run_parser.add_argument("--run-id", help="Explicit run id")
    run_parser.add_argument("--base-ref", help="Base ref for future workspace creation")

    plan_parser = subcommands.add_parser("plan", help="Plan an ambiguous task without modifying files")
    plan_parser.add_argument("--repo", required=True, help="Repository path")
    plan_parser.add_argument("--task", required=True, help="Raw request markdown file, relative to repo or absolute")
    plan_parser.add_argument("--dry-run", action="store_true", help="Generate planning artifacts without Agent execution")
    plan_parser.add_argument("--run-id", help="Explicit run id")

    discover_parser = subcommands.add_parser("discover", help="Inspect local Loop state before starting work")
    discover_parser.add_argument("--repo", default=".", help="Repository path, defaults to current directory")
    discover_parser.add_argument("--output", help="Report path, relative to repo or absolute")
    discover_parser.add_argument("--limit", type=int, default=20, help="Maximum recent runs to include")

    status_parser = subcommands.add_parser("status", help="Show run status")
    status_parser.add_argument("run_id", nargs="?", help="Run id")
    status_parser.add_argument("--latest", action="store_true", help="Show the latest run from local memory")
    status_parser.add_argument("--repo", default=".", help="Repository path, defaults to current directory")

    return parser


def cmd_init(args: argparse.Namespace) -> int:
    repo = Path(args.repo).resolve()
    try:
        written = init_repo(repo, force=args.force)
    except InitError as exc:
        print(f"init failed: {exc}", file=sys.stderr)
        return 10

    if written:
        print("initialized AI Loop files:")
        for path in written:
            print(f"  {path}")
    else:
        print("AI Loop files already exist; use --force to overwrite")
    return 0


def cmd_run(args: argparse.Namespace) -> int:
    request = RunRequest(
        repo=Path(args.repo),
        task=Path(args.task),
        dry_run=args.dry_run,
        run_id=args.run_id,
        base_ref=args.base_ref,
    )
    try:
        run_dir = run(request)
    except RunError as exc:
        print(f"run failed: {exc}", file=sys.stderr)
        return 3

    data = read_json(run_dir / "run.json")
    print(f"run_id: {data['run_id']}")
    print(f"status: {data['status']}")
    print(f"summary: {run_dir / 'summary.md'}")
    return int(data.get("exit_code") or 0)


def cmd_discover(args: argparse.Namespace) -> int:
    request = DiscoverRequest(
        repo=Path(args.repo),
        output=Path(args.output) if args.output else None,
        limit=args.limit,
    )
    try:
        report_path = discover(request)
    except DiscoverError as exc:
        print(f"discover failed: {exc}", file=sys.stderr)
        return 3

    print(f"discover: {report_path}")
    return 0


def cmd_plan(args: argparse.Namespace) -> int:
    request = PlanRequest(
        repo=Path(args.repo),
        task=Path(args.task),
        dry_run=args.dry_run,
        run_id=args.run_id,
    )
    try:
        run_dir = plan(request)
    except PlanError as exc:
        print(f"plan failed: {exc}", file=sys.stderr)
        return 3

    data = read_json(run_dir / "run.json")
    print(f"run_id: {data['run_id']}")
    print(f"mode: {data.get('mode', 'plan')}")
    print(f"status: {data['status']}")
    if data.get("plan_path"):
        print(f"plan: {run_dir / data['plan_path']}")
    print(f"summary: {run_dir / 'summary.md'}")
    return int(data.get("exit_code") or 0)


def cmd_status(args: argparse.Namespace) -> int:
    repo = Path(args.repo).resolve()
    try:
        config = load_config(repo)
    except ConfigError as exc:
        print(f"status failed: {exc}", file=sys.stderr)
        return 3
    artifacts_root = repo / config.get("artifacts", {}).get("root", "runs")
    if args.latest and args.run_id:
        print("status failed: pass either run_id or --latest, not both", file=sys.stderr)
        return 2
    if args.latest:
        run_id = latest_run_id(artifacts_root)
        if not run_id:
            print(f"no runs found in local memory: {artifacts_root / 'index.jsonl'}", file=sys.stderr)
            return 2
    elif args.run_id:
        run_id = args.run_id
    else:
        print("status failed: run_id is required unless --latest is used", file=sys.stderr)
        return 2

    run_path = artifacts_root / run_id / "run.json"
    if not run_path.exists():
        print(f"run not found: {run_path}", file=sys.stderr)
        return 2

    data = read_json(run_path)
    print(f"run_id: {data.get('run_id')}")
    print(f"mode: {data.get('mode', 'run')}")
    print(f"status: {data.get('status')}")
    print(f"error_code: {data.get('error_code') or ''}")
    print(f"iteration: {data.get('iteration')}/{data.get('max_iterations')}")
    print(f"workspace: {data.get('workspace')}")
    if data.get("plan_path"):
        print(f"plan: {artifacts_root / run_id / data['plan_path']}")
    print(f"summary: {artifacts_root / run_id / data.get('summary_path', 'summary.md')}")
    return int(data.get("exit_code") or 0)


def latest_run_id(artifacts_root: Path) -> str | None:
    records = read_index(artifacts_root / "index.jsonl")
    if not records:
        return None
    return str(records[-1].get("run_id") or "") or None


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command == "init":
        return cmd_init(args)
    if args.command == "run":
        return cmd_run(args)
    if args.command == "plan":
        return cmd_plan(args)
    if args.command == "discover":
        return cmd_discover(args)
    if args.command == "status":
        return cmd_status(args)

    parser.print_help()
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
