-- Local Tap panel. No server or external pages are needed.
return function(app)
    local diagnosticMode = false
    local panel
    local dragOrigin
    local controller = hs.webview.usercontent.new("tap")
    local function readHTML()
        local file = assert(io.open(hs.configdir .. "/tap-ui.html", "r"))
        local html = file:read("*a")
        file:close()
        return html
    end

    function app.refreshUI()
        if panel and panel:isVisible() then
            panel:evaluateJavaScript("update(" .. hs.json.encode(app.status()) .. ")")
        end
    end

    function app.showUI()
        diagnosticMode = false
        hs.closeConsole()
        if not panel then
            local frame = hs.screen.mainScreen():frame()
            local height = math.min(520, frame.h - 70)
            panel = hs.webview.new({
                x = frame.x + (frame.w - 520) / 2,
                y = frame.y + (frame.h - height) / 2,
                w = 520, h = height,
            }, {privateBrowsing = true, javaScriptCanOpenWindowsAutomatically = false}, controller)
                :windowStyle({"borderless", "miniaturizable"})
                :allowTextEntry(true):allowNewWindows(false):deleteOnClose(false)
                :transparent(true):shadow(false)
            panel:windowTitle("Tap")
            panel:darkMode(false)
            panel:navigationCallback(function(action)
                if action == "didFinishNavigation" then app.refreshUI() end
            end)
            panel:html(readHTML())
        end
        panel:show()
        local window = panel:hswindow()
        if window then window:unminimize():focus() end
        app.refreshUI()
    end

    function app.toggleUI()
        local window = panel and panel:hswindow()
        if panel and panel:isVisible() and window and not window:isMinimized() then
            panel:hide()
        else
            app.showUI()
        end
    end

    function app.openDiagnostics()
        diagnosticMode = true
        hs.openConsole()
    end

    controller:setCallback(function(message)
        local body = message.body or message
        if type(body) ~= "table" or type(body.action) ~= "string" then return end
        if body.action == "master" then
            app.setEnabled(not app.status().enabled)
        elseif body.action == "shift" and type(body.value) == "boolean" then
            app.setShiftEnabled(body.value)
        elseif body.action == "alt" and type(body.value) == "boolean" then
            app.setAltEnabled(body.value)
        elseif body.action == "compat" and type(body.value) == "table" then
            app.setCompatOption(body.value.id, body.value.enabled)
        elseif body.action == "page" and (body.value == "main" or body.value == "more") then
            if panel then
                local window = panel:hswindow()
                local screen = window and window:screen() or hs.screen.mainScreen()
                local bounds, frame = screen:frame(), panel:frame()
                local height = math.min(body.value == "more" and 620 or 520, bounds.h - 70)
                local y = math.max(bounds.y + 8, math.min(frame.y + (frame.h - height) / 2, bounds.y + bounds.h - height - 8))
                panel:frame({x = frame.x, y = y, w = frame.w, h = height})
            end
        elseif body.action == "autostart" and type(body.value) == "boolean" then
            hs.settings.set("tap.autoLaunch", body.value)
            hs.autoLaunch(body.value)
        elseif body.action == "hide" then
            if panel then panel:hide() end
        elseif body.action == "minimize" then
            if panel then panel:hswindow():minimize() end
        elseif body.action == "dragStart" and type(body.value) == "table" then
            local value = body.value
            if panel and type(value.x) == "number" and type(value.y) == "number" then
                dragOrigin = {x = value.x, y = value.y, frame = panel:frame()}
            end
        elseif body.action == "dragMove" and dragOrigin and type(body.value) == "table" then
            local value = body.value
            if type(value.x) == "number" and type(value.y) == "number" then
                local frame = dragOrigin.frame
                panel:frame({x = frame.x + value.x - dragOrigin.x,
                    y = frame.y + value.y - dragOrigin.y, w = frame.w, h = frame.h})
            end
        elseif body.action == "dragEnd" then
            dragOrigin = nil
        elseif body.action == "reload" then
            hs.settings.set("tap.restorePanel", true)
            app.reloadTimer = hs.timer.doAfter(0.1, hs.reload)
        end
        if body.action ~= "dragMove" then app.refreshUI() end
    end)

    -- Hammerspoon opens its console on app reopen; replace that entry point
    -- with the panel, while leaving the explicitly requested diagnostics usable.
    app.panelWatcher = hs.timer.doEvery(0.5, function()
        local console = hs.console.hswindow()
        local visible = console and console:isVisible()
        if visible and not diagnosticMode then
            app.showUI()
        elseif diagnosticMode and not visible then
            diagnosticMode = false
        end
        app.refreshUI()
    end)
    app.panelBoot = hs.timer.doAfter(0.2, function()
        local console = hs.console.hswindow()
        if hs.settings.get("tap.restorePanel") or (console and console:isVisible()) then
            hs.settings.set("tap.restorePanel", false)
            app.showUI()
        end
    end)
    app.panel = function() return panel end
end
