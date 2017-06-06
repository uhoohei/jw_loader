local json = require("loader.json")
local http = require("loader.http")
local crypto = require("loader.crypto")
local device = require("loader.device")
local network = require("loader.network")
local scheduler = require("loader.scheduler")
local utils = require("loader.utils")

local print_r = utils.print_r
local checkint = utils.checkint
local exists = utils.exists
local writeFile = utils.writeFile
local logFile = utils.logFile
local removeFile = utils.removeFile
local renameFile = utils.renameFile
local rmdir = utils.rmdir
local readFile = utils.readFile
local copyFile = utils.copyFile
local mkdir = utils.mkdir
local loadJsonFile = utils.loadJsonFile
local tableCount = utils.tableCount
local readResFile = utils.readResFile

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

--------------------------------- CONFIG START -------------------------------
-- 下载版本文件，对比检查，下载资源索引文件，检验索引文件，
-- 分析需要下载的文件，下载并检验文件，替换当前版本，更新结束。
local STATES = {
    init = 'init',
    start = "start",
    downVersion = "downVersion",
    downVersionEnd = "downVersionEnd",
    downIndex = "downIndex",
    downIndexEnd = "downIndexEnd",
    downFiles = "downFiles",
    downFilesEnd = "downFilesEnd",
    isEnd = "end",
}

local EVENTS = {
    success = 'success',
    fail = 'fail',
    progress = 'progress',
    state = 'state',
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

local versionInfoNew = {}  -- 新下载的版本信息
local indexInfoCurr = {}  -- 当前版的文件索引信息，可参考resindex.txt文件
local indexInfoRaw = {}  -- 原包里面的索引信息
local indexInfoNew = {}  -- 新下载的索引文件的信息
local downloadList = {}  -- 总下载任务队列
local downFailList = {}  -- 下载失败的文件队列

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
local UPDATE_PACKAGE_INDEX = "loader%s.zip"  -- 更新包的索引名称, 这里是为了能更新自身而放在这里的
local DOWNLOAD_THREADS = 4  -- 同时下载的任务数
local DOWNLOAD_SCHEDULER = nil  -- 下载的定时器
local DOWNLOAD_TASK_RUNNING = 0  -- 正在进行的下载数量
--------------------------------- CONFIG END ---------------------------------


local loader = {}

loader.state_ = nil
loader.doingList_ = {}
loader.startTime_ = 0

-- 当前有效的索引文件
function loader.indexFileOfCurr()
    return updater.work_path .. INDEX_FILE_NAME .. CURRENT_SUFFIX
end

-- 新版的工程索引文件
function loader.indexFileOfNew()
    return updater.work_path .. INDEX_FILE_NAME .. NEW_SUFFIX
end

function loader.init(zip64)
    local str64 = zip64 or ""
    UPDATE_PACKAGE_INDEX = string.format(UPDATE_PACKAGE_INDEX, zip64)
    logFile('loader.init')
    if nil ~= loader.state_ then
        logFile('loader.init fail with nil state')
        return
    end
    logFile(updater.work_path)

    local ok, err = mkdir(updater.work_path, true)
    logFile(tostring(ok))
    logFile(tostring(err))
    
    loader.setState_(STATES.init)
    loader.loadRawIndex_()
    loader.loadCurrIndex_()
end

function loader.loadRawIndex_()
    logFile("loader.loadRawIndex_()", INDEX_FILE_NAME)
    local content = json.decode(readResFile(INDEX_FILE_NAME))
    if not content then
        logFile("error: ", ERRORS.rawIndexReadFail)
        return
    end
    indexInfoRaw = content
    return true
end

function loader.loadCurrIndex_()
    logFile("loader.loadCurrIndex_()", loader.indexFileOfCurr())
    local content = loadJsonFile(loader.indexFileOfCurr())
    if not content then
        return
    end
    indexInfoCurr = content
    local currV = checkint(indexInfoCurr.scriptVersion)
    local rawV = checkint(indexInfoRaw.scriptVersion)
    if rawV >= currV then
        indexInfoCurr = {}
        removeFile(loader.indexFileOfCurr())
        logFile("loader.loadCurrIndex_() rawV >= currV")
    end

    return true
end

-- 从给定的文件路径来寻找对应的当前版的完整路径
-- 如果找到，那么对应的路径为 更新目录/版本目录/此文件的子路径值
function loader.getCurrPathByIndex(index)
    assert(index)
    if not indexInfoCurr or not indexInfoCurr.assets then
        return
    end
    if not indexInfoCurr.assets[index] then
        return
    end
    return updater.work_path .. indexInfoCurr.scriptVersion .. '/' .. index
end

-- 获得当前版中的资源的路径，如果资源不存在，或者资源与原版的一致，则返回空
function loader.checkCurrPathByIndex(index)
    local currSign = loader.getCurrSignByIndex(index)
    if not currSign then
        return
    end
    local rawSign = loader.getRawSignByIndex(index)
    if currSign == rawSign then  -- 两个版本一样，返回空
        return
    end
    local path = loader.getCurrPathByIndex(index)
    if path and exists(path) then
        return path
    end
end

-- 获得当前版的签名数据
function loader.getCurrSignByIndex(index)
    if not indexInfoCurr or not indexInfoCurr.assets then
        return
    end
    return indexInfoCurr.assets[index][2]
end

-- 获得原版的签名数据
function loader.getRawSignByIndex(index)
    if not indexInfoRaw or not indexInfoRaw.assets then
        return
    end
    return indexInfoRaw.assets[index][2]
end

function loader.hasNewUpdatePackage()
    return loader.checkCurrPathByIndex(UPDATE_PACKAGE_INDEX)
end

function loader.setState_(state)
    assert(state)
    loader.state_ = state
    loader.onState_(state)
end

function loader.getVersionURL_()
    if indexInfoCurr and indexInfoCurr.versionURL then
        return indexInfoCurr.versionURL
    end
    if indexInfoRaw and indexInfoRaw.versionURL then
        return indexInfoRaw.versionURL
    end
end

function loader.checkNetwork_(handler)
    logFile("loader.checkNetwork_")
    if network.isInternetConnectionAvailable() then
        return true
    end
    logFile("before device.showAlert")
    device.showAlert("网络错误", "当前无可用的网络连接，请检查后再重试！", {"重试"}, function ()
        loader.update(handler)
    end)
    return false
end

function loader.update(handler)
    logFile("loader.update(handler)")
    assert(handler)
    if not loader.checkNetwork_(handler) then
        logFile("if not loader.checkNetwork_(handler) then")
        return
    end
    if loader.state_ ~= STATES.init and loader.state_ ~= STATES.isEnd then
        return
    end
    loader.startTime_ = os.time()
    loader.doingList_ = {}
    downloadList = {}  -- 清空下载列表
    loader.updateHandler_ = handler
    loader.setState_(STATES.start)

    if not device.isAndroid and not device.isIOS then
        return loader.endWithEvent_(EVENTS.fail, "LOADER NOT SUPPORT THIS PLATFORM.")
    end
    if not indexInfoCurr.scriptVersion and not indexInfoRaw.scriptVersion then
        return loader.endWithEvent_(EVENTS.fail, 'No version Info or not init!')
    end

    removeFile(loader.indexFileOfNew())

    loader.setState_(STATES.downVersion)
    loader.onProgress_(0)
    loader.downVersion_()
end

function loader.endWithEvent_(event, ...)
    logFile("loader.endWithEvent_", event, ...)
    loader.onProgress_(100)
    if indexInfoCurr and indexInfoCurr.scriptVersion then  -- 启用目录
        cc.FileUtils:getInstance():addSearchPath(loader.getCurrPath_(), true)
    end
    loader.stopCheckScheduler_()
    loader.setState_(STATES.isEnd)
    loader.updateHandler_(EVENTS[event], ...)
end

function loader.onSuccess_(sucType)
    logFile("loader.onSuccess_: ", sucType)
    loader.endWithEvent_(EVENTS.success, sucType)
end

function loader.onFail_(message)
    logFile("loader.onFail_: ", message)
    loader.updateHandler_(EVENTS.fail, message)
end

function loader.onProgress_(percent)
    logFile("loader.onProgress_: ", percent)
    loader.updateHandler_(EVENTS.progress, percent)
end

function loader.onState_(state)
    logFile("loader.onState_: ", state)
    if loader.updateHandler_ then
        loader.updateHandler_(EVENTS.state, state)
    end
end

function loader.clean()
    logFile("loader.clean")
    loader.stopCheckScheduler_()
    loader.state_ = nil
    indexInfoCurr = {}
    indexInfoRaw = {}
    indexInfoNew = {}
    loader.doingList_ = {}
end

-- 下载version.txt文件
function loader.downVersion_(url)
    logFile("loader.downVersion_()", url)
    assert(loader.state_ == STATES.downVersion)
    local url = (url or loader.getVersionURL_()) .. '?' .. os.time()
    logFile("down url: ", url)
    if not url then
        return loader.endWithEvent_(EVENTS.fail, 'get Version URL fail')
    end
    
    local function failFunc()
        logFile("download version fail")
        loader.setState_(STATES.downVersionEnd)
        return loader.endWithEvent_(EVENTS.fail, 'download version fail')
    end
    
    local function sucFunc(data)
        logFile("download version file success.")
        if not data or string.len(data) < 2 then
            failFunc()
            return
        end
        loader.setState_(STATES.downVersionEnd)
        local result = json.decode(data)
        if not result or not result.scriptVersion or not result.mainVersion then
            return loader.endWithEvent_(EVENTS.fail, 'decode version file fail')
        end

        versionInfoNew = result
        loader.checkVersionNumber_(result)
    end

    http.get(url, sucFunc, failFunc)
end

local function isNew__(newV, compV)
    return checkint(newV) > checkint(compV)
end

function loader.checkVersionNumber_(result)
    logFile("loader.checkVersionNumber_")
    local newV = result.scriptVersion
    local currV = indexInfoCurr.scriptVersion
    local rawV = indexInfoRaw.scriptVersion
    logFile("check version: ", tostring(newV), tostring(currV), tostring(rawV))

    if result.mainVersion ~= indexInfoRaw.mainVersion then  -- 大版本不一致，直接返回
        logFile("mainVersion not equal ", tostring(result.mainVersion), tostring(indexInfoRaw.mainVersion))
        return loader.endWithEvent_(EVENTS.fail, 'MAIN VERSION IS NOT EQUAL!')
    end

    if result.gameId ~= indexInfoRaw.gameId or 
        result.branchId ~= indexInfoRaw.branchId then
        logFile("params check fail ")
        return loader.endWithEvent_(EVENTS.fail, 'PARAMS CHECK FAIL!')
    end

    if currV then
        if isNew__(newV, currV) then
            logFile("goto downloadIndexFile_ by currV")
            loader.downloadIndexFile_(result)
            return
        end
    elseif isNew__(newV, rawV) then
        logFile("goto downloadIndexFile_ by rawV")
        loader.downloadIndexFile_(result)
        return
    end

    return loader.onSuccess_(SUCCESS_TYPES.noNewVersion)
end

function loader.downloadIndexFile_(result)
    logFile("loader.downloadIndexFile_(result)")
    assert(loader.state_ == STATES.downVersionEnd)
    loader.setState_(STATES.downIndex)
    local function failFunc()
        logFile("download index fail")
        loader.setState_(STATES.downIndexEnd)
        return loader.endWithEvent_(EVENTS.fail, 'download index file fail')
    end
    local function sucFunc(file)
        logFile("download index suc", file)
        loader.setState_(STATES.downIndexEnd)
        if crypto.md5file(file) ~= result.indexSign then
            return loader.endWithEvent_(EVENTS.fail, 'check new index file sign fail')
        end

        local data = readFile(file)
        local indexNew = json.decode(data)
        if not indexNew or not indexNew.scriptVersion then
            return loader.endWithEvent_(EVENTS.fail, 'decode new index file fail')
        end

        indexInfoNew = indexNew
        loader.setState_(STATES.downIndexEnd)
        loader.downloadFiles_()
    end
    logFile("before download index: ", loader.indexFileOfNew(), result.indexURL)
    http.download(result.indexURL .. '?' .. os.time(), loader.indexFileOfNew(), sucFunc, failFunc)
end

-- 判断给定的元素是否在项目包中已存在
function loader.inProject_(key, item)
    if not key or not item or not indexInfoRaw then
        return false
    end
    if not indexInfoRaw.assets or not indexInfoRaw.assets[key] then
        return false
    end
    return indexInfoRaw.assets[key][2] == item[2]
end

-- 比对给定的列表与本地文件
-- 如果本地文件存在，且文件的MD5值相等，则跳过对应文件
-- 反之将错误的本地文件删除，并放进列表
function loader.filterFilesByPathAndList_(newPath, workList)
    local list = {}
    for k,v in pairs(workList) do
        local filename = newPath .. k
        if not exists(filename) then
            list[k] = v
        elseif crypto.md5file(filename) ~= v[2] then
            removeFile(filename)
            list[k] = v
        end
    end
    return list
end

function loader.getNewPath_()
    return updater.work_path .. versionInfoNew.scriptVersion .. '/'
end

function loader.getCurrPath_()
    if not indexInfoCurr.scriptVersion then
        return updater.work_path .. indexInfoRaw.scriptVersion .. '/'
    end
    return updater.work_path .. indexInfoCurr.scriptVersion .. '/'
end

function loader.filterCopyedFiles_(workList, currPath, newPath)
    local list = {}
    for k,v in pairs(workList) do
        local from = currPath .. k
        local to = newPath .. k
        if not utils.exists(from) or crypto.md5file(from) ~= v[2] then
            list[k] = v
        else
            local pinfo = utils.pathinfo(to)
            mkdir(pinfo.dirname, true)
            if not copyFile(from, to) then  -- 复制失败，加入列表
                list[k] = v
            elseif crypto.md5file(to) ~= v[2] then  -- 文件签名不正确，加入列表
                list[k] = v
                removeFile(to)
            end
        end
    end
    return list
end

function loader.filterProjectFiles_(workList)
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

function loader.downloadFiles_()
    logFile("loader.downloadFiles_()")
    assert(loader.state_ == STATES.downIndexEnd)
    loader.setState_(STATES.downFiles)

    local currPath = loader.getCurrPath_()
    local newPath = loader.getNewPath_()
    mkdir(newPath)  -- 创建新版的文件夹

    local downList_ = indexInfoNew.assets
    downList_ = loader.filterFilesByPathAndList_(newPath, downList_) -- 去除已下载成功的项
    downList_ = loader.filterCopyedFiles_(downList_, currPath, newPath) -- 去除从当前版中复制成功的项
    downList_ = loader.filterProjectFiles_(downList_) -- 去除原版中已存在且相同的项

    logFile("==============================================111")
    logFile("calc downlist: ", json.encode(downList_))
    
    downloadList = downList_
    downFailList = {}
    
    loader.downloadedSize_ = 0
    loader.downloadedCount_ = 0
    loader.totalSize_, loader.totalCount_ = loader.calcSizeAndCount_(downList_)
    loader.onProgress_(loader.calcDownloadProgress_())
    
    DOWNLOAD_TASK_RUNNING = 0

    if kCCNetworkStatusReachableViaWWAN == network.getInternetConnectionStatus() and 
        loader.totalSize_ > updater.slient_size then   -- 数据网络下的提示下载
        local desc = versionInfoNew.desc or "发现新的资源包需要下载，建议您立即下载。"
        desc = desc .. string.format("\n大小：%sM", string.format("%0.1f", loader.totalSize_ / 1024 / 1024))
        device.showAlert("温馨提示", desc, {"取消", "下载"}, function (event)
            if event.buttonIndex == 1 then  -- 取消
                return loader.endWithEvent_(EVENTS.fail, "user cancel in WWAN.")
            else -- 下载
                loader.startCheckScheduler_()
            end
        end)
        return
    end
    loader.startCheckScheduler_()
end

function loader.calcDownloadProgress_()
    if loader.totalSize_ <= 0 then
        return 100
    end
    return math.ceil((loader.downloadedSize_ / loader.totalSize_) * 100)
end

function loader.calcSizeAndCount_(list)
    local size, count = 0, 0
    for k,v in pairs(list) do
        size = size + v[1]
        count = count + 1
    end
    return size, count
end

function loader.startCheckScheduler_()
    logFile("loader.startCheckScheduler_()")
    if not DOWNLOAD_SCHEDULER then
        DOWNLOAD_SCHEDULER = scheduler.scheduleGlobal(loader.checkDownload_, 0.1)
    end
end

function loader.stopCheckScheduler_()
    logFile("loader.stopCheckScheduler_()")
    if DOWNLOAD_SCHEDULER then
        scheduler.unscheduleGlobal(DOWNLOAD_SCHEDULER)
        DOWNLOAD_SCHEDULER = nil
    end
end

function loader.incrDownloadedSize_(size)
    loader.downloadedSize_ = loader.downloadedSize_ + size
end

function loader.getResURL_(sign)
    return versionInfoNew.downloadURL .. sign
end

function loader.downloadResFile_(filePath, fileMetaData)
    logFile("loader.downloadResFile_", filePath)
    assert(filePath and fileMetaData)
    local fileTotalSize, fileMD5 = fileMetaData[1], fileMetaData[2]
    
    local function failFunc()
        logFile("download res fail!", filePath)
        loader.doingList_[filePath] = nil
        DOWNLOAD_TASK_RUNNING = DOWNLOAD_TASK_RUNNING - 1
        downFailList[filePath] = fileMetaData
    end
    
    local lastDownSize = 0
    local function sucFunc(file)
        logFile("download resfile suc: ", filePath)
        loader.doingList_[filePath] = nil
        DOWNLOAD_TASK_RUNNING = DOWNLOAD_TASK_RUNNING - 1
        if crypto.md5file(file) ~= fileMD5 then  -- 下载的文件MD5不正确
            downFailList[filePath] = fileMetaData
            return
        end

        loader.incrDownloadedSize_(fileTotalSize - lastDownSize)  -- 累加下载大小
        loader.downloadedCount_ = loader.downloadedCount_ + 1
        loader.onProgress_(loader.calcDownloadProgress_())  -- 通知总下载进度
    end
    
    local function progressFunc(total, dltotal)
        if total > 0 then
            fileTotalSize = total
        end
        if dltotal > 0 then
            loader.incrDownloadedSize_(dltotal - lastDownSize)  -- 累加下载大小
            lastDownSize = dltotal
            loader.onProgress_(loader.calcDownloadProgress_())  -- 通知总下载进度
        end
    end

    local url = loader.getResURL_(fileMD5)
    local seconds = math.max(10, fileTotalSize / (10 * 1024))  -- 动态指定下载的超时时间，因为文件大小差异太大
    local filename = loader.getNewPath_() .. filePath
    local pinfo = utils.pathinfo(filename)
    mkdir(pinfo.dirname, true)
    http.download(url, filename, sucFunc, failFunc, seconds, progressFunc)
end

-- 启用新版本的索引文件和版本文件
function loader.overWriteCurrFiles_()
    logFile("loader.overWriteCurrFiles_()")
    if writeFile(loader.indexFileOfCurr(), readFile(loader.indexFileOfNew())) then
        logFile("overWriteCurrFiles_ success")
        local path = loader.getCurrPath_()
        if exists(path) then
            logFile("delpath: ", path)
            rmdir(path)
        end
        return true
    end

    return false
end

function loader.onDownloadFinish_(desc)
    logFile("loader.onDownloadFinish_", desc)
    loader.setState_(STATES.downFilesEnd)
    if tableCount(downFailList) == 0 then  -- 下载完成且没有失败的
        loader.overWriteCurrFiles_()
        indexInfoCurr = indexInfoNew
        return loader.onSuccess_(SUCCESS_TYPES.updateSuccess)
    else
        return loader.endWithEvent_(EVENTS.fail, ERRORS.unknown)
    end
end

function loader.isFinish_()
    return 0 == tableCount(downloadList) and 0 == tableCount(loader.doingList_)
end

function loader.checkDownload_()
    if loader.isFinish_() then
        return loader.onDownloadFinish_("isall finish")
    end
    if loader.downloadedCount_ > 5000 then
        return loader.onDownloadFinish_("download times too much")
    end
    if os.time() - loader.startTime_ > (updater.seconds or 5 * 60) then
        return loader.onDownloadFinish_("timeout")
    end
    
    local list = {}
    for k,v in pairs(downloadList) do
        loader.doingList_[k] = true  -- 记录正在执行，在下载结束的时候要置为false
        loader.downloadResFile_(k, v)
        table.insert(list, k)
        DOWNLOAD_TASK_RUNNING = DOWNLOAD_TASK_RUNNING + 1
        if DOWNLOAD_TASK_RUNNING >= DOWNLOAD_THREADS then
            break
        end
    end

    for _,v in ipairs(list) do  -- 从下载队伍中去除执行中的下载任务
        downloadList[v] = nil
    end
end

return loader
