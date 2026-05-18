## 1. Renderer Behavior

- [x] 1.1 Add a failing `PetRendererTests` regression proving `.breakRunning` uses full-motion playback when idle animation intensity is 0 or intermediate.
- [x] 1.2 Implement the `.breakRunning` full-motion effective-intensity override inside `PetRenderer` without changing persisted idle intensity.
- [x] 1.3 Confirm `.breakRunning` still avoids variant rotation and existing idle/intensity tests continue to pass.

## 2. Verification

- [x] 2.1 Run focused tests for `PetRendererTests`.
- [x] 2.2 Run OpenSpec validation for `decouple-break-run-animation-intensity`.
