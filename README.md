<p align="center">
  <img src="assets/tap-icon.svg" width="88" height="88" alt="Tap icon">
</p>

# Tap

[简体中文](README.md) · [English](README.en.md)

把熟悉的 Windows 按键带到 Mac 上。**Tap 现在是独立的 macOS 应用**：下载一个 `Tap.app`，无需安装 Hammerspoon、Lua 或复制配置脚本。

![Tap 设置面板](assets/tap.jpg)

## 下载与使用

[下载独立版 Tap（Apple Silicon + Intel）](https://github.com/shkienao-pixel/tap/releases/download/v0.2.0-beta.1/Tap-macOS.zip) · [查看发布说明](https://github.com/shkienao-pixel/tap/releases/tag/v0.2.0-beta.1)

1. 下载并解压 `Tap-macOS.zip`，将 **Tap.app** 拖到「应用程序」。
2. 打开 Tap，点击「开启辅助功能」，在 macOS「系统设置 → 隐私与安全性 → 辅助功能」中允许 **Tap**。
3. 点击菜单栏的窗口＋T 图标打开设置，按需启用功能。

最低系统要求：**macOS 13**。发行包为通用二进制，包含 Apple Silicon 与 Intel 架构。

当前为 **0.2.0-beta.1 测试版**，应用使用本地签名，尚未完成 Apple Developer ID 签名与公证。下载的应用可能受到 macOS 安全检查限制；需要完整签名分发的用户请等正式版，也可以按下文从源码构建。本次已验证 Apple Silicon 上的启动和界面；真实按键与 Intel 运行仍需要授权后的设备测试。

## 功能

| 功能 | 按键／操作 | 新安装的默认状态 |
| --- | --- | --- |
| Ctrl 快捷键 | Ctrl + C / V / X / A / Z / S / F 等 | 开启 |
| 中英文切换 | 轻按并松开 Shift | 开启 |
| 原生应用切换 | Alt + Tab；加 Shift 反向 | 开启 |
| 总开关 | 暂停／启用 Tap 快捷键 | 开启 |
| 登录自动启动 | 登录后启动 Tap | **关闭** |
| 更多快捷键 | 在「更多」中逐项启用 | **全部关闭** |

- Alt + Tab 显示 **macOS 原生应用切换器**，切换应用，不逐个列出同一应用的窗口。
- Shift 松开时切换输入法，不增加等待；按住超过 0.5 秒、输入其他字符或使用其他修饰键会取消切换。
- 背景使用 macOS 原生毛玻璃；具体快捷键与「更多」位于上方模块，总开关和登录启动位于下方。
- 设置和按键处理全部在本机完成，不记录输入内容，不需要在线账号或网页服务器。

## 键盘模式与输入法

### Ctrl 适配已经包含在应用内

在「更多 → 键盘修饰键」选择：

| 模式 | 适用情况 |
| --- | --- |
| 由 Tap 适配 | Windows 键盘使用 macOS 默认修饰键设置；Tap 将 Ctrl / Windows 键对应的 Control / Command 事件互换 |
| 系统已交换 | 之前已在 macOS 中交换 Control / Command；Tap 保留系统结果，避免重复交换 |

首次启动会检查本机保存的修饰键映射，并尝试选择对应模式。有多把键盘、不同键盘配置不同的用户，应手动核对模式。当前适配作用于系统键盘事件，**不按单独设备区分**；Mac 键盘用户可关闭「Ctrl 快捷键」。

「更多」中的 Ctrl 和 Windows 快捷键，都按 Windows 键盘经上述模式适配后的结果设计。关闭 Ctrl 适配不会还原 macOS 已设置的修饰键映射。

### 中英文、Caps Lock 与鼠标

- Shift 切换固定使用 Apple **ABC** 与 **简体拼音**，请先在 macOS 输入法设置中添加这两种输入法。第三方输入法暂未适配。
- 如需 Caps Lock 只控制大小写，在 macOS 输入法设置中关闭 Caps Lock 中英文切换。
- 如需 Windows 鼠标滚轮方向，在 macOS 鼠标设置中关闭「自然滚动」。

Caps Lock 和鼠标偏好由系统管理，Tap 不自动修改它们。

## 更多快捷键：按需开启

| 功能 | 物理 Windows 按键 | 行为与范围 |
| --- | --- | --- |
| 按词移动与选择 | Ctrl + ← / →；加 Shift 选择 | 可识别的可编辑文本控件 |
| 按词删除 | Ctrl + Backspace / Delete | 删除前／后一个词；仅可编辑文本控件 |
| 行首与行尾 | Home / End；Ctrl + Home / End；可加 Shift | 跳行或文档首尾；仅可编辑文本控件 |
| 重做 | Ctrl + Y | Command + Shift + Z；仅可编辑文本控件 |
| 浏览器标签页切换 | Ctrl + Tab；加 Shift 反向 | 支持的浏览器 |
| 关闭窗口 | Alt + F4 | Command + W；标签页应用可能只关闭当前标签页，不强制退出 |
| 文件重命名 | F2 | 仅访达，编辑名称时不拦截 |
| 截图到剪贴板 | Win + Shift + S；Print Screen | 系统选区／全屏截图到剪贴板 |

支持的浏览器标识包括 Safari、Chrome、Edge、Firefox、Brave、Arc、Vivaldi 和 Opera。文字编辑映射避开访达以及 Terminal、iTerm2、Ghostty、Warp、Alacritty 和 kitty。

Print Screen 目前需发送 **F13**；F2 / F4 也需实际发送功能键，部分键盘要配合 Fn。应用未暴露可识别的可编辑控件时，文字映射不会生效。密码安全输入期间暂停适配。

## 操作与迁移

- **单击菜单栏图标**：打开面板；再点一次收起。
- **右键或 Option（Alt）＋点击图标**：显示重新连接和退出菜单。
- **Esc**：在「更多」页返回，在首页收起。
- **关闭／收起面板**：继续在后台运行；总开关才暂停快捷键。
- **登录启动**：把 Tap 放到「应用程序」后启用；macOS 若要求批准，请在登录项设置中完成。

从旧版迁移时，先退出旧的 Hammerspoon / Tap 配置版，避免两个键盘监听同时工作。独立版使用自己的设置存储，不读取旧版开关。已设置过系统修饰键映射的用户选择「系统已交换」。旧版源码保留在 [Git 历史](https://github.com/shkienao-pixel/tap/tree/fe46fcf239dc525829d8533e6f4bf59b4e4a63ed)，新版只维护一套 Swift 应用源码。

当前设置界面为中文，[英文 README](README.en.md) 提供完整使用说明。

## 从源码构建

需要 macOS 和带 Swift 工具链的 Xcode 或 Command Line Tools。

```sh
# 在仓库根目录运行测试
swift test

# 构建当前 Mac 架构的应用和 ZIP
sh Scripts/build-app.sh

# 构建 Apple Silicon + Intel 通用应用
TAP_UNIVERSAL=1 sh Scripts/build-app.sh
```

输出为 `dist/Tap.app` 和 `dist/Tap-macOS.zip`。构建默认使用本地签名；如有开发者证书，可通过 `TAP_SIGN_IDENTITY` 指定签名身份，公证需另行完成。

| 源码 | 用途 |
| --- | --- |
| `Sources/ShortcutCore/ShortcutEngine.swift` | 可测试的按键规则、Shift / Alt + Tab 状态、可选映射 |
| `Sources/Tap/main.swift` | macOS 键盘监听、输入法、权限、菜单栏、毛玻璃窗口与登录启动 |
| `Sources/Tap/Resources/panel.html` | 随应用打包的设置界面，不需用户单独安装 |
| `Tests/ShortcutCoreTests/` | 模拟事件测试，不发送真实按键或更改本机选项 |
| `Scripts/` | 应用打包与图标生成 |

测试覆盖短按 Shift、组合键保留、Ctrl 映射、系统已交换模式、原生 Alt + Tab、可选映射范围、安全输入及松键释放。真实设备与应用兼容性仍需实际验证。

## 许可

[MIT 许可](LICENSE)。Tap 使用 macOS 系统框架，不捆绑 Hammerspoon 或第三方运行时。
