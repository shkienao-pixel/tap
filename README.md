<p align="center">
  <img src="assets/tap-icon.svg" width="88" height="88" alt="Tap icon">
</p>

# Tap

[简体中文](README.md) · [English](README.en.md)

让 Windows 键盘在 Mac 上更顺手。Tap 提供 Shift 中英文切换、原生 Alt + Tab，以及可按需开启的 Windows 快捷键。

Tap 是基于 [Hammerspoon](https://www.hammerspoon.org/) 的开源配置项目，**需要 Hammerspoon 才能运行**。仓库包含源码、设置面板和安装脚本，不包含独立 `.app`。

![Tap 设置面板](assets/tap.jpg)

## 功能与默认状态

| 功能 | 操作 | 首次使用时 |
| --- | --- | --- |
| 中英文切换 | 轻按并松开 Shift | 开启 |
| 应用切换 | Alt + Tab；Alt + Shift + Tab 反向 | 开启 |
| 总开关 | 启用／暂停 Tap 快捷键 | 开启 |
| 登录自动启动 | 登录后启动 Hammerspoon 和 Tap | 开启 |
| 更多快捷键 | 在「更多」中逐项选择 | **全部关闭** |

设置会保存在本机；重新加载或更新文件不会重置已有选项。

- Alt + Tab 显示 **macOS 原生应用切换界面**，切换的是应用，不是同一应用内的每个窗口。
- Shift 在松开时立即切换；按住超过 0.5 秒、输入字符或使用其他修饰键时不会触发。Shift 组合键继续正常使用。
- 半透明设置面板分为两个模块：上方是具体快捷键和「更多」，下方是总开关和登录自动启动。
- 设置面板与快捷键都在本机运行，不需要网页服务器或在线账号。

## 安装

### 1. 准备 Hammerspoon 和输入法

1. 从 [Hammerspoon 官网](https://www.hammerspoon.org/) 安装并运行 Hammerspoon。
2. 在 macOS「系统设置 → 隐私与安全性 → 辅助功能」中允许 Hammerspoon。
3. 在 macOS 键盘输入法设置中添加 **ABC** 和 **简体拼音**。当前 Shift 切换固定使用这两种 Apple 输入法，第三方输入法暂未适配。

### 2. 安装 Tap 配置

下载仓库 ZIP 并解压，或使用 Git 克隆仓库。进入包含 `install.sh` 的目录，运行：

```sh
sh install.sh
```

脚本会把以下五个文件复制到 `~/.hammerspoon/`：

```text
init.lua
tap-ui.lua
tap-ui.html
tap-shortcuts.lua
tap-compat.lua
```

**安装会替换已有的同名文件，包括 `init.lua`。** 脚本会先备份它们，备份位于 `~/.hammerspoon/tap-backup-<时间>-<进程号>/`，完整路径会显示在安装输出中。若你已有 Hammerspoon 配置，先检查源码并按需手动合并，避免覆盖自己的功能。

### 3. 加载与打开

在 Hammerspoon 中重新加载配置，然后点击菜单栏的 **窗口＋T** 图标打开 Tap。

正常安装后，macOS 的应用名称与辅助功能权限项仍是 **Hammerspoon**。Tap 的「登录时自动启动」控制的是 Hammerspoon 的登录启动；首次加载默认启用，也可在面板中关闭。

## Windows 键盘与鼠标设置

这部分由 macOS 管理，安装脚本不会自动修改。

### Ctrl、Windows 键与复制粘贴

在 macOS「系统设置 → 键盘 → 键盘快捷键 → 修饰键」中，选中你的 **外接 Windows 键盘**，将 **Control 与 Command 互换**。

| 物理按键 | 互换后 macOS 收到的按键 |
| --- | --- |
| Ctrl | Command ⌘ |
| Windows | Control ⌃ |
| Alt | Option ⌥（保持原设置） |

这样 Ctrl + C / V / X / A / Z / S / F 等就会调用应用原有的 Command 快捷键。它们由系统的修饰键设置实现，**不是 Tap 单独拦截的功能**。Tap 的可选 Ctrl 与 Windows 键映射也按这一设置设计；未互换时，触发它们的物理按键会不同。

### Caps Lock 与滚轮

- **Caps Lock**：如果它仍切换输入法，在 macOS 输入法设置中关闭「使用 Caps Lock 键切换中英文」，保留大小写功能。
- **鼠标滚轮**：如需 Windows 的滚动方向，在 macOS 鼠标设置中关闭「自然滚动」。

暂停或退出 Tap 不会撤销以上系统设置。

## 更多快捷键：默认全部关闭

打开设置面板中的「更多」，单独开启需要的选项。下表按 **物理 Windows 键盘** 标注，并假定已互换 Control 与 Command。

| 功能 | 按键 | 行为与范围 |
| --- | --- | --- |
| 按词移动与选择 | Ctrl + ← / →；加 Shift 选择 | 仅识别到的可编辑文本控件 |
| 按词删除 | Ctrl + Backspace / Delete | 向前／向后删除一个词；仅可编辑文本控件 |
| 行首与行尾 | Home / End；Ctrl + Home / End；可加 Shift | 跳到行首尾或文档首尾；仅可编辑文本控件 |
| 重做 | Ctrl + Y | 调用 Command + Shift + Z；仅可编辑文本控件 |
| 切换标签页 | Ctrl + Tab；加 Shift 反向 | 仅支持的浏览器 |
| 关闭窗口 | Alt + F4 | 调用 Command + W；有标签页的应用可能关闭当前标签页，不会强制退出应用 |
| 文件重命名 | F2 | 仅访达；正在编辑名称时不拦截 |
| 截图到剪贴板 | Win + Shift + S；Print Screen | 分别调用系统选区截图／全屏截图，并复制到剪贴板 |

浏览器范围包括 Safari、Chrome、Edge、Firefox、Brave、Arc、Vivaldi 和 Opera 的对应应用标识。

文字编辑映射会避开访达以及配置中列出的 Terminal、iTerm2、Ghostty、Warp、Alacritty 和 kitty。部分应用不提供可识别的可编辑控件，因此这些映射可能不生效。Print Screen 目前要求键盘向 macOS 发送 **F13**，不同键盘可能需要额外设置；F2／F4 也需实际发送功能键，部分键盘须配合 Fn。

## 面板操作

| 操作 | 结果 |
| --- | --- |
| 单击菜单栏图标 | 打开面板；再次点击收起 |
| Option（Windows 键盘上的 Alt）＋点击图标 | 显示维护菜单：重新加载、开发控制台、退出等 |
| Esc | 在「更多」页返回；在首页收起 |
| 关闭或收起面板 | 快捷键继续在后台运行 |
| 关闭「启用快捷键」 | 暂停 Tap 的快捷键监听，保留已选功能与系统键盘设置 |

当前设置界面使用中文；英文版本的使用说明见 [English README](README.en.md)。

## 常见问题

**Shift 切换没有反应**：确认已添加 ABC 和 Apple 简体拼音，且 Shift 开关、总开关都已打开。轻按并松开 Shift，而不是持续按住。

**快捷键全部失效**：检查 Hammerspoon 是否运行、辅助功能权限是否开启、Tap 总开关是否开启。密码输入期间，macOS 的安全输入机制可能暂停键盘监听；退出密码输入后再试。

**Ctrl + C / V 不对**：确认在修饰键设置中选中了正确的外接键盘，并互换 Control 与 Command。内置键盘与其他外接键盘可能有独立设置。

**如何更新**：下载新版本，再运行 `sh install.sh` 并重新加载。安装会重新备份同名文件，本机已保存的 Tap 选项仍保留。

**如何恢复原配置**：先在面板中按需关闭登录自动启动，再退出 Hammerspoon。将安装时备份目录中的文件复制回 `~/.hammerspoon/`；对安装前不存在的 Tap 文件，可手动移除。重新运行 Hammerspoon 并加载恢复后的配置。系统修饰键、Caps Lock 与鼠标设置需在 macOS 设置中另行还原。

## 源码与验证

| 文件 | 用途 |
| --- | --- |
| `init.lua` | Shift、原生 Alt + Tab、菜单栏入口与监听恢复 |
| `tap-ui.lua` | 本机设置窗口、开关通信与窗口操作 |
| `tap-ui.html` | 半透明设置界面 |
| `tap-shortcuts.lua` | 可选快捷键规则与应用范围 |
| `tap-compat.lua` | 可选快捷键事件处理与设置保存 |
| `install.sh` | 备份同名配置并安装 |
| `tests/compat.lua` | 可选快捷键的模拟测试 |

使用 Lua 5.3 或 5.4，在仓库根目录运行：

```sh
lua tests/compat.lua .
```

当前包含 **96 项兼容性检查**。测试使用模拟事件和设置，不会改变本机选项或发送真实按键；它不替代实际键盘、输入法和应用的兼容性验证。

## 许可

Tap 配置源码采用 [MIT 许可](LICENSE)。[Hammerspoon](https://github.com/Hammerspoon/hammerspoon) 是独立项目，遵循其自身许可。
