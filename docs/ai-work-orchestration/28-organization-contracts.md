# Organization Contracts

Phase C turns routing, policy, side-effect gates, and review orchestration into stable local contracts.

## Contracts

- `route-result.v1`: produced by `scripts/route-actor.sh`; includes `next_actor`, `assigned_actor`, `role`, `lane`, `reason`, and `remote_write=false`.
- `policy-report.v1`: produced by `scripts/gate-policy-check.sh`; includes task type, required/optional gates, decision, failures, warnings, and side-effect summary.
- `side-effect-manifest.v1`: produced by `scripts/approval-boundary.sh`; includes action, category, side effect, approval requirement, approval presence, and decision.
- `review-orchestration.v1`: produced by `scripts/evaluate-state.sh`; includes evidence readiness, review packet presence, verification presence, verdict, and next actor.

## Preflight

`loop-execution-preflight.sh` exposes `organization_contract` so a run can see which contracts it is expected to use before implementation or writeback.

## Side Effects

These contracts are local-only. They do not approve remote writes. Feishu, Multica, Git remote, deployment, tool install, and Codex config writes still require approval-boundary policy and explicit approval unless a standing approval exists.
