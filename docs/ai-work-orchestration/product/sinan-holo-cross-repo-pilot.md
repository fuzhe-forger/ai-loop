# Sinan × Holo Cross-Repo Pilot Case

## Purpose

This case turns `holo-project` into the first concrete multi-repo/persona pilot for Sinan v1.1 → v2.0.

Sinan governs execution: task entry, gates, evidence, timing, memory, side-effect approval, and closeout.

Holo provides the persona/taste layer: Greykey for minimal implementation, Reviewer for boundary critique, and Coordinator for context, evidence, and handoff control.

## Repositories

| Repo | Role |
|---|---|
| `/home/user/JAVA/ai/ai-loop` | Governance engine, evidence, timing, task/run protocol |
| `/mnt/d/JAVA/holo-project` | Persona/profile engine, multi-agent taste acceptance, role samples |

## Pilot Acceptance

| Check | Evidence |
|---|---|
| Sinan v2 gap audit exists | `runs/sinan-holo-cross-repo-pilot-20260629/v2-gap-audit.md` |
| Both repos are referenced by evidence | `runs/sinan-holo-cross-repo-pilot-20260629/` multi-repo evidence artifacts |
| Holo profile validation remains green | `python3 scripts/verify_positioning.py` in `holo-project` |
| Sinan local toolchain remains green | `./scripts/verify-toolchain.sh` and `./scripts/sinan-doctor.sh` in `ai-loop` |
| v2 local acceptance passes for this run | `./scripts/sinan-v2-acceptance.sh --run-id sinan-holo-cross-repo-pilot-20260629` |

## Role Mapping

| Role | Source | Expected Output |
|---|---|---|
| Coordinator | `docs/agent_profiles/coordinator_persona.md` | Goal, scope, side-effect boundary, handoff |
| Greykey | `docs/agent_profiles/greykey.md` | Minimal local change, validation, no overbuild |
| Reviewer | `docs/agent_profiles/reviewer.md` | Failure modes, boundary risks, acceptance holes |

## Current Slice

This slice does not attempt real external writeback, deployment, or automated reviewer final decisions. It only establishes the local case pack and evidence path required for the next v1.1 E2E iteration.

## Next Slices

1. Run a real Holo persona update through Sinan gates with role-specific outputs.
2. Add a reviewer packet comparing Greykey output against Holo taste acceptance.
3. Promote the pilot into a v1.1 code-task E2E case pack.
4. Only after explicit approval, mirror the case to external documentation with readback evidence.
