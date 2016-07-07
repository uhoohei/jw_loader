local loader = require("loader.loader")
local display = require("loader.display")

local scene = cc.Scene:create()
scene.name = "LoadScene"

function scene._addUI()
    local __bg = cc.Sprite:create("splash/splash_bg.jpg")
    if CONFIG_SCREEN_AUTOSCALE == "FIXED_HEIGHT" then
        __bg:setScale(display.height / updater.design_height)
    elseif CONFIG_SCREEN_AUTOSCALE == "FIXED_WIDTH" then
        __bg:setScale(display.width / updater.design_width)
    end
    display.align(__bg, display.CENTER, display.cx, display.cy)
    scene:addChild(__bg, 0)

    local __label = cc.LabelTTF:create("载入中... 0％", "Arial", 22)
    __label:setColor(display.c3b(230, 230, 230))
    scene._label = __label
    display.align(__label, display.CENTER, display.cx, display.bottom + 60)
    scene:addChild(__label, 10)

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
        scene.enterGameApp()
    elseif event == 'progress' then
        local str = string.format("载入中... %s％", tostring(vars[1]))
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
