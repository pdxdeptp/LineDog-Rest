# Round 04 Review: AI Capability Boundary

## Reviewer Lens

The assistant will use LLMs for routing and planning, so the design must prevent hidden hallucinated certainty, fabricated repo understanding, or disguised prioritization.

## Issues Found

1. Calibration was mentioned but not treated as a first-class review requirement.
2. The design did not explicitly require provenance for user-provided facts, parsed facts, and AI assumptions.
3. GitHub fallback needed a stronger "do not invent repo structure" constraint.

## Modifications Made

- Added Decision 11 to `design.md` for calibration and provenance.
- Added `Calibration And Provenance` requirement to `study-intake-planning`.
- Added material ingestion scenario requiring unavailable repo facts to remain unavailable rather than invented.

## Result

The design now treats AI output as a draft with visible evidence and uncertainty, not as an authoritative hidden planner.
