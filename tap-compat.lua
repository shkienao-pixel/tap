-- Optional event tap. No key is intercepted until a saved option is enabled.
return function(app, rules, runtime)
    local options = rules.defaults(hs.settings.get("tap.compatOptions"))
    local held = {}
    local types, properties = hs.eventtap.event.types, hs.eventtap.event.properties
    local function hasHeld() return next(held) ~= nil end
    local function textFocused(front)
        if not front or rules.terminals[front:bundleID()] then return false end
        local ok, editable = pcall(function()
            local root = hs.axuielement.applicationElement(front):setTimeout(0.05)
            local element = root:attributeValue("AXFocusedUIElement")
            if not element then return false end
            element:setTimeout(0.05)
            local role = element:attributeValue("AXRole")
            if element:attributeValue("AXSubrole") == "AXSecureTextField" then return false end
            return role == "AXTextField" or role == "AXTextArea" or role == "AXComboBox"
                or element:attributeValue("AXEditable") == true
        end)
        return ok and editable == true
    end
    local function replacement(event, result)
        local modifiers = {}
        for key, value in pairs(result.flags) do if value then table.insert(modifiers, key) end end
        return hs.eventtap.event.newKeyEvent(modifiers, result.key, event:getType() == types.keyDown)
            :setFlags(result.flags):setProperty(properties.eventSourceUserData, runtime.generatedEvent)
            :setProperty(properties.keyboardEventAutorepeat, event:getProperty(properties.keyboardEventAutorepeat))
    end
    app.compatTap = hs.eventtap.new({types.keyDown, types.keyUp}, function(event)
        if event:getProperty(properties.eventSourceUserData) == runtime.generatedEvent then return false end
        local code, kind = event:getKeyCode(), event:getType()
        local result = held[code]
        if result and kind == types.keyDown and event:getProperty(properties.keyboardEventAutorepeat) == 0 then
            -- A fresh press after sleep/lost key-up must respect current preferences.
            held[code], result = nil, nil
        end
        if result then
            if kind == types.keyDown and not result.repeatable then return true end
            local output = replacement(event, result)
            if kind == types.keyUp then
                held[code] = nil
                if not hasHeld() and (not runtime.isEnabled() or not rules.any(options)) then app.compatTap:stop() end
            end
            return true, {output}
        end
        if kind ~= types.keyDown then return false end
        if not runtime.isEnabled() or not rules.any(options) then
            if not hasHeld() then app.compatTap:stop() end
            return false
        end
        local key, flags = hs.keycodes.map[code], event:getFlags()
        local front = hs.application.frontmostApplication()
        local context = {
            bundle = front and front:bundleID() or "",
            secureInput = hs.eventtap.isSecureInputEnabled(),
            nativeTabActive = runtime.nativeTabActive(),
            editable = false,
        }
        if rules.textCandidate(key, flags, options) or (options.finderRename and key == "f2") then
            context.editable = textFocused(front)
        end
        result = rules.resolve(key, flags, context, options)
        if not result then return false end
        runtime.resetShift()
        held[code] = result
        return true, {replacement(event, result)}
    end)
    function app.applyCompatSettings()
        if app.compatWanted() then app.compatTap:start() else app.compatTap:stop() end
    end
    function app.compatWanted()
        return (runtime.isEnabled() and rules.any(options)) or hasHeld()
    end
    function app.setCompatOption(id, value)
        if options[id] == nil or type(value) ~= "boolean" then return end
        options[id] = value
        hs.settings.set("tap.compatOptions", options)
        app.applyCompatSettings()
        if app.refreshUI then app.refreshUI() end
    end
    function app.compatStatus()
        local copy = {}
        for key, value in pairs(options) do copy[key] = value end
        return copy
    end
end
