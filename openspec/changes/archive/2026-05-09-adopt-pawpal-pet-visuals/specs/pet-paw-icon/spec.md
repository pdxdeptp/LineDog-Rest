## ADDED Requirements

### Requirement: Menu bar icon uses pawprint symbol
`MenuBarDogLabel` SHALL display `pawprint.fill` SF Symbol in place of `dog.fill` for all four `PetDisplayMode` cases. Color semantics (primary / red / white+black / indigo) are preserved.

#### Scenario: Running mode shows black pawprint
- **WHEN** `MenuBarDogLabel` renders with `mode == .runningBlack`
- **THEN** a `pawprint.fill` symbol is shown with `.primary` foreground style

#### Scenario: Resting mode shows red pawprint
- **WHEN** `MenuBarDogLabel` renders with `mode == .restingRed`
- **THEN** a `pawprint.fill` symbol is shown with `.red` foreground style

#### Scenario: Paused mode shows white pawprint with black outline
- **WHEN** `MenuBarDogLabel` renders with `mode == .pausedWhiteOutline`
- **THEN** a layered `ZStack` shows a slightly larger `pawprint.fill` in black behind a smaller `pawprint.fill` in white

#### Scenario: Thinking mode shows indigo pawprint
- **WHEN** `MenuBarDogLabel` renders with `mode == .thinking`
- **THEN** a `pawprint.fill` symbol is shown with `.indigo` foreground style

### Requirement: App icon uses paw print design
The `AppIcon.appiconset/MalDazeMark.png` SHALL be replaced with a paw-print image. The new image SHALL visually match PawPal's paw geometry (one large central pad, four smaller toe pads above it).

#### Scenario: App icon displays in Dock and Finder
- **WHEN** MalDaze is visible in the macOS Dock or Finder
- **THEN** the app icon shows a paw print, not the previous dog silhouette

### Requirement: No `dog.fill` symbol remains in pet-facing UI
After the change, neither `MenuBarDogLabel` nor `PetRenderer` SHALL reference the `dog.fill` SF Symbol name for pet display purposes.

#### Scenario: Codebase search finds no pet dog.fill usage
- **WHEN** the codebase is searched for `"dog.fill"` in pet-display UI files
- **THEN** no occurrences exist in `MenuBarDogLabel.swift` or `PetRenderer.swift`
