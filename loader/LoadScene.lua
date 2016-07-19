local loader = require("loader.loader")
local display = require("loader.display")

local scene = cc.Scene:create()
scene.name = "LoadScene"

function scene._addUI()
    local bg_sprite_name = updater.bg_sprite_name or "splash/splash_bg.jpg"
    if bg_sprite_name and string.len(bg_sprite_name) > 0 then
        local __bg = cc.Sprite:create(bg_sprite_name)
        if CONFIG_SCREEN_AUTOSCALE == "FIXED_HEIGHT" then
            __bg:setScale(display.height / updater.design_height)
        elseif CONFIG_SCREEN_AUTOSCALE == "FIXED_WIDTH" then
            __bg:setScale(display.width / updater.design_width)
        end
        display.align(__bg, display.CENTER, display.cx, display.cy)
        scene:addChild(__bg, 0)
    end

    local __label = cc.LabelTTF:create("载入中... 0％", "Arial", 22)
    __label:setColor(display.c3b(230, 230, 230))
    scene._label = __label
    display.align(__label, display.CENTER, display.cx, display.bottom + 60)
    scene:addChild(__label, 10)

    local progress_bg_name = updater.progress_bg_name or "splash/loading_bar_bg.png"
    local progress_fg_name = updater.progress_fg_name or "splash/loading_bar.png"
    if progress_bg_name and progress_fg_name and string.len(progress_fg_name) > 0 and string.len(progress_bg_name) > 0 then
        local x, y = display.cx, display.cy - 130
        local bg = cc.Sprite:create(progress_bg_name)
        bg:setPosition(x, y)
        scene:addChild(bg, 9)

        local progress = cc.ProgressTimer:create(cc.Sprite:create(progress_fg_name))
        progress:setType(1)
        progress:setMidpoint({0, 0.5})
        progress:setBarChangeRate({1, 0})
        progress:setPosition(x, y)
        scene:addChild(progress, 10)
        scene.progress_ = progress
    end

    scene.labelDebug_ = cc.LabelTTF:create("", "Arial", 22)
    scene.labelDebug_:setColor(display.c3b(50, 50, 50))
    display.align(scene.labelDebug_, display.CENTER, display.cx, display.bottom + 30)
    scene:addChild(scene.labelDebug_, 10)
end

function scene._sceneHandler(event)
    if event == "enter" then
        scene.onEnter()
    elseif event == "cleanup" then
        scene.onCleanup()
    elseif event == "exit" then
        scene.onExit()
    end
end

local function dump(tbl)
    for k,v in pairs(tbl) do
        print(k, "\t", v)
    end
end

function scene._updateHandler(event, ...)
    local vars = {...}
    local str = table.concat(vars, ", ")
    if DEBUG and DEBUG > 0 then
        str = event .. "@" .. str
        scene.labelDebug_:setString(str)
    end

    if event == 'fail' then
        scene.labelDebug_:setString(str)
    end
    if event == "success" or event == "fail" then
        scene.setProgress_(100)
        scene.enterGameApp()
    elseif event == 'progress' then
        scene.setProgress_(vars[1])
    end
end

function scene.setProgress_(percent)
    if scene.progress_ then
        scene.progress_:setPercentage(percent)
    end
    if scene._label then
        local str = string.format("载入中... %s％", tostring(percent))
        scene._label:setString(str)
    end
end

function scene.enterGameApp()
    for i,v in ipairs(updater.preload_zips) do
        cc.LuaLoadChunksFromZIP(v)
    end
    require(updater.app_entrance).new():run()
end

function scene.onEnter()
    loader.update(scene._updateHandler)
end

function scene.onExit()
    loader.clean()
    scene:unregisterScriptHandler()
end

function scene.onCleanup()
end

scene:registerScriptHandler(scene._sceneHandler)
scene._addUI()

return scene
