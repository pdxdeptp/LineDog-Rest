## Why

MalDaze's pet is currently a static PNG rendered with color tinting across 4 states — visually inert and easily ignored in users' peripheral vision. PawPal's 线条小狗 design uses expressive, looping animated GIFs with 14 distinct behavioral states that communicate the app's intent with personality. Replacing MalDaze's static dog icon and color-tint renderer with PawPal's animated GIF system will make the pet feel alive and dramatically increase its presence as a break-reminder companion.

## What Changes

- **Menu bar icon**: Replace `dog.fill` SF Symbol in `MenuBarDogLabel.swift` (all 4 modes) with `pawprint.fill` SF Symbol, matching PawPal's paw-print tray icon identity.
- **App icon**: Replace `Assets.xcassets/AppIcon.appiconset/MalDazeMark.png` with a paw-print-based design derived from PawPal's programmatic paw geometry.
- **Pet renderer**: Replace `PetRenderer.swift`'s static `NSImageView` + `contentTintColor` approach with an animated GIF player (NSImageView `animates = true` or `NSBitmapImageRep` frame-stepping), sourcing the 线条小狗 GIF files bundled from PawPal's `pet_assets/线条小狗/`.
- **Pet image asset**: Replace `Assets.xcassets/MalDazePet.imageset/MalDazeMark.png` (single static image) with a bundle of 25+ GIF files organized by state.
- **`PetDisplayMode` → GIF state mapping**: Map MalDaze's 4 operational modes to subsets of PawPal's 14 GIF states, preserving existing caller contracts.

## Capabilities

### New Capabilities

- `pet-gif-animation`: The pet renderer plays animated GIFs selected by state, cycling through multiple variants for idle and non-critical states. Replaces all color-tint logic.
- `pet-paw-icon`: Menu bar icon and app icon both use a paw-print design instead of the generic dog silhouette.

### Modified Capabilities

<!-- No existing specs exist; all behavioral contracts are new -->

## Impact

- **`MalDaze/PetRenderer/PetRenderer.swift`**: Full rewrite of render logic; `PetRendering` protocol surface unchanged.
- **`MalDaze/PetDisplayMode.swift`**: Enum cases remain; new internal GIF-state lookup table added alongside.
- **`MalDaze/MenuBarDogLabel.swift`**: Symbol name changes only; layout and state logic unchanged.
- **`MalDaze/Assets.xcassets/`**: New `LineDogGIFs` group added; existing `MalDazePet.imageset` removed.
- **`MalDaze.xcodeproj`**: GIF files added as bundled resources.
- **No API or IPC changes**; all callers of `PetRenderer` and `PetDisplayMode` are unaffected.
