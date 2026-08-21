# Kugou Touch Bar Lyrics

一个非官方的 macOS 菜单栏小工具：读取酷狗音乐正在播放的歌曲，在配备 Touch Bar 的 MacBook Pro 上显示逐句歌词，并提供上一曲、播放/暂停、下一曲按钮。

## 功能

- Touch Bar 显示当前一句歌词
- Touch Bar 空心细线图标快捷控制：上一曲、播放/暂停、下一曲
- 菜单栏显示当前歌曲与当前歌词
- 优先读取酷狗本地 KRC 歌词，离线也可使用已缓存歌词
- 本地无歌词时，尝试网易云音乐和 LRCLIB 的公开歌词接口
- 支持歌词时间偏移微调（菜单栏内 ±0.5 秒）
- 可选择在酷狗播放期间保持主屏幕常亮

## 系统要求

- **macOS 13 Ventura 或更高版本**。低于 macOS 13 的系统不能运行当前版本。
- **Apple 芯片（arm64）Mac**。当前发布包及随附的媒体控制组件均为 arm64，不支持 Intel Mac。
- **实体 Touch Bar**。没有 Touch Bar 的 Mac 可以启动菜单栏程序，但无法使用本项目的核心歌词与控制界面。
- **酷狗音乐 Mac 版**，并且酷狗需要能够向 macOS 发布“正在播放”信息。
- 在线搜索歌词时需要网络；已缓存的酷狗本地歌词不需要网络。

目前真实测试环境：MacBook Pro（M2，Mac14,7）、macOS 15.6.1、酷狗音乐 3.3.2。

其他 Apple 芯片 Touch Bar 机型及较新的 macOS 版本理论上可以运行，但尚未逐一进行真机测试。Touch Bar 使用了系统私有接口，未来的 macOS 更新可能改变其行为。

## 安装

1. 打开 `KugouTouchBarLyrics-0.2.5.dmg`。
2. 将“酷狗 Touch Bar 歌词”拖入“应用程序”。
3. 启动酷狗音乐并播放歌曲，再打开本应用。

### 是否需要允许“任何来源”

**不需要，也不建议开启“允许任何来源”。** 不需要关闭 SIP，不需要关闭 Gatekeeper，也不需要在终端执行全局解除安全检查的命令。

当前发布包采用临时签名，没有 Apple Developer ID 签名和 Apple 公证，因此首次启动可能被 Gatekeeper 拦截。请只为这个 App 添加一次例外：

1. 确认 App 来自本项目可信的 GitHub 仓库或 Release 页面，并已拖入“应用程序”。
2. 先正常打开一次；如果 macOS 阻止运行，关闭提示窗口。
3. 打开“系统设置 → 隐私与安全性”，向下滚动到“安全性”。
4. 找到被阻止的“酷狗 Touch Bar 歌词”，点击“仍要打开”，然后按系统提示确认。该按钮通常只会在尝试启动后的一段时间内出现。
5. 以后可以像普通 App 一样直接打开，无需重复操作。

也可以先在 Finder 中按住 Control 键点按 App，选择“打开”，再在确认窗口中选择“打开”。不同 macOS 版本显示的文字可能略有不同。Apple 官方说明见：[打开来自未知开发者的 Mac App](https://support.apple.com/zh-cn/guide/mac-help/-mh40616/mac)。

如果 Mac 由公司或学校管理，“仍要打开”可能被管理员策略禁用；这种情况下需要联系管理员。本应用本身不需要管理员权限、辅助功能权限或完全磁盘访问权限。

## 使用

Touch Bar 从左到右显示：

`上一曲 | 当前一句歌词 | 播放/暂停 | 下一曲`

三个播放控制按钮使用圆角空心细线图标：上一曲为 `|<`，下一曲为 `>|`；播放按钮会根据酷狗当前状态自动切换为空心播放三角或暂停双线。

这些图标由 Objective-C 使用 `NSBezierPath` 绘制为 22pt 矢量路径，再以 2x 分辨率渲染成白色非模板图片，放入 44pt 的原生 Touch Bar 按钮。使用非模板图片是为了避免系统模态 Touch Bar 将白色模板错误地重新着色为黑色。

菜单栏图标中可以查看当前歌曲、当前歌词，调整歌词时间偏移，或退出应用。切歌后程序会自动重新查找歌词。

“播放时保持主屏幕常亮”默认关闭。开启后，设置会被保存；只有酷狗正在播放时才阻止主屏幕因空闲休眠，暂停、退出酷狗或退出本应用后会自动恢复系统休眠行为。该功能使用 macOS 的电源断言，不需要辅助功能权限；开启会增加电池消耗。

Touch Bar 有独立于主屏幕的硬件空闲策略。macOS 没有向普通第三方应用开放“阻止 Touch Bar 空闲熄灭”的接口，因此本应用无法保证 Touch Bar 始终点亮。Touch Bar 熄灭后，触碰键盘或触控板即可恢复，歌词仍会继续同步。

## 从源码构建

先安装 Xcode Command Line Tools，然后在项目目录执行：

```sh
xcode-select --install
make release
```

生成文件：

- `dist/KugouTouchBarLyrics.app`
- `dist/KugouTouchBarLyrics-0.2.5.dmg`
- `dist/KugouTouchBarLyrics-0.2.5-app.zip`（适合放在 GitHub Release）

运行核心逻辑测试：

```sh
make test
```

项目使用 Objective-C、AppKit 和系统自带的 clang 构建，不需要 Python、CocoaPods 或其他包管理器。

## 工作方式与隐私

应用只在本机读取系统“正在播放”信息和酷狗本地歌词缓存。找不到本地歌词时，才会把歌曲名和歌手名发送给 `music.163.com` 与 `lrclib.net` 搜索歌词。应用不收集账户、播放历史或个人资料。

播放控制通过随应用打包的 `media-control` 工具发送给 macOS 当前媒体会话。第三方组件的许可证见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 已知限制

- Touch Bar 接口并非 Apple 面向第三方应用公开的正式 API，无法上架 Mac App Store，未来 macOS 更新可能导致失效。
- 当前没有 Apple Developer ID 签名与公证，直接下载时可能出现 Gatekeeper 警告。
- 尚未实现登录时自动启动、图形化设置窗口和歌词偏移持久保存。
- macOS 的 Touch Bar 空闲熄灭由系统服务和真实 HID 活动控制；普通第三方应用无法可靠阻止，主屏幕常亮设置不会改变这一行为。
- 播放按钮控制的是 macOS 当前媒体会话；若其他播放器抢占会话，控制对象可能不是酷狗。
- 在线歌词来自第三方公开接口，接口变化、网络异常或歌曲信息不一致时可能找不到歌词。
- 目前只在一台 Touch Bar Mac 和酷狗音乐 3.3.2 上完成真实播放验证；没有 Touch Bar UI 自动化测试。
- 当前打包的媒体控制组件只有 arm64 版本，因此此发布包不支持 Intel Mac。
- 当前仍使用系统默认应用图标。

## 项目结构

```text
Sources/App       菜单栏与 Touch Bar 界面
Sources/Media     正在播放信息与媒体控制
Sources/Lyrics    KRC 解码、本地查找与在线回退
Sources/Core      LRC 时间轴、歌曲模型与缓存
Tests             核心逻辑测试
Vendor            随应用分发的第三方媒体控制组件
scripts           App 与 DMG 打包脚本
```

## 许可证与声明

本项目源码采用 MIT License，见 [LICENSE](LICENSE)。`media-control` 及其 `mediaremote-adapter` 依照 BSD 3-Clause License 分发，见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

本项目与酷狗音乐及其运营方没有隶属、授权或背书关系。“酷狗音乐”及相关商标归其权利人所有。歌词版权归原作者及相应权利人所有，本工具只展示酷狗客户端已缓存或第三方服务返回的歌词，不随仓库分发歌词内容。
