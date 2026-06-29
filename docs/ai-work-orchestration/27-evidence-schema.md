# Evidence Summary Schema

## Contract

`evidence-summary.json` is the local evidence index for one run. It is local-only and must not imply remote writeback.

Required top-level fields:

- `schema_version`: schema version, currently `1`.
- `issue`: issue or case identifier.
- `run_id`: run directory name.
- `run_dir`: local run path.
- `run`: run status and mode metadata.
- `checks`: gate, strict, and timing accuracy summaries.
- `artifacts`: concrete artifact map used by existing tools.
- `artifact_registry`: registry-backed grouped view from `config/evidence-artifacts.json`.
- `remote_writes`: boolean, always `false` for collection.

## Artifact Registry

`config/evidence-artifacts.json` is the source of truth for reusable evidence definitions. Each artifact has:

- `key`: stable machine key.
- `path`: path relative to `runs/<run-id>/`.
- `group`: logical group such as `core`, `preflight`, `gate`, `timing`, `evidence`, `review`, or `writeback`.
- `required_for`: task types where the artifact is required.

`collect-evidence.sh` keeps the legacy `artifacts` map for compatibility and adds `artifact_registry` so new artifacts can be registered without expanding long positional argument lists.

## Timing Accuracy

`checks.timing_accuracy` summarizes every `execution-time-contract*.json` artifact and must expose:

- `artifact_count`
- `trusted_measured_count`
- `within_one_minute_count`
- `one_minute_miss_count`
- `latest.absolute_error_minutes`
- `latest.within_one_minute`
- `latest.elapsed_minutes`
- `latest.recommended_next_estimate_minutes`

## Task-Type Checklist

Checklist tools should prefer registry groups for task-type-specific required evidence. A `documentation` run does not need writeback artifacts; a `writeback` run must show approval boundary and writeback summary artifacts.
