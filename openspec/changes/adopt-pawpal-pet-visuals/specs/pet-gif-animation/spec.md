## ADDED Requirements

### Requirement: Pet renders animated GIF per display mode
The `PetRenderer` SHALL display an animated GIF image for each `PetDisplayMode`, sourced from the 线条小狗 GIF set bundled with the app. No color tinting is applied to GIF content.

#### Scenario: Running state shows idle animation
- **WHEN** `setDisplayMode(.runningBlack)` is called
- **THEN** the pet image view plays one of the idle GIFs: `线条小狗第12弹_无聊.gif`, `线条小狗第12弹_晃脚脚.gif`, `线条小狗第1弹_摆烂.gif`, or `线条小狗第9弹_甩耳朵.gif`

#### Scenario: Resting state shows break prompt animation
- **WHEN** `setDisplayMode(.restingRed)` is called
- **THEN** the pet image view plays one of: `线条小狗第2弹_激动.gif`, `线条小狗第5弹_偷看.gif`, `线条小狗第5弹_出去玩.gif`, `线条小狗第1弹_啦啦啦.gif`, or `线条小狗第1弹_来了.gif`

#### Scenario: Paused state shows sleeping animation
- **WHEN** `setDisplayMode(.pausedWhiteOutline)` is called
- **THEN** the pet image view plays `线条小狗第12弹_困.gif`

#### Scenario: Thinking state shows focus guard animation
- **WHEN** `setDisplayMode(.thinking)` is called
- **THEN** the pet image view plays one of: `线条小狗第17弹_工作.gif` or `线条小狗第2弹_努力.gif`

### Requirement: GIF variant cycles after playback completes
For states with multiple GIF variants, the renderer SHALL select a new random variant after the current GIF finishes playing, avoiding repeating the same variant consecutively.

#### Scenario: Idle GIF rotates to a different variant
- **WHEN** an idle GIF reaches its last frame
- **THEN** a different idle GIF variant begins playing

#### Scenario: Single-variant state loops the same GIF
- **WHEN** a state with only one GIF variant (e.g., `sleeping`) finishes
- **THEN** the same GIF loops from the beginning

### Requirement: GIF files are bundled as app resources
All 线条小狗 GIF files from PawPal's `pet_assets/线条小狗/` SHALL be added to the app bundle under a `LineDog/` resource folder, organized into subfolders matching PawPal's state names.

#### Scenario: GIF file is loadable at runtime
- **WHEN** the app launches
- **THEN** `Bundle.main.url(forResource:withExtension:subdirectory:)` resolves each GIF path without returning `nil`

#### Scenario: Missing GIF falls back gracefully
- **WHEN** a GIF file cannot be found in the bundle
- **THEN** the pet image view shows the `dog.fill` SF Symbol fallback (no crash)

### Requirement: Old static image and tint-color approach is removed
The `outlineImageView` layer and `contentTintColor` tinting in `PetRenderer` SHALL be removed. The `MalDazePet.imageset` image set SHALL be removed from `Assets.xcassets`.

#### Scenario: PetRenderer has no outline image view
- **WHEN** `PetRenderer` is initialized
- **THEN** only one `NSImageView` exists in the view hierarchy (no `outlineImageView`)

#### Scenario: MalDazePet.imageset is absent
- **WHEN** Assets.xcassets is inspected
- **THEN** no `MalDazePet` image set exists
