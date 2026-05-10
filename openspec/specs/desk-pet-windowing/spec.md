# desk-pet-windowing Specification

## Purpose

MalDaze 桌宠由 `WindowManager` 管理为一个常态透明小窗，并在休息时复用同一窗口扩展为休息显示。该规格记录常态窗口、位置持久化、多屏对齐和鼠标穿透行为。

## Requirements

### Requirement: 常态透明小窗
系统 SHALL 在应用启动后安装桌宠 `NSWindow`，常态下窗口只覆盖桌宠图标周围区域。

#### Scenario: 安装窗口
- **WHEN** 应用完成启动或下一拍 main queue 执行安装逻辑
- **THEN** `WindowManager` 创建桌宠窗口
- **AND** 窗口 identifier 为 `com.maldaze.deskPetStage`
- **AND** 内容视图为 `PetStageView`

#### Scenario: 默认位置
- **WHEN** 没有持久化位置
- **THEN** 常态桌宠窗口默认位于菜单栏屏幕可见区右下角

#### Scenario: 常态窗口尺寸
- **WHEN** 常态桌宠窗口计算尺寸
- **THEN** 窗口边长等于用户配置图标边长加上单侧 15 点留白的两倍

### Requirement: 位置持久化
系统 SHALL 在常态桌宠拖动后保存窗口位置。

#### Scenario: 拖动窗口
- **WHEN** 用户在常态桌宠命中区按下并拖动超过阈值
- **THEN** 系统移动桌宠窗口

#### Scenario: 保存位置
- **WHEN** 常态桌宠拖动结束或应用退出
- **THEN** 系统保存 idle pet 窗口 origin

#### Scenario: 加载位置
- **WHEN** 下次安装桌宠窗口
- **THEN** 系统优先使用已保存的 origin
- **AND** 使用当前图标边长计算窗口大小

### Requirement: 多屏对齐
系统 SHALL 在屏幕配置变化时将桌宠窗口保持在可见屏幕内。

#### Scenario: 屏幕参数变化
- **WHEN** `NSApplication.didChangeScreenParametersNotification` 触发
- **THEN** 系统防抖后重新定位桌宠窗口

#### Scenario: 主显示器变化
- **WHEN** 活跃显示器变化通知触发
- **THEN** 系统重新定位桌宠窗口

#### Scenario: 常态窗口对齐
- **WHEN** 当前桌宠为常态小窗
- **THEN** 系统将现有窗口 frame clamp 到可见屏幕范围内

#### Scenario: 休息窗口对齐
- **WHEN** 当前桌宠处于全屏休息阶段
- **THEN** 系统将窗口 frame 设为菜单栏屏幕全屏 frame

### Requirement: 鼠标穿透
系统 SHALL 避免常态透明窗口区域吞掉桌面点击。

#### Scenario: 未绑定 ViewModel
- **WHEN** 桌宠菜单 ViewModel 未绑定
- **THEN** 桌宠窗口忽略鼠标事件

#### Scenario: 常态命中区外
- **WHEN** 桌宠在常态且鼠标不在宠物屏幕命中区内
- **THEN** 桌宠窗口设置 `ignoresMouseEvents=true`

#### Scenario: 常态命中区内
- **WHEN** 桌宠在常态且鼠标位于宠物屏幕命中区内
- **THEN** 桌宠窗口接收鼠标事件

#### Scenario: 命中区计算
- **WHEN** `PetStageView` 布局常态宠物
- **THEN** 命中区使用图像布局边长的 60%

### Requirement: 图标边长设置
系统 SHALL 支持用户调整常态桌宠图标绘制边长。

#### Scenario: 边长范围
- **WHEN** 系统读取 `idlePetIconSidePoints`
- **THEN** 数值被 clamp 到 72...180
- **AND** 未写入或为 0 时默认 120

#### Scenario: 应用边长
- **WHEN** 用户提交新的桌宠图标边长
- **THEN** 系统调整 PetStageView 的目标图标边长
- **AND** 按窗口中心缩放常态小窗
- **AND** 保存新的窗口 frame

#### Scenario: 休息或跑屏中
- **WHEN** 用户设置图标边长但桌宠正在休息或跑屏
- **THEN** 系统不立即改变当前休息或跑屏窗口尺寸

### Requirement: 桌宠归位
系统 SHALL 提供将常态桌宠移回默认角落的能力。

#### Scenario: 用户归位
- **WHEN** 用户点击“桌宠归位”或触发对应全局快捷键
- **THEN** 系统将常态桌宠窗口移动到菜单栏屏幕可见区右下角
- **AND** 保存该位置

#### Scenario: 休息中归位
- **WHEN** 桌宠处于全屏休息阶段
- **THEN** 归位操作不改变窗口
