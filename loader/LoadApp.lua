-- 更新包所包含的所有模块，方便移除
local updatePackage = {
    "loader.utils",
    "loader.http",
    "loader.json",
    "loader.network",
    "loader.display",
    "loader.crypto",
    "loader.scheduler",
    "loader.device",
    "loader.LoadApp",
    "loader.loader",
    "loader.LoadScene",
    "loader.luaoc",
    "loader.luaj",
}

local LoadApp = {}

LoadApp.__cname = "LoadApp"
LoadApp.__index = LoadApp
LoadApp.__ctype = 2

local sharedDirector = cc.Director:getInstance()
local loader = require("loader.loader")
local utils = require("loader.utils")
local appName = "updater"  -- 更新模块的全局名称，要修改的话得修改关联的地方

function LoadApp.new(...)
    local instance = setmetatable({}, LoadApp)
    instance.class = LoadApp
    instance:ctor(...)
    return instance
end

function LoadApp:ctor(configs)
    utils.removeLogFile()
    utils.logFile("LoadApp:ctor", configs)
    assert(configs.preload_zips)
    assert(configs.app_entrance)
    assert(configs.work_path)
    assert(configs.design_width)
    assert(configs.design_height)
    assert(configs.seconds)
    utils.logFile("assert finish")
    _G[appName] = self
    self.configs_ = configs
    self.preload_zips = configs.preload_zips
    self.app_entrance = configs.app_entrance
    self.work_path = configs.work_path
    self.design_width = configs.design_width
    self.design_height = configs.design_height
    self.seconds = math.max(120, configs.seconds)
    
    self.bg_sprite_name = configs.bg_sprite_name
    self.progress_bg_name = configs.progress_bg_name
    self.progress_fg_name = configs.progress_fg_name
    self.zip64 = configs.zip64
    utils.logFile("set configs finish.")
end

function LoadApp:run()
    utils.logFile("LoadApp:run()")
    loader.init(self.zip64)
    local scene = require("loader.LoadScene")
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
