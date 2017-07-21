--[[

Copyright (c) 2011-2014 chukong-inc.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

]]

--------------------------------
-- @module network

--[[--

网络服务

]]

-- 小补丁，因为不用CURL库的话这几个变量不会被导出
if not kCCNetworkStatusNotReachable then
    kCCNetworkStatusNotReachable = 0
end
if not kCCNetworkStatusReachableViaWiFi then
    kCCNetworkStatusReachableViaWiFi = 1
end
if not kCCNetworkStatusReachableViaWWAN then
    kCCNetworkStatusReachableViaWWAN = 2
end

local network = {}

-- start --

--------------------------------
-- 检查地 WIFI 网络是否可用
-- @function [parent=#network] isLocalWiFiAvailable
-- @return boolean#boolean ret (return value: bool)  网络是否可用

--[[--

检查地 WIFI 网络是否可用

提示： WIFI 网络可用不代表可以访问互联网。

]]
-- end --

function network.isLocalWiFiAvailable()
    return cc.Network:isLocalWiFiAvailable()
end

-- start --

--------------------------------
-- 检查互联网连接是否可用
-- @function [parent=#network] isInternetConnectionAvailable
-- @return boolean#boolean ret (return value: bool)  网络是否可用

--[[--

检查互联网连接是否可用

通常，这里接口返回 3G 网络的状态，具体情况与设备和操作系统有关。 

]]
-- end --

function network.isInternetConnectionAvailable()
    return cc.Network:isInternetConnectionAvailable()
end

-- start --

--------------------------------
-- 检查是否可以解析指定的主机名
-- @function [parent=#network] isHostNameReachable
-- @param string hostname 主机名
-- @return boolean#boolean ret (return value: bool)  主机名是否可以解析

--[[--

检查是否可以解析指定的主机名

~~~ lua

if network.isHostNameReachable("www.google.com") then
    -- 域名可以解析
end

~~~

注意： 该接口会阻塞程序，因此在调用该接口时应该提醒用户应用程序在一段时间内会失去响应。 

]]
-- end --

function network.isHostNameReachable(hostname)
    assert(type(hostname) == "string")
    return cc.Network:isHostNameReachable(hostname)
end

-- start --

--------------------------------
-- 返回互联网连接状态值
-- @function [parent=#network] getInternetConnectionStatus
-- @return string#string ret (return value: string)  互联网连接状态值

--[[--

返回互联网连接状态值

状态值有三种：

-   kCCNetworkStatusNotReachable: 无法访问互联网
-   kCCNetworkStatusReachableViaWiFi: 通过 WIFI
-   kCCNetworkStatusReachableViaWWAN: 通过 3G 网络

]]
-- end --

function network.getInternetConnectionStatus()
    return cc.Network:getInternetConnectionStatus()
end

-- start --

--------------------------------
-- 创建异步 HTTP 请求，并返回 cc.HTTPRequest 对象。
-- @function [parent=#network] createHTTPRequest
-- @param function callbock 回调函数
-- @url string http路径
-- method string method 请求方式
-- @return HTTPRequest#HTTPRequest ret (return value: cc.HTTPRequest) 

--[[--

创建异步 HTTP 请求，并返回 cc.HTTPRequest 对象。 

~~~ lua

function onRequestFinished(event)
    local ok = (event.name == "completed")
    local request = event.request
 
    if not ok then
        -- 请求失败，显示错误代码和错误消息
        print(request:getErrorCode(), request:getErrorMessage())
        return
    end
 
    local code = request:getResponseStatusCode()
    if code ~= 200 then
        -- 请求结束，但没有返回 200 响应代码
        print(code)
        return
    end
 
    -- 请求成功，显示服务端返回的内容
    local response = request:getResponseString()
    print(response)
end
 
-- 创建一个请求，并以 POST 方式发送数据到服务端
local url = "http://www.mycompany.com/request.php"
local request = network.createHTTPRequest(onRequestFinished, url, "POST")
request:addPOSTValue("KEY", "VALUE")
 
-- 开始请求。当请求完成时会调用 callback() 函数
request:start()

~~~

]]
-- end --

function network.createHTTPRequest(callback, url, method)
    if not method then method = "GET" end
    if string.upper(tostring(method)) == "GET" then
        method = cc.kCCHTTPRequestMethodGET
    else
        method = cc.kCCHTTPRequestMethodPOST
    end
    return cc.HTTPRequest:createWithUrl(callback, url, method)
end

return network
