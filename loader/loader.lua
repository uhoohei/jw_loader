local json = require("loader.json")
local http = require("loader.http")
local crypto = require("loader.crypto")
local device = require("loader.device")
local network = require("loader.network")
local utils = require("loader.utils")

--------------------------------- CONFIG START -------------------------------
-- 下载版本文件，对比检查，下载资源索引文件，检验索引文件，
-- 分析需要下载的文件，下载并检验文件，替换当前版本，更新结束。
local EVENTS = {
    success = 'success',
    fail = 'fail',
    progress = 'progress',
}

local SUCCESS_TYPES = {
    noNewVersion = 'noNewVersion',
    updateSuccess = 'updateSuccess',
}

local ERRORS = {
    rawIndexReadFail = 'rawIndexReadFail',
    createFile = "errorCreateFile",
    network = "errorNetwork",
    unknown = "errorUnknown";
}

local TASK = {  -- 任务的几种状态
    idle = 0,
    success = 1,
    progress = 2,
    fail = 3,
}

--[[
名词说明：
原版：指APK或IPA包中自带的文件
当前版：指更新目录中的经过检验的文件
新版：指最新下载的，还未完成更新的文件，新版经过验证后会变成当前版
]]
local CURRENT_SUFFIX = ".curr"  -- 当前启用版本所用的后缀
local NEW_SUFFIX = ".new"  -- 正在更新中的版本的后缀，如果此类文件存在，说明上一次的更新未完成
local VERSION_FILE_NAME = "version.txt"  -- 其实是json，这里只是为了防止运营商劫持所修改的后缀
local INDEX_FILE_NAME = "resindex.txt"  -- 其实是json，这里只是为了防止运营商劫持所修改的后缀
local DOWNLOAD_THREADS = 4  -- 同时下载的任务数
--------------------------------- CONFIG END ---------------------------------

local configs = nil
local loader = {}

function loader.init(_configs)
    utils.logFile('loader.init')
    configs = _configs
    loader.versionInfoNew_ = {}  -- 新下载的版本信息
    loader.indexInfoCurr_ = {}  -- 当前版的文件索引信息，可参考resindex.txt文件
    loader.indexInfoRaw_ = {}  -- 原包里面的索引信息
    loader.indexInfoNew_ = {}  -- 新下载的索引文件的信息
    loader.startTime_ = 0
    loader.currIndexFilePath_ = configs.work_path .. INDEX_FILE_NAME .. CURRENT_SUFFIX
    loader.newIndexFilePath_ = configs.work_path .. INDEX_FILE_NAME .. NEW_SUFFIX
    loader.taskList_ = nil
    utils.logFile(configs.work_path)
    local ok, err = utils.mkdir(configs.work_path, true)
    utils.logFile("mkdir", configs.work_path, tostring(ok), tostring(err))
    loader.loadRawIndex_()
    loader.loadCurrIndex_()
end

function loader.loadRawIndex_()
    utils.logFile("loader.loadRawIndex_()", INDEX_FILE_NAME)
    local content = json.decode(utils.readResFile(INDEX_FILE_NAME))
    if not content then
        utils.logFile("error: ", ERRORS.rawIndexReadFail)
        return
    end
    loader.indexInfoRaw_ = content
    return true
end

function loader.loadCurrIndex_()
    utils.logFile("loader.loadCurrIndex_()", loader.currIndexFilePath_)
    local content = utils.loadJsonFile(loader.currIndexFilePath_)
    if not content then
        return
    end
    loader.indexInfoCurr_ = content
    local currV = utils.checkint(loader.indexInfoCurr_.scriptVersion)
    local rawV = utils.checkint(loader.indexInfoRaw_.scriptVersion)
    if rawV >= currV then
        loader.indexInfoCurr_ = {}
        utils.removeFile(loader.currIndexFilePath_)
        utils.logFile("loader.loadCurrIndex_() rawV >= currV")
    end

    return true
end

function loader.getVersionURL_()
    utils.logFile("loader.getVersionURL_()")
    if loader.indexInfoCurr_ and loader.indexInfoCurr_.versionURL then
        return loader.indexInfoCurr_.versionURL
    end
    if loader.indexInfoRaw_ and loader.indexInfoRaw_.versionURL then
        return loader.indexInfoRaw_.versionURL
    end
end

function loader.checkNetwork_(handler)
    utils.logFile("loader.checkNetwork_")
    if network.isInternetConnectionAvailable() then
        return true
    end
    utils.logFile("before device.showAlert")
    device.showAlert("网络错误", "当前无可用的网络连接，请检查后再重试！", {"重试"}, function ()
        loader.update(handler)
    end)
    return false
end

function loader.setLoadEventHandler(handler)
    utils.logFile("loader.setLoadEventHandler(handler)")
    assert(handler)
    loader.updateHandler_ = handler
end

function loader.update()
    utils.logFile("loader.update()")
    loader.updateProgress_(1)
    if not loader.checkNetwork_(loader.updateHandler_) then
        utils.logFile("if not loader.checkNetwork_(handler) then")
        return
    end
    loader.startTime_ = os.time()
    
    if not device.isAndroid and not device.isIOS then
        return loader.endWithEvent_(EVENTS.fail, "LOADER NOT SUPPORT THIS PLATFORM.")
    end

    if not loader.indexInfoCurr_.scriptVersion and not loader.indexInfoRaw_.scriptVersion then
        return loader.endWithEvent_(EVENTS.fail, 'No version Info or not init!')
    end

    utils.removeFile(loader.newIndexFilePath_)
    loader.downVersion_()
end

function loader.endWithEvent_(event, ...)
    utils.logFile("loader.endWithEvent_", event, ...)
    loader.updateProgress_(100)
    if loader.indexInfoCurr_ and loader.indexInfoCurr_.scriptVersion then  -- 启用目录
        cc.FileUtils:getInstance():addSearchPath(loader.getCurrPath_(), true)
    end
    loader.updateHandler_(EVENTS[event], ...)
end

function loader.onSuccess_(sucType)
    utils.logFile("loader.onSuccess_: ", sucType)
    loader.updateProgress_(99)
    loader.endWithEvent_(EVENTS.success, sucType)
end

function loader.onFail_(message)
    utils.logFile("loader.onFail_: ", message)
    loader.updateHandler_(EVENTS.fail, message)
end

function loader.updateProgress_(percent)
    utils.logFile("loader.updateProgress_: ", percent)
    local totalFiles, finishFiles, totalSize, finishSize, inProgressSize = 0, 0, 0, 0, 0
    if percent == nil then
        totalFiles, finishFiles, totalSize, finishSize, inProgressSize, percent = 
            utils.calcDownloadProgress(loader.taskList_, TASK)
    end
    loader.updateHandler_(EVENTS.progress, totalFiles, finishFiles, totalSize, finishSize, inProgressSize, percent)
end

function loader.clean()
    utils.logFile("loader.clean")
end

-- 下载version.txt文件
function loader.downVersion_(url)
    utils.logFile("loader.downVersion_()", url)
    local url = (url or loader.getVersionURL_()) .. '?' .. os.time()
    utils.logFile("down url: ", url)
    if not url then
        return loader.endWithEvent_(EVENTS.fail, 'get Version URL fail')
    end
    
    local function failFunc()
        utils.logFile("download version fail", url)
        loader.updateProgress_(3)
        return loader.endWithEvent_(EVENTS.fail, 'download version fail')
    end
    
    local function sucFunc(data)
        utils.logFile("download version file success.", url)
        loader.updateProgress_(3)
        if not data or string.len(data or "") < 2 then
            failFunc()
            return
        end
        local result = json.decode(data)
        if not result or not result.scriptVersion or not result.mainVersion then
            return loader.endWithEvent_(EVENTS.fail, 'decode version file fail')
        end

        loader.versionInfoNew_ = result
        loader.checkVersionNumber_(result)
    end

    loader.updateProgress_(2)
    http.get(url, sucFunc, failFunc)
end

function loader.checkVersionNumber_(result)
    utils.logFile("loader.checkVersionNumber_")
    loader.updateProgress_(4)
    local newV = result.scriptVersion
    local currV = loader.indexInfoCurr_.scriptVersion
    local rawV = loader.indexInfoRaw_.scriptVersion
    utils.logFile("check version: ", tostring(newV), tostring(currV), tostring(rawV))

    if result.gameId ~= loader.indexInfoRaw_.gameId or 
        result.branchId ~= loader.indexInfoRaw_.branchId then
        utils.logFile("params check fail ")
        return loader.endWithEvent_(EVENTS.fail, 'PARAMS CHECK FAIL!')
    end

    if currV then
        if utils.isNew(newV, currV) then
            utils.logFile("goto downloadIndexFile_ by currV")
            loader.downloadIndexFile_(result)
            return
        end
    elseif utils.isNew(newV, rawV) then
        utils.logFile("goto downloadIndexFile_ by rawV")
        loader.downloadIndexFile_(result)
        return
    end

    return loader.onSuccess_(SUCCESS_TYPES.noNewVersion)
end

function loader.downloadIndexFile_(result)
    utils.logFile("loader.downloadIndexFile_(result)")
    loader.updateProgress_(5)
    local function failFunc()
        utils.logFile("download index fail")
        loader.updateProgress_(6)
        return loader.endWithEvent_(EVENTS.fail, 'download index file fail')
    end
    local function sucFunc(file)
        utils.logFile("download index suc", file)
        loader.updateProgress_(6)
        local data = utils.readFile(file)
        local indexNew = json.decode(data)
        if not indexNew or not indexNew.scriptVersion then
            return loader.endWithEvent_(EVENTS.fail, 'decode new index file fail')
        end

        loader.indexInfoNew_ = indexNew
        loader.calcDiffList_()
    end
    utils.logFile("before download index: ", loader.newIndexFilePath_, result.indexURL)
    http.download(result.indexURL .. '?' .. os.time(), loader.newIndexFilePath_, sucFunc, failFunc)
end

-- 判断给定的元素是否在项目包中已存在
function loader.inProject_(key, item)
    if not key or not item or not loader.indexInfoRaw_ then
        return false
    end
    if not loader.indexInfoRaw_.assets or not loader.indexInfoRaw_.assets[key] then
        return false
    end
    return loader.indexInfoRaw_.assets[key][2] == item[2]
end

function loader.getNewPath_()
    utils.logFile("loader.getNewPath_()")
    return configs.work_path .. loader.versionInfoNew_.scriptVersion .. '/'
end

function loader.getCurrPath_()
    utils.logFile("loader.getCurrPath_()")
    if not loader.indexInfoCurr_.scriptVersion then
        return configs.work_path .. loader.indexInfoRaw_.scriptVersion .. '/'
    end
    return configs.work_path .. loader.indexInfoCurr_.scriptVersion .. '/'
end

function loader.filterProjectFiles_(workList)
    utils.logFile("loader.filterProjectFiles_(workList)")
    if not workList then
        return {}
    end

    local list = {}
    for k,v in pairs(workList) do
        if not loader.inProject_(k, v) then
            list[k] = v
        end
    end
    return list
end

function loader.makeTaskList_(list)
    -- 返回结果为table, 每一项都由{文件路径, 文件大小, MD5, 任务状态, 失败次数, 已下载大小}构成
    local result = {}
    for k,v in pairs(list) do
        table.insert(result, {k, v[1], v[2], TASK.idle, 0, 0})
    end
    return result
end

function loader.calcDiffList_()
    utils.logFile("loader.calcDiffList_()")
    loader.updateProgress_(7)
    local currPath = loader.getCurrPath_()
    local newPath = loader.getNewPath_()
    utils.mkdir(newPath)  -- 创建新版的文件夹

    local diffList = loader.indexInfoNew_.assets
    utils.logFile("full assets: ", diffList)
    diffList = utils.filterFilesByPathAndList(newPath, diffList) -- 去除已下载成功的项
    diffList = utils.filterCopyedFiles(diffList, currPath, newPath) -- 去除从当前版中复制成功的项
    diffList = loader.filterProjectFiles_(diffList) -- 去除原版中已存在且相同的项
    utils.logFile("calc downlist: ", diffList)
    
    loader.taskList_ = loader.makeTaskList_(diffList)
    utils.logFile("calc task list: ", loader.taskList_)
    loader.updateProgress_()
end

function loader.setTaskState_(filePath, state, downloadSize)
    for _,v in pairs(loader.taskList_) do
        if v[1] == filePath then
            v[4] = state
            if state == TASK.progress then  -- 进行中则保存进度大小
                v[6] = downloadSize
            end
            if state == TASK.fail then  -- 失败则次数加1
                v[5] = v[5] + 1
            end
        end
    end
end

function loader.getResURL_(sign)
    return loader.versionInfoNew_.downloadURL .. sign
end

function loader.downloadResFile_(filePath, fileMetaData)
    utils.logFile("loader.downloadResFile_", filePath)
    local fileTotalSize, fileMD5 = fileMetaData[1], fileMetaData[2]
    local function failFunc()
        utils.logFile("download res fail!", filePath)
        loader.setTaskState_(filePath, TASK.fail, 0)
        loader.updateProgress_()  -- 更新进度
    end
    
    local function sucFunc(file)
        utils.logFile("download resfile suc: ", filePath)
        if crypto.md5file(file) ~= fileMD5 then  -- 下载的文件MD5不正确
            loader.setTaskState_(filePath, TASK.fail, 0)
            loader.updateProgress_()  -- 更新进度
            return
        end

        loader.setTaskState_(filePath, TASK.success, 0)
        loader.updateProgress_()  -- 更新进度
    end
    
    local function progressFunc(total, dltotal)
        if dltotal > 0 then
            loader.setTaskState_(filePath, TASK.progress, dltotal)
            loader.updateProgress_()  -- 更新进度
        end
    end

    local url = loader.getResURL_(fileMD5)
    local seconds = math.max(50, fileTotalSize / (10 * 1024))  -- 动态指定下载的超时时间，因为文件大小差异太大
    local filename = loader.getNewPath_() .. filePath
    local pinfo = utils.pathinfo(filename)
    utils.mkdir(pinfo.dirname, true)
    loader.setTaskState_(filePath, TASK.progress, 0)
    http.download(url, filename, sucFunc, failFunc, seconds, progressFunc)
end

-- 启用新版本的索引文件和版本文件
function loader.replaceCurrResFiles_()
    utils.logFile("loader.replaceCurrResFiles_()")
    if utils.writeFile(loader.currIndexFilePath_, utils.readFile(loader.newIndexFilePath_)) then
        utils.logFile("replaceCurrResFiles_ success")
        local path = loader.getCurrPath_()
        if utils.exists(path) then
            utils.logFile("delpath: ", path)
            utils.rmdir(path)
        end
        return true
    end

    return false
end

function loader.onDownloadFinish_(desc)
    utils.logFile("loader.onDownloadFinish_", desc, loader.taskList_)
    loader.updateProgress_(98)
    if loader.isFullSuccess_() then  -- 下载完成且没有失败的
        loader.replaceCurrResFiles_()
        loader.indexInfoCurr_ = loader.indexInfoNew_
        return loader.onSuccess_(SUCCESS_TYPES.updateSuccess)
    else
        return loader.endWithEvent_(EVENTS.fail, desc)
    end
end

function loader.isFullSuccess_()
    if nil == loader.taskList_ then
        return false
    end
    for _,v in pairs(loader.taskList_) do
        if v[4] ~= TASK.success then
            return false
        end
    end
    return true
end

function loader.onSchedule()
    if 0 == loader.startTime_ then  -- 没有网络还没开始
        return
    end
    if os.time() - loader.startTime_ > (configs.seconds or 5 * 60) then
        return loader.onDownloadFinish_("timeout")
    end
    if loader.isFullSuccess_() then
        return loader.onDownloadFinish_("isall finish")
    end
    if not loader.taskList_ then
        return
    end
    
    local taskCount = 0
    for k,v in pairs(loader.taskList_) do
        if #v ~= 6 then
            utils.logFile("unpack item fail: ", v)
            return loader.endWithEvent_(EVENTS.fail, "meta data error!")
        end
        local filePath, fileSize, fileMD5, fileState, failCount, downloadSize = unpack(v)
        if fileState == TASK.progress then
            taskCount = taskCount + 1
        end
        if fileState == TASK.fail and failCount > 5 then
            utils.logFile("too many fail count: ", filePath, failCount)
            return loader.endWithEvent_(EVENTS.fail, "too many fail count")
        end
        if taskCount >= DOWNLOAD_THREADS then
            utils.logFile("running task count rather than DOWNLOAD_THREADS", taskCount, DOWNLOAD_THREADS)
            return
        end
    end

    for k,v in pairs(loader.taskList_) do
        local filePath, fileSize, fileMD5, fileState, failCount, downloadSize = unpack(v)
        if fileState == TASK.idle or fileState == TASK.fail then
            loader.setTaskState_(filePath, TASK.progress, 0)
            loader.downloadResFile_(filePath, {fileSize, fileMD5})
            taskCount = taskCount + 1
        end
        if taskCount > DOWNLOAD_THREADS then
            break
        end
    end
end

return loader
