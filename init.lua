-- Tap, powered by Hammerspoon: Shift for Chinese/English, native Alt+Tab.
-- Ctrl/Command swapping and Caps Lock remain macOS keyboard settings.
local eventTypes = hs.eventtap.event.types
local keycodes = hs.keycodes.map
local pendingShift, previousShift = nil, false
local enabled = hs.settings.get("tap.enabled") ~= false
local shiftEnabled = hs.settings.get("tap.shiftEnabled") ~= false
local altEnabled = hs.settings.get("tap.altEnabled") ~= false
winKeys = {appName = "Tap", shiftSwitches = 0}
local compatRules = dofile(hs.configdir .. "/tap-shortcuts.lua")

local function otherModifier(flags)
    return flags.cmd or flags.ctrl or flags.alt or flags.fn
end

local function resetShift()
    pendingShift, previousShift = nil, false
end

local function toggleInput()
    -- Select the source directly, bypassing the system shortcut and its UI.
    local english = "com.apple.keylayout.ABC"
    local chinese = "com.apple.inputmethod.SCIM.ITABC"
    local target = hs.keycodes.currentSourceID() == chinese and english or chinese
    if hs.keycodes.currentSourceID(target) then
        winKeys.shiftSwitches = winKeys.shiftSwitches + 1
    else
        print("Could not select input source: " .. target)
    end
end

winKeys.shiftTap = hs.eventtap.new({
    eventTypes.flagsChanged, eventTypes.keyDown, eventTypes.keyUp,
    eventTypes.leftMouseDown, eventTypes.rightMouseDown,
    eventTypes.otherMouseDown, eventTypes.scrollWheel,
}, function(event)
    if not enabled or not shiftEnabled then return false end
    local kind, flags = event:getType(), event:getFlags()
    if kind ~= eventTypes.flagsChanged then
        pendingShift = nil -- typing, selection, or mouse use is never a Shift tap
        return false
    end
    local code = event:getKeyCode()
    local shiftKey = code == keycodes.shift or code == keycodes.rightshift
    local shift = flags.shift == true
    if shiftKey and shift and not previousShift and not otherModifier(flags) then
        pendingShift = hs.timer.secondsSinceEpoch()
    elseif shiftKey and not shift and previousShift then
        local started = pendingShift
        pendingShift = nil
        if started and not otherModifier(flags)
            and hs.timer.secondsSinceEpoch() - started <= 0.5 then
            toggleInput()
        end
    else
        pendingShift = nil -- another modifier or a second Shift cancels the tap
    end
    previousShift = shift
    return false -- Shift combinations and Caps Lock pass through unchanged
end)

-- Translate only an Alt+Tab session to Command+Tab. Dock draws the native UI.
local nativeTabActive = false
local generatedEvent = 0x574B4559
local sourceTag = hs.eventtap.event.properties.eventSourceUserData

local function releaseNativeTab()
    if nativeTabActive then
        nativeTabActive = false
        hs.eventtap.event.newKeyEvent({}, "cmd", false)
            :setFlags({}):setProperty(sourceTag, generatedEvent):post()
    end
end

winKeys.nativeTab = hs.eventtap.new({
    eventTypes.keyDown, eventTypes.keyUp, eventTypes.flagsChanged,
}, function(event)
    if not enabled or not altEnabled or event:getProperty(sourceTag) == generatedEvent then
        return false
    end
    local kind, flags, code = event:getType(), event:getFlags(), event:getKeyCode()
    local startsSession = kind == eventTypes.keyDown and code == keycodes.tab
        and flags.alt and not flags.cmd and not flags.ctrl and not flags.fn
    if not nativeTabActive and not startsSession then return false end
    pendingShift = nil

    if kind == eventTypes.flagsChanged and not flags.alt then
        nativeTabActive = false
        winKeys.nativeTabReleases = (winKeys.nativeTabReleases or 0) + 1
        flags.alt, flags.cmd = nil, nil
        event:setKeyCode(keycodes.cmd):setFlags(flags)
        return false -- Releasing physical Alt commits the native selection.
    end

    flags.alt, flags.cmd = nil, true
    event:setFlags(flags)
    if startsSession and not nativeTabActive then
        nativeTabActive = true
        winKeys.nativeTabStarts = (winKeys.nativeTabStarts or 0) + 1
        local commandDown = hs.eventtap.event.newKeyEvent({"cmd"}, "cmd", true)
            :setFlags(flags):setProperty(sourceTag, generatedEvent)
        return true, {commandDown, event:copy():setProperty(sourceTag, generatedEvent)}
    end
    return false -- Tab, Shift+Tab, arrows and Escape go to the native switcher.
end)
hs.shutdownCallback = releaseNativeTab

function winKeys.applySettings()
    resetShift()
    if enabled and shiftEnabled then winKeys.shiftTap:start() else winKeys.shiftTap:stop() end
    if enabled and altEnabled then
        winKeys.nativeTab:start()
    else
        releaseNativeTab()
        winKeys.nativeTab:stop()
    end
    if winKeys.applyCompatSettings then winKeys.applyCompatSettings() end
    if winKeys.refreshUI then winKeys.refreshUI() end
end

function winKeys.setEnabled(value)
    enabled = value == true
    hs.settings.set("tap.enabled", enabled)
    winKeys.applySettings()
end

function winKeys.setShiftEnabled(value)
    shiftEnabled = value == true
    hs.settings.set("tap.shiftEnabled", shiftEnabled)
    winKeys.applySettings()
end

function winKeys.setAltEnabled(value)
    altEnabled = value == true
    hs.settings.set("tap.altEnabled", altEnabled)
    winKeys.applySettings()
end

function winKeys.status()
    return {
        appName = winKeys.appName,
        enabled = enabled,
        shiftEnabled = shiftEnabled,
        altEnabled = altEnabled,
        autoLaunch = hs.autoLaunch(),
        accessibility = hs.accessibilityState(),
        shiftListener = winKeys.shiftTap:isEnabled(),
        altTabListener = winKeys.nativeTab:isEnabled(),
        altTabStyle = "macOS native",
        altTabActive = nativeTabActive,
        altTabStarts = winKeys.nativeTabStarts or 0,
        altTabReleases = winKeys.nativeTabReleases or 0,
        secureInput = hs.eventtap.isSecureInputEnabled(),
        inputSource = hs.keycodes.currentSourceID(),
        shiftSwitches = winKeys.shiftSwitches,
        shiftSwitchMode = "direct, on release",
        compatOptions = winKeys.compatStatus and winKeys.compatStatus() or compatRules.defaults(),
        compatDefinitions = compatRules.definitions,
        compatListener = winKeys.compatTap and winKeys.compatTap:isEnabled() or false,
    }
end

dofile(hs.configdir .. "/tap-compat.lua")(winKeys, compatRules, {
    generatedEvent = generatedEvent,
    isEnabled = function() return enabled end,
    nativeTabActive = function() return nativeTabActive end,
    resetShift = resetShift,
})

-- Compact overlapping windows + T, drawn at retina resolution.
local iconCanvas = hs.canvas.new({x = 0, y = 0, w = 40, h = 36})
iconCanvas:appendElements({
    type = "rectangle", action = "stroke",
    frame = {x = 4, y = 4, w = 25, h = 21},
    roundedRectRadii = {xRadius = 4, yRadius = 4},
    strokeWidth = 2.6, strokeColor = {white = 0, alpha = 1},
})
iconCanvas:appendElements({
    type = "rectangle", action = "fill", compositeRule = "clear",
    frame = {x = 10, y = 10, w = 26, h = 22},
    roundedRectRadii = {xRadius = 4.5, yRadius = 4.5},
})
iconCanvas:appendElements({
    type = "rectangle", action = "stroke",
    frame = {x = 10, y = 10, w = 26, h = 22},
    roundedRectRadii = {xRadius = 4.5, yRadius = 4.5},
    strokeWidth = 2.6, strokeColor = {white = 0, alpha = 1},
})
for _, bar in ipairs({{16.7, 15.7, 12.6, 2.6}, {21.7, 15.7, 2.6, 11.6}}) do
    iconCanvas:appendElements({
        type = "rectangle", action = "fill",
        frame = {x = bar[1], y = bar[2], w = bar[3], h = bar[4]},
        roundedRectRadii = {xRadius = 1.3, yRadius = 1.3},
        fillColor = {white = 0, alpha = 1},
    })
end
winKeys.menuIcon = iconCanvas:imageFromCanvas():setSize({w = 20, h = 18})
iconCanvas:delete()
winKeys.menu = hs.menubar.new(true, "WindowsKeys")
winKeys.menu:setIcon(winKeys.menuIcon, true):setTooltip("Tap · 键盘与窗口快捷键")
hs.menuIcon(false)
winKeys.actionMenu = hs.menubar.new(false)
winKeys.actionMenu:setMenu(function()
    local status = winKeys.status()
    return {
        {title = "打开 Tap", fn = function() winKeys.showUI() end},
        {title = "-"},
        {title = "Shift 切中英文 · Caps Lock 大小写", disabled = true},
        {title = "Alt+Tab 原生切应用 · Ctrl+C/V 复制粘贴", disabled = true},
        {title = "-"},
        {title = status.shiftListener and "键盘监听正常" or "键盘监听未启用", disabled = true},
        {title = status.secureInput and "密码输入期间系统暂停监听" or "输入法：" .. (status.inputSource or "未知"), disabled = true},
        {title = enabled and "暂停快捷键" or "恢复快捷键", fn = function()
            winKeys.setEnabled(not enabled)
        end},
        {title = "重新加载配置", fn = hs.reload},
        {title = "Tap 设置…", fn = function() winKeys.showUI() end},
        {title = "开发控制台…", fn = function() winKeys.openDiagnostics() end},
        {title = "退出", fn = function() hs.application.get("org.hammerspoon.Hammerspoon"):kill() end},
    }
end)


-- A normal click opens the panel immediately; Option-click keeps utility actions available.
winKeys.menu:setClickCallback(function(modifiers)
    if modifiers.alt then
        local frame = winKeys.menu:frame()
        if frame then winKeys.actionMenu:popupMenu({x = frame.x, y = frame.y + frame.h}) end
    else
        winKeys.toggleUI()
    end
end)

winKeys.applySettings()
-- macOS can stop an event tap; restore it after sleep or permission changes.
winKeys.watchdog = hs.timer.doEvery(5, function()
    if enabled and not hs.eventtap.isSecureInputEnabled() and hs.accessibilityState() then
        if shiftEnabled and not winKeys.shiftTap:isEnabled() then
            resetShift()
            winKeys.shiftTap:start()
        end
        if altEnabled and not winKeys.nativeTab:isEnabled() then
            releaseNativeTab()
            winKeys.nativeTab:start()
        end
        if winKeys.compatWanted() and not winKeys.compatTap:isEnabled() then winKeys.compatTap:start() end
    end
end)
hs.autoLaunch(hs.settings.get("tap.autoLaunch") ~= false)
hs.consoleOnTop(false)
dofile(hs.configdir .. "/tap-ui.lua")(winKeys)
print("Tap loaded: Shift / Caps Lock / native Alt+Tab")
