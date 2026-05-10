## Context

MalDaze's pet visuals are built around a single vector asset (`MalDazePet.imageset/MalDazeMark.png`) rendered through `PetRenderer.swift` using `NSImageView.contentTintColor`. Four `PetDisplayMode` cases swap between color states (black/red/white/indigo) to signal timer state. The menu bar icon uses `dog.fill` from SF Symbols.

PawPal (https://github.com/zebangeth/PawPal) ships 25 animated GIFs for its 线条小狗 skin, organized into 13 state folders. Each state can have 1–5 variant GIFs; the app cycles variants randomly. This produces a living desktop companion vs. a colored silhouette.

The goal is to port PawPal's 线条小狗 GIF set and its state-dispatch logic into MalDaze's Swift/AppKit renderer while preserving all existing caller contracts.

## Goals / Non-Goals

**Goals:**
- Play PawPal's animated 线条小狗 GIFs in the desktop pet window across all MalDaze operational states
- Replace `dog.fill` menu bar icon with `pawprint.fill` across all 4 `PetDisplayMode` cases
- Replace app icon with a paw-print design
- Keep `PetRendering` protocol surface identical (no caller changes required)
- Keep `PetDisplayMode` enum cases identical (no upstream changes required)

**Non-Goals:**
- Supporting 金毛 puppy or any second skin (not in scope)
- Adopting PawPal's full 14-state `PetState` type system into MalDaze
- Networking or on-demand GIF download — all assets are bundled
- Animated tray icon (menu bar item is a static SF Symbol)

## Decisions

### D1: GIF playback via `NSBitmapImageRep` frame-stepping over `NSImageView.animates`

`NSImageView.animates = true` plays the GIF at its embedded frame rate but cannot be stopped, swapped mid-cycle, or cross-faded. Using `NSBitmapImageRep.currentFrame` with a `CADisplayLink` or a 24fps `Timer` gives explicit frame control needed for:
- Cycling to a new variant GIF after the current one finishes
- Switching states mid-animation cleanly
- Controlled fade-in when entering rest phase

**Alternative considered**: Third-party `SDWebImage` or `Gifu`. Rejected — adds a Swift Package dependency for functionality achievable with 30 lines of standard AppKit.

**Alternative considered**: `WKWebView` rendering `<img src="...gif">`. Rejected — heavyweight, requires web permissions, and introduces an IPC round-trip.

### D2: Map `PetDisplayMode` → GIF state subset, not full `PetState` adoption

MalDaze has 4 operational modes tied to the timer engine. PawPal has 14 states. Adopting all 14 would require timer-engine changes out of scope for this visual-only change. Instead, a static lookup table in `PetRenderer` maps each `PetDisplayMode` to a list of GIF file paths:

| `PetDisplayMode` | PawPal state folder | GIF files used |
|---|---|---|
| `runningBlack` | `idle` | 线条小狗第12弹_无聊.gif, 线条小狗第12弹_晃脚脚.gif, 线条小狗第1弹_摆烂.gif, 线条小狗第9弹_甩耳朵.gif |
| `restingRed` | `breakPrompt` + `breakRunning` | 线条小狗第2弹_激动.gif, 线条小狗第5弹_偷看.gif, 线条小狗第5弹_出去玩.gif, 线条小狗第1弹_啦啦啦.gif, 线条小狗第1弹_来了.gif |
| `pausedWhiteOutline` | `sleeping` | 线条小狗第12弹_困.gif |
| `thinking` | `focusGuard` | 线条小狗第17弹_工作.gif, 线条小狗第2弹_努力.gif |

No tint/color overlay is applied — GIFs carry their own palette. The `outlineImageView` layer used for the white/black border effect is removed.

### D3: GIF files added as loose bundle resources, not inside `.xcassets`

`.xcassets` does not support animated GIF processing — Xcode strips animation frames during asset compilation. GIFs must be added as direct bundle resources (Build Phase → Copy Bundle Resources). A `LineDog/` folder in the Xcode project organizes them by state.

**Directory layout in bundle:**
```
LineDog/
  idle/
    线条小狗第12弹_无聊.gif
    ...
  breakPrompt/
    线条小狗第2弹_激动.gif
    ...
  breakRunning/ ...
  sleeping/ ...
  focusGuard/ ...
```

### D4: GIF variant cycling — finish-then-swap, no interrupt

When `setDisplayMode` is called, the in-progress GIF plays to completion; the new state's GIF starts on the next cycle. Exception: if the mode changes to `restingRed` during `runningBlack`, swap immediately (rest is time-critical). This matches PawPal's `CONTINUOUS_ASSET_STATES` pattern (only `idle` and `focusGuard` rotate variants; others play once).

### D5: Menu bar icon — `pawprint.fill` SF Symbol

PawPal's tray icon is a programmatic pixel-art paw (5 circles). The nearest Apple SF Symbol is `pawprint.fill`, available since macOS 11. This preserves template-image behavior (adapts to light/dark menu bar) with zero image assets. All 4 `PetDisplayMode` cases in `MenuBarDogLabel.swift` switch from `dog.fill` to `pawprint.fill`; color logic is unchanged.

### D6: App icon — redraw `MalDazeMark.png` as paw print

The existing `MalDazeMark.png` (used for both app icon and pet image) is a dog silhouette. Since the pet image is being replaced by GIFs, the PNG only serves the app icon slot. It should be redrawn as a paw print to match the new brand. This is a design asset change; implementation is "replace the PNG file". The `MalDazePet.imageset` image set is removed from `Assets.xcassets` (no longer used).

## Risks / Trade-offs

- **GIF file size**: 25 GIFs from PawPal average ~80–200 KB each. Total bundle addition ≈ 3–4 MB. Acceptable for a desktop app; no mitigation needed.
- **Frame-stepping timer overhead**: A 24fps `Timer` fires 24 times/second while the pet is visible. Mitigated by invalidating the timer when the window is hidden (existing `WindowManager` hide/show logic).
- **Chinese filenames in bundle**: macOS handles UTF-8 filenames natively; `Bundle.main.url(forResource:withExtension:subdirectory:)` works correctly. No rename needed.
- **`NSBitmapImageRep` GIF decode on main thread**: For 80–200 KB GIFs, decode is negligible (<1 ms). No background decode queue needed.
- **`outlineImageView` removal**: The white-border effect used in `runningBlack` and `pausedWhiteOutline` was a workaround for the single-color-template-image approach. GIFs render their own outlines (the 线条小狗 design has built-in black outlines on white body). The border layer is simply deleted.

## Migration Plan

1. Copy 25 GIF files from PawPal `pet_assets/线条小狗/` into `MalDaze/LineDog/` (organized by state)
2. Add all GIFs to Xcode project → Build Phase → Copy Bundle Resources
3. Remove `MalDazePet.imageset` from `Assets.xcassets`
4. Rewrite `PetRenderer.swift` with GIF frame-stepper + state→GIF mapping table
5. Update `MenuBarDogLabel.swift`: `dog.fill` → `pawprint.fill` (4 occurrences)
6. Replace `MalDazeMark.png` in `AppIcon.appiconset` with paw-print design
7. Build and verify each `PetDisplayMode` state shows correct animation

Rollback: revert commits in reverse order; GIF files are additive so no database or format migration required.

## Open Questions

- Q1: Should `restingRed` show `breakPrompt` GIFs during the 60s approach animation and switch to `breakRunning` once the pet reaches center? This would require `PetStageView` to call `setDisplayMode` at the midpoint. **Current decision: out of scope — use `breakPrompt` only for simplicity; the distinction can be added later.**
- Q2: Who redraws `MalDazeMark.png` as a paw? This is a manual design asset task for the developer; not automated by code changes.
