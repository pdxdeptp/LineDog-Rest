## Context

The current idle app has no obvious busy loop, but it keeps the main run loop awake through several repeating timers:

- `WindowManager` polls the global cursor at 10 Hz to keep the transparent idle pet window click-through outside the pet hit area.
- `AutoTimerEngine` polls at 4 Hz while waiting for the next `:00` or `:30` rest anchor.
- `BreakRunController` moves the pet window at 60 Hz during break-run rest.
- `PetStageView` redraws fullscreen rest at 15 Hz for the entire rest duration.
- `PetRenderer` decodes GIF frames whenever static or intermediate animation paths reload a GIF.
- `BackendProcessManager` starts the local Python backend during app launch, even before the assistant panel is used.

The optimization needs to preserve user-visible interaction: clicking or dragging the pet must still work, outside clicks must still pass through, scheduled rests must still happen at clock anchors, and the assistant panel must still communicate connection state.

## Goals / Non-Goals

**Goals:**

- Reduce always-on idle wakeups when the pet is static and no assistant UI is open.
- Preserve existing desktop pet hit testing, menu opening, drag behavior, rest routing, and countdown behavior.
- Keep animation and rest visuals close to the current experience, with lower timer frequency where possible.
- Add focused tests around scheduling decisions and lifecycle behavior before implementation.
- Keep the implementation local to existing Swift/AppKit components.

**Non-Goals:**

- Do not redesign the pet visuals, menu UI, or learning assistant UI.
- Do not remove break-run or fullscreen rest modes.
- Do not change backend API contracts or learning data storage.
- Do not add new third-party dependencies.
- Do not require privileged energy tooling for test verification.

## Decisions

### Use adaptive timer scheduling for idle cursor tracking

`WindowManager` should keep the same pass-through semantics but avoid a fixed 10 Hz timer forever. The low-risk path is an adaptive repeating timer with slower polling when the pointer is outside the pet hit area and faster polling only near or inside the pet window. This keeps behavior compatible with transparent AppKit windows, where pure tracking areas are unreliable when `ignoresMouseEvents=true`.

Alternative considered: replace polling entirely with local/global mouse monitors. This can miss pointer transitions over a click-through window and may require accessibility permissions for global monitoring, so it is higher risk for this pass.

### Schedule automatic rest anchors with one-shot timers

`AutoTimerEngine` should schedule a one-shot timer for the next half-hour anchor instead of polling every 0.25 seconds. Once rest begins, it can use a 1 Hz repeating timer because UI consumers only need whole-second countdown updates. This preserves the `autoWatching(nextAnchor:)` and `.resting(remaining:)` state contract while removing permanent wakeups.

Alternative considered: keep 0.25 second ticks during rest for more precise countdown transitions. The current implementation already only emits whole-second changes, so 1 Hz is sufficient.

### Lower break-run frame rate and make movement time-based

Break-run should target 30 Hz by default and compute movement from elapsed time instead of pixels per timer tick. This reduces WindowServer and main-thread work while keeping speed stable if the timer fires late.

Alternative considered: keep 60 Hz but skip every other frame. That lowers window updates but makes speed math harder to reason about and still wakes the timer at 60 Hz.

### Decouple fullscreen rest animation cadence from countdown cadence

The approach animation needs smooth-ish visual updates only while the pet moves and the dimming progresses. After approach completion, countdown text can update once per second and the rest view should avoid continuous layout/redraw.

Alternative considered: leave fullscreen rest unchanged because it is not an idle path. The change is still worthwhile because long rests can last minutes.

### Cache decoded GIF frames by URL

`PetRenderer` should cache decoded frames per GIF URL for static-first-frame and intermediate manual playback paths. This avoids repeated disk reads and ImageIO decoding when intensity changes or modes are reapplied.

Alternative considered: rely solely on `NSImage` native GIF playback. Intermediate intensity control needs manual frames, so caching is still needed.

### Make assistant backend startup mode configurable

`BackendProcessManager` should expose an idempotent `startIfNeeded()` path. A persisted user setting should choose whether the app delegate starts the backend eagerly at app launch or defers startup until `LearningAssistantViewModel` is created or loaded. The energy-oriented default remains lazy startup, while users who want the assistant panel to open faster can opt into eager startup.

Alternative considered: keep eager backend startup and only reduce polling. The measured backend CPU was low, but memory and process startup are still avoidable for users who never open the assistant. Making the policy configurable keeps that energy win without forcing every user into the same latency trade-off.

## Risks / Trade-offs

- Adaptive cursor polling may delay clickability by a small fraction of a second when the pointer approaches from far away. Mitigation: use a faster cadence near the window frame and immediately sync on mouse policy changes.
- One-shot anchor scheduling may miss an anchor if the machine sleeps through it. Mitigation: when the timer fires or scheduling resumes, compare `Date()` with the anchor and begin rest if due.
- Lower break-run frame rate may feel less fluid. Mitigation: time-based movement preserves speed, and 30 Hz is adequate for a small desktop pet.
- Lazy backend startup changes app launch behavior. Mitigation: expose a settings toggle so users can restore eager startup, and test both launch policies.
- GIF caching increases memory slightly. Mitigation: cache only decoded frames for bundled GIF URLs used by the pet, and reuse existing images instead of repeatedly allocating them.
