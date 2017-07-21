local network = require("loader.network")
local utils = require("loader.utils")
local HTTP = {}

local TIMEOUT_SECONDS = 20  -- HTTP 超时时间

local function string_split(input, delimiter)
    input = tostring(input)
    delimiter = tostring(delimiter)
    if (delimiter=='') then return false end
    local pos,arr = 0, {}
    -- for each divider found
    for st,sp in function() return string.find(input, delimiter, pos, true) end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end

local function onRequestFinished(event, sucFunc, failFunc)
    local ok = (event.name == "completed")
    local request = event.request
 
    if event.name == "progress" then
        return
    end

    if not ok then
        -- 请求失败，显示错误代码和错误消息
        utils.logFile("HTTP request fail: ", event.name, request:getErrorCode(), request:getErrorMessage())
        if failFunc then failFunc() end
        return
    end

    local code = request:getResponseStatusCode()
    if code ~= 200 then
        -- 请求结束，但没有返回 200 响应代码
        utils.logFile("HTTP code error: " .. code)
        if failFunc then failFunc() end
        return
    end

    local response = request:getResponseString()
    if sucFunc then
        sucFunc(response)
    end
end

function HTTP.get(url, sucFunc, failFunc, timeoutSeconds)
    local seconds = timeoutSeconds or TIMEOUT_SECONDS
    local function handler_func(event)
        onRequestFinished(event, sucFunc, failFunc)
    end
    local request = network.createHTTPRequest(handler_func, url, "GET")
    request:addRequestHeader("Content-Type: application/x-www-form-urlencoded")
    request:setTimeout(seconds)
    request:start()
end

function HTTP.post(url, params, sucFunc, failFunc, timeoutSeconds)
    local seconds = timeoutSeconds or TIMEOUT_SECONDS
    -- 创建一个请求，并以 POST 方式发送数据到服务端
    local function handler_func(event)
        onRequestFinished(event, sucFunc, failFunc)
    end
    local request = network.createHTTPRequest(handler_func, url, "POST")
    request:addRequestHeader("Content-Type: application/x-www-form-urlencoded")
    if params then
        for k, v in pairs(params) do
            request:addPOSTValue(k, v)
        end
    end
    request:setTimeout(seconds)
    request:start() -- 开始请求。当请求完成时会调用 callback() 函数
end

local function onDownloaded(event, sucFunc, failFunc, progressFunc, filename)
    local ok = (event.name == "completed")
    local request = event.request
 
    if event.name == "progress" then
        if progressFunc then
            progressFunc(event.total or 0, event.dltotal or 0)  -- 通知下载进度
        end
    elseif not ok then
        -- 请求失败，显示错误代码和错误消息
        local errorCode = request:getErrorCode()
        local message = request:getErrorMessage()
        utils.logFile("HTTP download fail: ", event.name, errorCode, message)
        if failFunc then
            failFunc(errorCode, message)
        end
    elseif ok then
        utils.logFile("before save file: ", filename)
        -- request:saveResponseData(filename) -- 此句在android写不下文件
        local flag = utils.writeFile(filename, request:getResponseData())
        utils.logFile("after save file: ", filename, tostring(flag))
        if sucFunc then
            sucFunc(filename)
        end
    end
end

-- HTTP下载
function HTTP.download(url, filename, sucFunc, failFunc, timeoutSeconds, progressFunc)
    assert(filename)
    local seconds = timeoutSeconds or TIMEOUT_SECONDS
    local function handler_func(event)
       onDownloaded(event, sucFunc, failFunc, progressFunc, filename)
    end
    local request = network.createHTTPRequest(handler_func, url, "GET")
    request:setTimeout(seconds)
    request:start()
end

return HTTP
