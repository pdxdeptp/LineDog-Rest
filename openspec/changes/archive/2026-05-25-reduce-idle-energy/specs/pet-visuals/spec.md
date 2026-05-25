## ADDED Requirements

### Requirement: GIF 帧解码缓存
`PetRenderer` SHALL reuse decoded GIF frames for bundled pet GIF URLs when rendering static first frames or intermediate animation intensity.

#### Scenario: 静止路径复用解码结果
- **WHEN** animationIntensity <= 0.001 and the same GIF URL is displayed more than once
- **THEN** `PetRenderer` SHALL reuse previously decoded frames when available
- **AND** it SHALL NOT re-read and re-decode the GIF from disk for each display refresh

#### Scenario: 中间强度路径复用解码结果
- **WHEN** animationIntensity is greater than 0.001 and less than 0.999 and the same GIF URL is displayed more than once
- **THEN** `PetRenderer` SHALL reuse cached frames for manual playback when available
- **AND** manual playback SHALL still honor the current animation intensity when scheduling frame delays

#### Scenario: GIF fallback remains available
- **WHEN** GIF data cannot be decoded or cached frames are unavailable
- **THEN** `PetRenderer` SHALL continue using the existing SF Symbol fallback behavior
