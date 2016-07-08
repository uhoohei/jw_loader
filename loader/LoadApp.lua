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
local sharedFileUtils = cc.FileUtils:getInstance()
local loader = require("loader.loader")
local appName = "updater"  -- 更新模块的全局名称，要修改的话得修改关联的地方

function LoadApp.new(...)
    local instance = setmetatable({}, LoadApp)
    instance.class = LoadApp
    instance:ctor(...)
    return instance
end

function LoadApp:ctor(configs)
    assert(configs.preload_zips)
    assert(configs.app_entrance)
    assert(configs.work_path)
    assert(configs.design_width)
    assert(configs.design_height)
    assert(configs.seconds)
    assert(configs.java_channel_params)
    assert(configs.java_env_params)
    assert(configs.oc_channel_params)
    assert(configs.oc_env_params)
    _G[appName] = self
    self.configs_ = configs
    self.preload_zips = configs.preload_zips
    self.app_entrance = configs.app_entrance
    self.work_path = configs.work_path
    self.design_width = configs.design_width
    self.design_height = configs.design_height
    self.seconds = configs.seconds
    self.java_channel_params = configs.java_channel_params
    self.java_env_params = configs.java_env_params
    self.oc_channel_params = configs.oc_channel_params
    self.oc_env_params = configs.oc_env_params
end

function LoadApp:run(checkNewUpdatePackage)
    loader.init()
    local newLoaderPath = loader.hasNewUpdatePackage()
    print("LoadApp.run(%s)", checkNewUpdatePackage)
    if checkNewUpdatePackage and newLoaderPath then
        self:updateSelf(newLoaderPath)
    else
        local scene = require("loader.LoadScene")
        self:enterScene(scene)
    end
end

function LoadApp:updateSelf(newLoaderPath)
    print("LoadApp.updateSelf ", newLoaderPath)
    print("--before clean")
    loader.clean()
    for __,v in ipairs(updatePackage) do
        package.preload[v] = nil
        package.loaded[v] = nil
    end
    print("--after clean")
    local configs = self.configs_
    _G[appName] = nil  -- 清除自己
    cc.LuaLoadChunksFromZIP(newLoaderPath)
    print("--after cc.LuaLoadChunksForZIP")
    require("loader.LoadApp").new(configs):run(false)
    print("--after require and run")
end

function LoadApp:enterScene(__scene)
    if sharedDirector:getRunningScene() then
        sharedDirector:replaceScene(__scene)
    else
        sharedDirector:runWithScene(__scene)
    end
end

return LoadApp
