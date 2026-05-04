## 1. Copy PawPal GIF Assets into MalDaze Project

- [x] 1.1 Create folder `MalDaze/LineDog/idle/` and copy these 4 files from PawPal `pet_assets/线条小狗/idle/`: `线条小狗第12弹_无聊.gif`, `线条小狗第12弹_晃脚脚.gif`, `线条小狗第1弹_摆烂.gif`, `线条小狗第9弹_甩耳朵.gif`
- [x] 1.2 Create folder `MalDaze/LineDog/breakPrompt/` and copy these 3 files from PawPal `pet_assets/线条小狗/breakPrompt/`: `线条小狗第2弹_激动.gif`, `线条小狗第5弹_偷看.gif`, `线条小狗第5弹_出去玩.gif`
- [x] 1.3 Create folder `MalDaze/LineDog/breakRunning/` and copy these 2 files from PawPal `pet_assets/线条小狗/breakRunning/`: `线条小狗第1弹_啦啦啦.gif`, `线条小狗第1弹_来了.gif`
- [x] 1.4 Create folder `MalDaze/LineDog/sleeping/` and copy this 1 file from PawPal `pet_assets/线条小狗/sleeping/`: `线条小狗第12弹_困.gif`
- [x] 1.5 Create folder `MalDaze/LineDog/focusGuard/` and copy these 2 files from PawPal `pet_assets/线条小狗/focusGuard/`: `线条小狗第17弹_工作.gif`, `线条小狗第2弹_努力.gif` (also included `线条小狗第9弹_甩耳朵.gif` from focusGuard)

## 2. Add GIF Files to Xcode Project as Bundle Resources

- [x] 2.1 In `MalDaze.xcodeproj`, add the `LineDog/` folder to the project navigator under the `MalDaze` group (drag-and-drop or Add Files), selecting "Create folder references" so the directory structure is preserved in the bundle
- [x] 2.2 Verify that all 12 GIF files appear in `MalDaze` target → Build Phases → Copy Bundle Resources (add manually if Xcode did not auto-include them)
- [x] 2.3 Build the project and confirm `Bundle.main.url(forResource: "线条小狗第12弹_无聊", withExtension: "gif", subdirectory: "LineDog/idle")` returns a non-nil URL

## 3. Remove Old Pet Image Asset

- [x] 3.1 Delete `MalDaze/Assets.xcassets/MalDazePet.imageset/MalDazeMark.png` from the filesystem
- [x] 3.2 Delete the `MalDazePet.imageset/` folder and its `Contents.json` from `Assets.xcassets` in both Xcode and the filesystem
- [x] 3.3 Confirm no Swift file references `NSImage(named: "MalDazePet")` — the only caller is `PetRenderer.swift` which will be rewritten in step 4

## 4. Rewrite `PetRenderer.swift` — GIF Frame-Stepper

Replace the entire body of `MalDaze/PetRenderer/PetRenderer.swift` with the new implementation below. The `PetRendering` protocol declaration at the top of the file stays **unchanged**.

- [x] 4.1 Remove `outlineImageView: NSImageView` property and all references to it (including `outlineImageView.wantsLayer`, `outlineImageView.contentTintColor`, `outlineImageView.isHidden`, `outlineImageView.frame`, `parent.addSubview(outlineImageView)`)
- [x] 4.2 Remove `imageView.contentTintColor` assignments in `setDisplayMode(_:)` — tinting is no longer used
- [x] 4.3 Add a `displayMode → [URL]` lookup table as a static computed property or lazy var that maps:
  - `.runningBlack` → URLs for `LineDog/idle/线条小狗第12弹_无聊.gif`, `…晃脚脚.gif`, `…摆烂.gif`, `…甩耳朵.gif`
  - `.restingRed` → URLs for `LineDog/breakPrompt/线条小狗第2弹_激动.gif`, `…偷看.gif`, `…出去玩.gif`, `LineDog/breakRunning/线条小狗第1弹_啦啦啦.gif`, `…来了.gif`
  - `.pausedWhiteOutline` → URL for `LineDog/sleeping/线条小狗第12弹_困.gif`
  - `.thinking` → URLs for `LineDog/focusGuard/线条小狗第17弹_工作.gif`, `…努力.gif`
  
  Use `Bundle.main.url(forResource:withExtension:subdirectory:)` to resolve each path at initialization time; store the results.
- [x] 4.4 Add GIF playback properties: `private var gifRep: NSBitmapImageRep?`, `private var frameCount: Int = 0`, `private var currentFrame: Int = 0`, `private var frameTimer: Timer?`, `private var currentVariantURLs: [URL] = []`, `private var currentVariantIndex: Int = 0`
- [x] 4.5 Add method `loadGIF(url: URL)` that: (a) loads `NSData` from the URL, (b) creates `NSBitmapImageRep` from the data, (c) reads `NSBitmapImageRep.value(forProperty: .frameCount)` to get `frameCount`, (d) resets `currentFrame = 0`, (e) sets `imageView.image` to the first frame extracted by setting `.currentFrame = 0` then calling `.bitmapImageRepresentation`/`NSImage` — or use `NSImage(data:)` with `animates = false` and step manually. Simplest approach: load `NSImage(data:)` into `imageView.image` and set `imageView.animates = true` for the GIF to self-play, then only the variant-rotation logic is needed.
- [x] 4.6 Add method `startGIFCycle(urls: [URL])` that: (a) invalidates `frameTimer`, (b) stores `currentVariantURLs = urls`, (c) picks a random starting index, (d) calls `loadGIF(url: currentVariantURLs[index])`, (e) if `urls.count > 1`, schedules a `Timer` to rotate variants — fire interval = GIF duration (read from `NSBitmapImageRep.value(forProperty: .loopCount)` or default to 3 seconds)
- [x] 4.7 Update `setDisplayMode(_ mode: PetDisplayMode)` to call `startGIFCycle(urls: gifs(for: mode))` where `gifs(for:)` returns the URL array from task 4.3's lookup table
- [x] 4.8 Update `loadPetImage()` (called from `install(in:)`) to call `startGIFCycle(urls: gifs(for: .runningBlack))` as the initial state; keep the `dog.fill` SF Symbol as fallback if the first URL is nil
- [x] 4.9 Add `deinit { frameTimer?.invalidate() }` to clean up the rotation timer

## 5. Update `MenuBarDogLabel.swift` — `dog.fill` → `pawprint.fill`

File: `MalDaze/MenuBarDogLabel.swift`

- [x] 5.1 In the `.runningBlack` case: change `Image(systemName: "dog.fill")` to `Image(systemName: "pawprint.fill")`
- [x] 5.2 In the `.pausedWhiteOutline` case: change both `Image(systemName: "dog.fill")` occurrences (outer at `iconSize * 1.22` and inner at `iconSize`) to `Image(systemName: "pawprint.fill")`
- [x] 5.3 In the `.restingRed` case: change `Image(systemName: "dog.fill")` to `Image(systemName: "pawprint.fill")`
- [x] 5.4 In the `.thinking` case: no `dog.fill` reference (this case uses `sparkles`) — verify and leave unchanged
- [x] 5.5 Build the project and visually confirm the menu bar icon changes from a dog silhouette to a paw print in all states

## 6. Replace App Icon with Paw Print Design

- [x] 6.1 Create a new 1024×1024 px paw print PNG following PawPal's `trayIcon.ts` geometry: one large circle (radius ≈ 32% of canvas) centered at (50%, 68%), three smaller toe circles (radius ≈ 11%) at approximately (23%, 18%), (50%, 11%), (77%, 18%), and one more toe at (12%, 41%) — or use any paw print that reads clearly as a paw
- [x] 6.2 Export the PNG at all required iOS/macOS icon sizes and replace `MalDaze/Assets.xcassets/AppIcon.appiconset/MalDazeMark.png` with the new 1024×1024 image (update `Contents.json` if the filename changes)
- [ ] 6.3 Build and confirm the app icon in the macOS Dock shows a paw print

## 7. Verification

- [ ] 7.1 Run the app and trigger each `PetDisplayMode` state; verify: (a) `.runningBlack` shows a looping idle GIF, (b) `.restingRed` shows a break-prompt/running GIF, (c) `.pausedWhiteOutline` shows the sleeping GIF, (d) `.thinking` shows a focus GIF
- [x] 7.2 Confirm no `dog.fill` references remain in `MenuBarDogLabel.swift` or `PetRenderer.swift` by running: `grep -n "dog.fill" MalDaze/MenuBarDogLabel.swift MalDaze/PetRenderer/PetRenderer.swift`
- [x] 7.3 Confirm `MalDazePet.imageset` no longer exists: `ls MalDaze/Assets.xcassets/ | grep MalDazePet` should return nothing
- [x] 7.4 Confirm all 12 GIF files are in the built `.app` bundle: `find MalDaze.app -name "*.gif" | wc -l` should return 12 (we have 13 including bonus focusGuard variant)
