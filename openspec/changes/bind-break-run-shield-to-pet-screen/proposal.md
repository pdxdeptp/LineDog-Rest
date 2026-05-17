## Why

跑屏休息 60 秒后出现的半透明遮罩目前跟随 `NSScreen.main`，在仅菜单栏应用里可能随鼠标/焦点屏变化。用户在倒计时剩 4 分钟时如果鼠标重心位于其他屏幕，会看到其他屏幕被降亮度，而不是小狗正在跑的屏幕。

## What Changes

- Bind the delayed break-run shield to the screen containing the running desk pet window.
- Keep the shield independent from the current mouse location, keyboard focus screen, and `NSScreen.main`.
- Preserve the existing countdown panel, break-run movement, click-through, and early-end behavior.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `break-interruption`: clarify that the delayed break-run shield appears on the same physical display as the running desk pet.

## Affected Specs

- `break-interruption`

## Impact

- Affected code: `MalDaze/WindowManager/WindowManager.swift`
- Affected tests: `MalDazeTests/*` coverage for break-run shield screen selection
- No API, dependency, data model, or user-defaults changes.
