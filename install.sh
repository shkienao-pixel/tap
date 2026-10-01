#!/bin/sh
set -eu
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
config_dir="${TAP_CONFIG_DIR:-$HOME/.hammerspoon}"
backup_dir="$config_dir/tap-backup-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$config_dir" "$backup_dir"
for file in init.lua tap-ui.lua tap-ui.html tap-shortcuts.lua tap-compat.lua; do
    if [ -e "$config_dir/$file" ] || [ -L "$config_dir/$file" ]; then
        cp -p "$config_dir/$file" "$backup_dir/$file"
    fi
    cp "$source_dir/$file" "$config_dir/$file"
done
printf 'Tap 已安装到 %s\n原配置备份在 %s\n打开 Hammerspoon 并重新加载配置。\n' "$config_dir" "$backup_dir"
