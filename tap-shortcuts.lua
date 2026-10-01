-- Pure shortcut rules. Ctrl/Command are already swapped by macOS for the ROG keyboard.
local M = {}
M.definitions = {
    {id = "wordNavigation", title = "按词移动与选择", detail = "Ctrl + ← / → · Shift 选择", category = "文字编辑"},
    {id = "wordDelete", title = "按词删除", detail = "Ctrl + Backspace / Delete", category = "文字编辑"},
    {id = "lineNavigation", title = "行首与行尾", detail = "Home / End · Ctrl 跳文档首尾 · Shift 选择", category = "文字编辑"},
    {id = "redo", title = "重做", detail = "Ctrl + Y", category = "文字编辑"},
    {id = "browserTabs", title = "切换标签页", detail = "Ctrl + Tab · Shift 反向 · 仅浏览器", category = "应用与文件"},
    {id = "closeWindow", title = "关闭窗口", detail = "Alt + F4", category = "应用与文件"},
    {id = "finderRename", title = "文件重命名", detail = "F2 · 仅访达", category = "应用与文件"},
    {id = "screenshots", title = "截图到剪贴板", detail = "Win + Shift + S 选区 · Print Screen 全屏", category = "截图"},
}
M.browsers = {
    ["com.apple.Safari"] = true, ["com.google.Chrome"] = true,
    ["com.microsoft.edgemac"] = true, ["org.mozilla.firefox"] = true,
    ["com.brave.Browser"] = true, ["company.thebrowser.Browser"] = true,
    ["com.vivaldi.Vivaldi"] = true, ["com.operasoftware.Opera"] = true,
}
M.terminals = {
    ["com.apple.Terminal"] = true, ["com.googlecode.iterm2"] = true,
    ["com.mitchellh.ghostty"] = true, ["dev.warp.Warp-Stable"] = true,
    ["org.alacritty"] = true, ["net.kovidgoyal.kitty"] = true,
}
function M.defaults(saved)
    local options = {}
    for _, item in ipairs(M.definitions) do options[item.id] = type(saved) == "table" and saved[item.id] == true or false end
    return options
end
function M.any(options)
    for _, item in ipairs(M.definitions) do if options[item.id] then return true end end
    return false
end
function M.textCandidate(key, flags, options)
    if flags.alt or flags.ctrl then return false end
    return (options.lineNavigation and (key == "home" or key == "end"))
        or (flags.cmd and ((options.wordNavigation and (key == "left" or key == "right"))
        or (options.wordDelete and (key == "delete" or key == "forwarddelete"))
        or (options.redo and key == "y"))) or false
end
local function plan(key, flags, repeatable)
    return {key = key, flags = flags, repeatable = repeatable ~= false}
end
function M.resolve(key, f, context, o)
    if context.secureInput or context.nativeTabActive then return nil end
    local plain = not f.cmd and not f.ctrl and not f.alt
    local command = f.cmd and not f.ctrl and not f.alt
    if o.browserTabs and M.browsers[context.bundle] and key == "tab" and command and not f.fn then
        return plan("tab", {ctrl = true, shift = f.shift or nil})
    end
    if o.closeWindow and key == "f4" and f.alt and not f.cmd and not f.ctrl and not f.shift then
        return plan("w", {cmd = true}, false)
    end
    if o.finderRename and context.bundle == "com.apple.finder" and not context.editable
        and key == "f2" and plain and not f.shift then
        return plan("return", {}, false)
    end
    if o.screenshots then
        -- Physical Win arrives as Control after the system modifier swap.
        if key == "s" and f.ctrl and f.shift and not f.cmd and not f.alt and not f.fn then
            return plan("4", {cmd = true, ctrl = true, shift = true}, false)
        elseif key == "f13" and plain and not f.shift then
            return plan("3", {cmd = true, ctrl = true, shift = true}, false)
        end
    end
    -- Leave terminal shortcuts and non-editable views alone.
    if not context.editable or M.terminals[context.bundle] or context.bundle == "com.apple.finder" then return nil end
    local selection = f.shift or nil
    if o.lineNavigation and (key == "home" or key == "end") and (plain or command) then
        local target = command and (key == "home" and "up" or "down") or (key == "home" and "left" or "right")
        return plan(target, {cmd = true, shift = selection})
    end
    if not command then return nil end
    if o.wordNavigation and (key == "left" or key == "right") then
        return plan(key, {alt = true, shift = selection})
    elseif o.wordDelete and (key == "delete" or key == "forwarddelete") and not f.shift then
        return plan(key, {alt = true})
    elseif o.redo and key == "y" and not f.shift and not f.fn then
        return plan("z", {cmd = true, shift = true}, false)
    end
end
return M
