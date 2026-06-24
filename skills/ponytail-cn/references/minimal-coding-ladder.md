# Minimal Coding Ladder

## Source Note

This local skill is inspired by the public Ponytail project by DietrichGebert, but it does not vendor Ponytail source code or install its hooks. The local policy keeps the useful coding discipline while fitting Sinan's local-first, evidence-driven Loop workflow.

Primary source: https://github.com/DietrichGebert/ponytail
License of source project: MIT.

## What To Optimize

Optimize for necessary code, not clever code golf.

Good minimality:
- fewer moving parts
- fewer dependencies
- fewer new concepts
- less surface area to test
- less future maintenance

Bad minimality:
- removing validation
- hiding errors
- skipping edge cases named in acceptance criteria
- compressing code until unreadable
- using one-liners that are harder to maintain

## Overengineering Smells

- New abstraction for one caller
- New dependency for platform behavior
- New service/class/factory before there is variation
- New config knob without a second use case
- Reimplementing an existing helper
- Broad refactor to fix a local bug
- Writing a generic solution when acceptance is concrete
- Adding tests for invented behavior rather than requested behavior

## Safe Stop Conditions

Stop and ask or return to Loop planning when:

- acceptance criteria are unclear
- the smallest fix touches many business domains
- schema, deployment, remote Git, production, permissions, deletes, or data migrations appear
- security/auth/payment/data-loss semantics are uncertain
- the requested shortcut would bypass validation or safety
