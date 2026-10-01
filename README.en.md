<p align="center">
  <img src="assets/tap-icon.svg" width="88" height="88" alt="Tap icon">
</p>

# Tap

[简体中文](README.md) · [English](README.en.md)

Make a Windows keyboard feel more familiar on a Mac. Tap adds Shift-based Chinese/English input switching, native Alt + Tab, and optional Windows-style shortcuts.

Tap is an open-source configuration for [Hammerspoon](https://www.hammerspoon.org/). **Hammerspoon is required to run it.** This repository contains source code, a settings panel, and an installer—not a standalone `.app`.

![Tap settings panel](assets/tap.jpg)

## Features and defaults

| Feature | Action | First-run default |
| --- | --- | --- |
| Chinese/English input switching | Tap and release Shift | On |
| Application switching | Alt + Tab; Alt + Shift + Tab to reverse | On |
| Master switch | Enable or pause Tap shortcuts | On |
| Launch at login | Start Hammerspoon and Tap after login | On |
| Additional shortcuts | Choose individually in “More” | **All off** |

Preferences are stored locally. Reloading or updating the files preserves previously saved options.

- Alt + Tab uses the **native macOS application switcher**. It switches applications, not individual windows within the same application.
- Shift switches input when released, without an added delay. Holding it for more than 0.5 seconds, typing another key, or using another modifier cancels the input switch. Shift combinations continue to work.
- The translucent panel has two groups: individual shortcuts and “More” at the top, and the master switch and login startup below.
- The panel and shortcuts run locally. No web server or online account is required.

## Installation

### 1. Set up Hammerspoon and input sources

1. Install and run Hammerspoon from its [official website](https://www.hammerspoon.org/).
2. Allow Hammerspoon under macOS **System Settings → Privacy & Security → Accessibility**.
3. Add **ABC** and **Apple Simplified Chinese Pinyin** in the macOS keyboard input source settings. Shift switching currently targets these two Apple input sources; third-party input methods are not configured.

### 2. Install the Tap configuration

Download and extract the repository ZIP, or clone the repository with Git. From the directory containing `install.sh`, run:

```sh
sh install.sh
```

The installer copies these five files into `~/.hammerspoon/`:

```text
init.lua
tap-ui.lua
tap-ui.html
tap-shortcuts.lua
tap-compat.lua
```

**Installation replaces existing files with the same names, including `init.lua`.** The installer backs them up first under `~/.hammerspoon/tap-backup-<timestamp>-<process-id>/` and prints the full backup path. If you already use Hammerspoon, review the source and merge it manually as needed to preserve your existing setup.

### 3. Load and open Tap

Reload the configuration in Hammerspoon, then click the **window + T** menu bar icon to open Tap.

With a standard installation, the application and its Accessibility permission entry are still named **Hammerspoon**. Tap’s login startup switch controls Hammerspoon’s launch-at-login setting. It is enabled on first load and can be turned off in the panel.

## Windows keyboard and mouse setup

These settings are managed by macOS. The installer does not change them automatically.

### Ctrl, the Windows key, and copy/paste

Under macOS **System Settings → Keyboard → Keyboard Shortcuts → Modifier Keys**, select your **external Windows keyboard** and swap **Control and Command**.

| Physical key | Key received by macOS after the swap |
| --- | --- |
| Ctrl | Command ⌘ |
| Windows | Control ⌃ |
| Alt | Option ⌥, with its existing setting retained |

Ctrl + C / V / X / A / Z / S / F can then use each application’s existing Command shortcuts. This comes from the system modifier setting; **Tap does not intercept these shortcuts individually**. Tap’s optional Ctrl and Windows-key mappings also assume this swap. Without it, different physical keys will trigger them.

### Caps Lock and scrolling

- **Caps Lock:** If it still switches input sources, disable the macOS input setting that uses Caps Lock to switch between Chinese and English, so Caps Lock retains its normal capitalization behavior.
- **Mouse wheel:** Turn off **Natural scrolling** in macOS mouse settings if you prefer the Windows scrolling direction.

Pausing or quitting Tap does not undo these system settings.

## Additional shortcuts: all off by default

Open “More” in the settings panel and enable only the options you want. The table below names **physical Windows keyboard keys** and assumes Control and Command have been swapped.

| Feature | Shortcut | Behavior and scope |
| --- | --- | --- |
| Move or select by word | Ctrl + ← / →; add Shift to select | Recognized editable text controls only |
| Delete by word | Ctrl + Backspace / Delete | Delete the previous/next word; editable text controls only |
| Line and document navigation | Home / End; Ctrl + Home / End; optionally add Shift | Move to line or document boundaries; editable text controls only |
| Redo | Ctrl + Y | Send Command + Shift + Z; editable text controls only |
| Switch browser tabs | Ctrl + Tab; add Shift to reverse | Supported browsers only |
| Close a window | Alt + F4 | Send Command + W; tabbed apps may close the current tab. Does not force the app to quit |
| Rename a file | F2 | Finder only; passes through while editing the name |
| Screenshot to clipboard | Win + Shift + S; Print Screen | Use the system region/full-screen screenshot shortcuts and copy the result to the clipboard |

The browser scope includes the configured application identifiers for Safari, Chrome, Edge, Firefox, Brave, Arc, Vivaldi, and Opera.

Text-editing mappings exclude Finder and the configured terminal applications: Terminal, iTerm2, Ghostty, Warp, Alacritty, and kitty. Some applications do not expose recognizable editable controls, so these mappings may not apply. Print Screen currently requires the keyboard to send **F13** to macOS; some keyboards need additional configuration. F2/F4 must also be sent as function keys, which may require Fn on some keyboards.

## Panel controls

| Action | Result |
| --- | --- |
| Click the menu bar icon | Open the panel; click again to hide it |
| Option-click the icon, using Alt on a Windows keyboard | Open the maintenance menu: reload, developer console, quit, and other actions |
| Esc | Return from “More”; hide the panel on the main page |
| Close or hide the panel | Keep shortcuts running in the background |
| Turn off the master switch | Pause Tap’s shortcut listeners while retaining selected options and system keyboard settings |

The settings interface currently uses Chinese. This English README documents its controls and behavior.

## Troubleshooting

**Shift does not switch input:** Make sure ABC and Apple Simplified Chinese Pinyin are added, and both the Shift and master switches are on. Tap and release Shift instead of holding it down.

**All shortcuts stop working:** Check that Hammerspoon is running, Accessibility permission is enabled, and Tap’s master switch is on. macOS Secure Input may suspend keyboard listening during password entry; try again after leaving the password field.

**Ctrl + C / V behave unexpectedly:** Select the correct external keyboard in Modifier Keys and swap Control and Command. Built-in keyboards and other external keyboards may have separate settings.

**Updating:** Download the new version, run `sh install.sh` again, and reload the configuration. The installer makes a new backup of matching files, while saved Tap preferences are retained locally.

**Restoring your previous configuration:** If desired, disable login startup in the panel first, then quit Hammerspoon. Copy files from the installation backup back into `~/.hammerspoon/`; manually remove Tap files that did not exist before installation. Restart Hammerspoon and reload the restored configuration. Restore modifier keys, Caps Lock, and mouse preferences separately in macOS settings.

## Source and validation

| File | Purpose |
| --- | --- |
| `init.lua` | Shift switching, native Alt + Tab, menu bar entry, and listener recovery |
| `tap-ui.lua` | Local settings window, preference bridge, and window controls |
| `tap-ui.html` | Translucent settings interface |
| `tap-shortcuts.lua` | Optional shortcut rules and application scope |
| `tap-compat.lua` | Optional keyboard event handling and preference storage |
| `install.sh` | Back up matching files and install the configuration |
| `tests/compat.lua` | Mock tests for optional shortcuts |

With Lua 5.3 or 5.4 installed, run from the repository root:

```sh
lua tests/compat.lua .
```

The current suite contains **96 compatibility checks**. It uses mock events and settings, without changing live preferences or sending real keystrokes. It does not replace testing with actual keyboards, input methods, and applications.

## License

Tap’s configuration source is licensed under the [MIT License](LICENSE). [Hammerspoon](https://github.com/Hammerspoon/hammerspoon) is a separate project with its own license.
