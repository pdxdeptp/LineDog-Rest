## Why

Once Add / Initiate can route items and persist drafts, the system needs the actual Plan Compiler: the part that turns a confirmed learning/project intent into phases, milestones, executable task candidates, estimates, assumptions, and calibration.

This change is the third split from `redesign-study-intake-planning`. It owns the compilation pipeline before deterministic date placement. It must not be a single "make me a plan" prompt, and it must not let the LLM assign final dates.

## What Changes

- Build normalized `PlanningEnvelope` input from confirmed role, anchors, source summaries, existing plan context, source roles, target output, target depth, and provenance.
- Select plan archetype and scope boundary using deterministic signals and narrow ambiguity handling.
- Make target depth operational: it changes completion evidence and task families.
- Generate phases and milestones with observable completion evidence.
- Generate executable task candidates with concrete output, criteria, estimates, dependencies, fallback mode, split points, and assumptions.
- Validate LLM outputs against narrow schemas and bounded repair loops.
- Normalize estimates using source facts, user estimates, archetype defaults, LLM suggestions, clamps, confidence, and low-calibration flags.
- Emit compiler trace records for validation, repair, estimate normalization, and calibration.

## Capabilities

### Affected Specs

- `study-intake-planning`

### New Capability

- `study-intake-planning`: structured plan compilation from confirmed anchors into validated phases and task candidates.

## Impact

- Future backend/API: compiler service or module, LLM schema contracts, validators, repair loop, estimate normalizer, trace records.
- Future scheduler consumes validated task candidates and estimate confidence from this change.
- Future UI can show assumptions and low-calibration warnings from this change, but UI rendering itself is not in scope.
