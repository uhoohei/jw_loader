local cc = cc or {}
cc.PLATFORM_OS_WINDOWS = 0
cc.PLATFORM_OS_LINUX   = 1
cc.PLATFORM_OS_MAC     = 2
cc.PLATFORM_OS_ANDROID = 3
cc.PLATFORM_OS_IPHONE  = 4
cc.PLATFORM_OS_IPAD    = 5
cc.PLATFORM_OS_BLACKBERRY = 6
cc.PLATFORM_OS_NACL    = 7
cc.PLATFORM_OS_EMSCRIPTEN = 8
cc.PLATFORM_OS_TIZEN   = 9
cc.PLATFORM_OS_WINRT   = 10
cc.PLATFORM_OS_WP8     = 11

local device = {}

device.platform    = "unknown"
device.model       = "unknown"

local sharedApplication = cc.Application:getInstance()
local target = sharedApplication:getTargetPlatform()
if target == cc.PLATFORM_OS_WINDOWS then
    device.platform = "windows"
elseif target == cc.PLATFORM_OS_MAC then
    device.platform = "mac"
elseif target == cc.PLATFORM_OS_ANDROID then
    device.platform = "android"
elseif target == cc.PLATFORM_OS_IPHONE or target == cc.PLATFORM_OS_IPAD then
    device.platform = "ios"
    if target == cc.PLATFORM_OS_IPHONE then
        device.model = "iphone"
    else
        device.model = "ipad"
    end
elseif target == cc.PLATFORM_OS_WINRT then
    device.platform = "winrt"
elseif target == cc.PLATFORM_OS_WP8 then
    device.platform = "wp8"
end

local language_ = sharedApplication:getCurrentLanguage()
if language_ == cc.LANGUAGE_CHINESE then
    language_ = "cn"
elseif language_ == cc.LANGUAGE_FRENCH then
    language_ = "fr"
elseif language_ == cc.LANGUAGE_ITALIAN then
    language_ = "it"
elseif language_ == cc.LANGUAGE_GERMAN then
    language_ = "gr"
elseif language_ == cc.LANGUAGE_SPANISH then
    language_ = "sp"
elseif language_ == cc.LANGUAGE_RUSSIAN then
    language_ = "ru"
elseif language_ == cc.LANGUAGE_KOREAN then
    language_ = "kr"
elseif language_ == cc.LANGUAGE_JAPANESE then
    language_ = "jp"
elseif language_ == cc.LANGUAGE_HUNGARIAN then
    language_ = "hu"
elseif language_ == cc.LANGUAGE_PORTUGUESE then
    language_ = "pt"
elseif language_ == cc.LANGUAGE_ARABIC then
    language_ = "ar"
else
    language_ = "en"
end

device.language = language_
device.writablePath = cc.FileUtils:getInstance():getWritablePath()
-- device.cachePath = cc.FileUtils:getInstance():getCachePath()
device.directorySeparator = "/"
device.pathSeparator = ":"
if device.platform == "windows" then
    device.directorySeparator = "\\"
    device.pathSeparator = ";"
end

device.isAndroid = ("android" == device.platform)
device.isIOS = ("ios" == device.platform)

local luaj
if device.isAndroid then
    luaj = require("loader.luaj")
end

local luaoc
if device.isIOS then
    luaoc = require("loader.luaoc")
end

local function table_map(t, fn)
    for k, v in pairs(t) do
        t[k] = fn(v, k)
    end
end

-- start --

--------------------------------
-- 显示一个包含按钮的弹出对话框
-- @function [parent=#device] showAlert
-- @param string title 对话框标题
-- @param string message 内容
-- @param table buttonLabels 包含多个按钮标题的表格对象
-- @param function listener 回调函数

--[[--

显示一个包含按钮的弹出对话框

~~~ lua

local function onButtonClicked(event)
    if event.buttonIndex == 1 then
        .... 玩家选择了 YES 按钮
    else
        .... 玩家选择了 NO 按钮
    end
end

device.showAlert("Confirm Exit", "Are you sure exit game ?", {"YES", "NO"}, onButtonClicked)

~~~

当没有指定按钮标题时，对话框会默认显示一个“OK”按钮。
回调函数获得的表格中，buttonIndex 指示玩家选择了哪一个按钮，其值是按钮的显示顺序。

]]

-- end --

function device.showAlert(title, message, buttonLabels, listener)
    if type(buttonLabels) ~= "table" then
        buttonLabels = {tostring(buttonLabels)}
    else
        table_map(buttonLabels, function(v) return tostring(v) end)
    end

    if DEBUG > 1 then
        print("device.showAlert() - title: %s", title)
        print("    message: %s", message)
        print("    buttonLabels: %s", table.concat(buttonLabels, ", "))
    end

    if device.platform == "android" then
        local tempListner = function(event)
            if type(event) == "string" then
                event = require("loader.json").decode(event)
                event.buttonIndex = tonumber(event.buttonIndex)
            end
            if listener then listener(event) end
        end
        luaj.callStaticMethod("org/cocos2dx/utils/PSNative", "createAlert", {title, message, buttonLabels, tempListner}, "(Ljava/lang/String;Ljava/lang/String;Ljava/util/Vector;I)V");
    else
        local defaultLabel = ""
        if #buttonLabels > 0 then
            defaultLabel = buttonLabels[1]
            table.remove(buttonLabels, 1)
        end

        cc.Native:createAlert(title, message, defaultLabel)
        for i, label in ipairs(buttonLabels) do
            cc.Native:addAlertButton(label)
        end

        if type(listener) ~= "function" then
            listener = function() end
        end

        cc.Native:showAlert(listener)
    end
end

-- start --

--------------------------------
-- 取消正在显示的对话框。
-- @function [parent=#device] cancelAlert

-- end --

function device.cancelAlert()
    if DEBUG > 1 then
        print("device.cancelAlert()")
    end
    cc.Native:cancelAlert()
end

local function checknumber(value, base)
    return tonumber(value, base) or 0
end

local function round(value)
    value = checknumber(value)
    return math.floor(value + 0.5)
end

local function checkint(value)
    return round(checknumber(value))
end

local function callNativeAndroid(java_class, java_method_name, java_method_params, java_method_sig)
    if DEBUG and DEBUG > 0 then
        print("callNativeAndroid(%s, %s, %s, %s)", java_class, java_method_name, type(java_method_params), java_method_sig)
    end
    local ok, result = luaj.callStaticMethod(java_class, java_method_name, java_method_params, java_method_sig)
    if ok then
        return result
    end
end

-- 获得SD卡目录
local sdCardPath = nil
function device.getSDCardPath()
    -- if device.platform ~= "android" then
    return device.writablePath
    -- end
    -- if sdCardPath then
    --     return sdCardPath
    -- end
    -- sdCardPath = callNativeAndroid("com/jw/utils/Bridge", "getExternalStorageDirectory", {}, "()Ljava/lang/String;")
    -- return sdCardPath
end

return device
