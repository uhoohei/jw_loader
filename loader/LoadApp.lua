local LoadApp = {}

LoadApp.__cname = "LoadApp"
LoadApp.__index = LoadApp
LoadApp.__ctype = 2

local sharedDirector = cc.Director:getInstance()
local loader = require("loader.loader")
local utils = require("loader.utils")

function LoadApp.new(...)
    local instance = setmetatable({}, LoadApp)
    instance.class = LoadApp
    instance:ctor(...)
    return instance
end

function LoadApp:ctor(configs)
    utils.removeLogFile(configs.keepLogSize or 20 * 1024 * 1024)
    utils.logFile("\r\n\r\nLoadApp:ctor", configs)
    self.configs_ = configs
end

function LoadApp:run()
    utils.logFile("LoadApp:run()")
    local scene = require("loader.LoadScene")
    scene.init(self.configs_)
    self:enterScene(scene)
end

function LoadApp:enterScene(__scene)
    if sharedDirector:getRunningScene() then
        sharedDirector:replaceScene(__scene)
    else
        sharedDirector:runWithScene(__scene)
    end
end

return LoadApp
