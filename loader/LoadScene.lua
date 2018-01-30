local loader = require("loader.loader")
local display = require("loader.display")
local utils = require("loader.utils")

local configs = nil
local scene = cc.Scene:create()
scene.name = "LoadScene"

function scene.init(_configs)
    configs = _configs
    
    assert(configs.preload_zips)
    assert(configs.app_entrance)
    assert(configs.work_path)
    assert(configs.design_width)
    assert(configs.design_height)
    assert(configs.seconds)
    utils.logFile("assert finish")

    loader.init(configs)
    utils.logFile("set configs finish.")
    scene.drawUI_()
end

function scene.drawUI_()
    local bg_sprite_name = configs.bg_sprite_name or "splash/splash_bg.jpg"
    if bg_sprite_name and string.len(bg_sprite_name) > 0 then
        local __bg = cc.Sprite:create(bg_sprite_name)
        if CONFIG_SCREEN_AUTOSCALE == "FIXED_HEIGHT" then
            __bg:setScale(display.width / configs.design_width)
        elseif CONFIG_SCREEN_AUTOSCALE == "FIXED_WIDTH" then
            __bg:setScale(display.height / configs.design_height)
        end
        display.align(__bg, display.CENTER, display.cx, display.cy)
        scene:addChild(__bg, 0)
    end

    local __label = cc.LabelTTF:create("载入中... 0％", "Arial", 22)
    __label:setColor(display.c3b(230, 230, 230))
    scene._label = __label
    display.align(__label, display.CENTER, display.cx, display.bottom + 60)
    scene:addChild(__label, 10)

    local progress_bg_name = configs.progress_bg_name or "splash/loading_bar_bg.png"
    local progress_fg_name = configs.progress_fg_name or "splash/loading_bar.png"
    if progress_bg_name and progress_fg_name and string.len(progress_fg_name) > 0 and string.len(progress_bg_name) > 0 then
        local x, y = display.cx, display.cy - 130
        local bg = cc.Sprite:create(progress_bg_name)
        bg:setPosition(x, y)
        scene:addChild(bg, 9)

        local progress = cc.ProgressTimer:create(cc.Sprite:create(progress_fg_name))
        progress:setType(1)
        progress:setMidpoint({x=0, y=0.5})
        progress:setBarChangeRate({x=1, y=0})
        progress:setPosition(x, y)
        scene:addChild(progress, 10)
        scene.progress_ = progress
    end

    scene.labelDebug_ = cc.LabelTTF:create("", "Arial", 26)
    scene.labelDebug_:setColor(display.c3b(255, 255, 255))
    display.align(scene.labelDebug_, display.CENTER, display.cx, display.cy)
    scene:addChild(scene.labelDebug_, 10)
    loader.setLoadEventHandler(scene.onLoaderEvent)
end

function scene._sceneHandler(event)
    utils.logFile("scene._sceneHandler(event)", event)
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

function scene.onLoaderEvent(event, ...)
    utils.logFile("scene.onLoaderEvent", event)
    local vars = {...}
    local str = table.concat(vars, ", ")
    if tolua.isnull(scene) then
        utils.logFile("tolua.isnull(scene)")
        return
    end
    if DEBUG and DEBUG > 0 then
        str = event .. "@" .. str
        scene.labelDebug_:setString(str)
    end

    if event == 'fail' then
        scene.labelDebug_:setString(str)
    end
    if event == "success" or event == "fail" then
        scene.setPercent_(100)
        scene.enterGameApp()
    elseif event == 'progress' then
        scene.onProgress_(vars)
    end
end

function scene.onProgress_(vars)
    local totalFiles, finishFiles, totalSize, finishSize, inProgressSize, percent = unpack(vars)
    scene.setPercent_(percent)
end

function scene.setPercent_(percent)
    if scene.progress_ then
        scene.progress_:setPercentage(percent)
    end
    if scene._label then
        local str = string.format("载入中... %s％", tostring(percent))
        scene._label:setString(str)
    end
end

function scene.enterGameApp()
    utils.logFile("scene.enterGameApp()")
    for i,v in ipairs(configs.preload_zips) do
        cc.LuaLoadChunksFromZIP(v)
    end
    require(configs.app_entrance).new():run()
end

local function doSchedule(node, callback, delay)
    local delay = cc.DelayTime:create(delay)
    local sequence = cc.Sequence:create(delay, cc.CallFunc:create(callback))
    local action = cc.RepeatForever:create(sequence)
    node:runAction(action)
    return action
end

function stopTarget(target)
    local actionManager = cc.Director:getInstance():getActionManager()
    if not tolua.isnull(target) then
        actionManager:removeAllActionsFromTarget(target)
    end
end

function scene.onEnter()
    loader.update()
    doSchedule(scene, loader.onSchedule, 0.02)
end

function scene.onExit()
    utils.logFile("scene.onExit()\r\n\r\n")
    loader.clean()
    scene:unregisterScriptHandler()
    stopTarget(scene)
end

function scene.onCleanup()
end

scene:registerScriptHandler(scene._sceneHandler)

return scene
