# Touch Bar 常亮设置设计

## 目标

在菜单栏增加“播放时保持 Touch Bar/屏幕常亮”开关。开关默认关闭并持久保存；开启后，仅当酷狗正在播放时阻止显示器因空闲而自动变暗。暂停、停止、切换到其他播放器、关闭开关或退出应用时立即恢复系统默认电源行为。

## 方案选择

主屏幕使用 Apple 公开的 IOKit `kIOPMAssertionTypePreventUserIdleDisplaySleep`。真机验证发现该断言不影响 Touch Bar 独立的 HID 空闲计时，`DFRBrightnessClient turnOn` 也会被空闲控制立即覆盖。Quartz 合成鼠标活动虽会重置系统空闲时间，但 TouchBarServer 不把它视为真实 HID 活动。虚拟 HID 设备则要求 Apple 专用的 `com.apple.developer.hid.virtual.device` entitlement，普通第三方应用无法使用。因此最终只提供主屏幕常亮，并在菜单和 README 中明确 Touch Bar 的系统限制。

macOS 没有公开的“保持 Touch Bar 常亮”接口。菜单只承诺主屏幕常亮，README 同时说明 Touch Bar 会按系统策略熄灭以及耗电影响。

## 组件与数据流

- `KTLKeepAwakePolicy`：纯逻辑组件，根据用户偏好、是否为酷狗、是否播放决定是否持有断言，便于单元测试。
- `KTLAppDelegate`：读取和保存 `NSUserDefaults`，维护菜单项与 IOPM assertion 生命周期。
- `KTLTouchBarController`：不再模拟用户输入，也不再申请辅助功能权限。
- 播放状态每秒更新时重新计算策略，但只有目标状态变化时才创建或释放断言。
- 应用退出前无条件释放断言。

## 错误处理与验证

断言创建失败时安全降级并更新菜单提示，不影响歌词和播放控制。单元测试覆盖开启、暂停、非酷狗和关闭偏好；实际验证使用 `pmset -g assertions` 确认播放时存在断言。实体 Touch Bar 的熄灭行为由系统控制。
