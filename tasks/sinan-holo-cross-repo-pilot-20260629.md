# Sinan × Holo Cross-Repo Pilot

## Goal

推进 `ai-loop` 与 `holo-project` 的联动试点：用 Holo 的 Greykey/Reviewer/Coordinator 人格资料作为司南跨仓库、多角色治理案例，补齐本地 v2 gap audit 证据，并形成一个可继续执行的最小 case pack。

## Scope

- Local-only repository changes.
- No remote Git push.
- No Feishu/Multica/Obsidian writes.
- No deployment, production, permission, delete, or destructive operation.

## Acceptance

- `runs/<run-id>/v2-gap-audit.md` exists and states remaining v2 gaps.
- A cross-repo pilot case document exists under `docs/ai-work-orchestration/product/`.
- Multi-repo evidence references both `ai-loop` and `holo-project`.
- Local verification passes: `verify-toolchain.sh`, `sinan-doctor.sh`, `sinan-v2-acceptance.sh --run-id <run-id>`.
