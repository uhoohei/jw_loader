require "lfs"
local device = require("loader.device")
local json = require("loader.json")
local crypto = require("loader.crypto")

local print = print
local tconcat = table.concat
local tinsert = table.insert
local srep = string.rep
local type = type
local pairs = pairs
local tostring = tostring
local next = next

local utils = {}
function utils.print_r(root)
    local cache = {  [root] = "." }
    local function _dump(t,space,name)
        local temp = {}
        for k,v in pairs(t) do
            local key = tostring(k)
            if cache[v] then
                tinsert(temp,"+" .. key .. " {" .. cache[v].."}")
            elseif type(v) == "table" then
                local new_key = name .. "." .. key
                cache[v] = new_key
                tinsert(temp,"+" .. key .. _dump(v,space .. (next(t,k) and "|" or " " ).. srep(" ",#key),new_key))
            else
                tinsert(temp,"+" .. key .. " [" .. tostring(v).."]")
            end
        end
        return tconcat(temp,"\n"..space)
    end
    print(_dump(root, "",""))
end

function utils.stringSplit(input, delimiter)
    local input = tostring(input)
    local delimiter = tostring(delimiter)
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

function utils.checknumber(value, base)
    return tonumber(value, base) or 0
end

function utils.mathRound(value)
    value = utils.checknumber(value)
    return math.floor(value + 0.5)
end

function utils.checkint(value)
    return utils.mathRound(utils.checknumber(value))
end

function utils.exists(path)
    local file = io.open(path, "r")
    if file then
        io.close(file)
        return true
    end
    return false
end

function utils.fileSize(path)
    local size = 0
    local file = io.open(path, "r")
    if file then
        local current = file:seek()
        size = file:seek("end")
        file:seek("set", current)
        io.close(file)
    end
    return size
end

function utils.doWriteFile(path, content, mode)
    local mode = mode or "w+b"
    local file = io.open(path, mode)
    if file then
        if file:write(content) == nil then return false end
        io.close(file)
        return true
    else
        return false
    end
end

function utils.writeFile(path, content, mode)
    utils.logFile("utils.writeFile", path, string.len(content or ""), mode)
    return utils.doWriteFile(path, content, mode)
end

local function getLogFileName()
    local path =  device.getSDCardPath()
    return path .. '/jw_loader' .. GAME_ID .. ".txt"
end

function utils.logFile(...)
    local str = json.encode({os.time(), ...})
    print(str)
    utils.doWriteFile(getLogFileName(), str .. "\n", 'a+b')
end

function utils.removeLogFile(keepSize)
    local filePath = getLogFileName()
    if keepSize and keepSize > 0 then
        if utils.fileSize(filePath) < keepSize then
            utils.logFile("removeLogFile return by keepSize ", keepSize)
            return
        end
    end
    utils.removeFile(filePath)
end

function utils.removeFile(path)
    local succ, des = os.remove(path)
    if des then
        utils.logFile(des)
    end
    return succ
end

function utils.renameFile(oldname, newname)
    local flag, desc = os.rename(oldname, newname)
    if not flag then
        utils.logFile(desc)
        return false
    end
    return true
end

local function __rmdir(path)
    local iter, dir_obj = lfs.dir(path)
    while true do
        local dir = iter(dir_obj)
        if dir == nil then break end
        if dir ~= "." and dir ~= ".." then
            local curDir = path .. dir
            local mode = lfs.attributes(curDir, "mode")
            if mode == "directory" then
                __rmdir(curDir .. "/")
            elseif mode == "file" then
                os.remove(curDir)
            end
        end
    end
    local succ, des = os.remove(path)
    if des then
        utils.logFile(des)
    end
    return succ
end

function utils.rmdir(path)
    if utils.exists(path) then
        __rmdir(path)
    end
    return true
end

function utils.readFile(path)
    utils.logFile("utils.readFile", path)
    local file, errors = io.open(path, "r")
    if file then
        local content = file:read("*a")
        io.close(file)
        return content
    end
    return nil
end

function utils.copyFile(from, to, mode)
    utils.logFile("utils.copyFile", from, to, mode)
    if not utils.exists(from) then
        return false
    end
    return utils.writeFile(to, utils.readFile(from), mode)
end

function utils.mkdir(path, r)
    if utils.exists(path) then
        return true
    end
    if not r then
        return lfs.mkdir(path)
    end
    local arr = utils.stringSplit(path, '/')
    if not arr then
        return false
    end
    local rPath = '/'
    local ok, err = false, nil
    for i,v in ipairs(arr) do
        if string.len(v or "") > 0 then
            rPath = rPath .. v .. '/'
            ok, err = utils.mkdir(rPath)
        end
    end
    return ok
end

function utils.loadJsonFile(filePath)
    local text = utils.readFile(filePath)
    if not text then
        return
    end
    local content = json.decode(text)
    if not content then
        return
    end
    return content
end

function utils.tableCount(tbl)
    if type(tbl) ~= 'table' then
        return 0
    end
    local count = 0
    for _,v in pairs(tbl) do
        count = count + 1
    end
    return count
end

function utils.readResFile(path)
    return cc.FileUtils:getInstance():getDataFromFile(path)
end

-- 来自框架中的 io.pathinfo 函数
function utils.pathinfo(path)
    local pos = string.len(path or "")
    local extpos = pos + 1
    while pos > 0 do
        local b = string.byte(path, pos)
        if b == 46 then -- 46 = char "."
            extpos = pos
        elseif b == 47 then -- 47 = char "/"
            break
        end
        pos = pos - 1
    end

    local dirname = string.sub(path, 1, pos)
    local filename = string.sub(path, pos + 1)
    extpos = extpos - pos
    local basename = string.sub(filename, 1, extpos - 1)
    local extname = string.sub(filename, extpos)
    return {
        dirname = dirname,
        filename = filename,
        basename = basename,
        extname = extname
    }
end

function utils.isNew(newV, compV)
    return utils.checkint(newV) > utils.checkint(compV)
end

-- 比对给定的列表与本地文件
-- 如果本地文件存在，且文件的MD5值相等，则跳过对应文件
-- 反之将错误的本地文件删除，并放进列表
function utils.filterFilesByPathAndList(newPath, workList)
    utils.logFile("utils.filterFilesByPathAndList", newPath)
    local list = {}
    for k,v in pairs(workList) do
        local filename = newPath .. k
        if not utils.exists(filename) then
            list[k] = v
        elseif crypto.md5file(filename) ~= v[2] then
            utils.removeFile(filename)
            list[k] = v
        end
    end
    return list
end

function utils.filterCopyedFiles(workList, currPath, newPath)
    utils.logFile("utils.filterCopyedFiles", currPath, newPath)
    local list = {}
    for k,v in pairs(workList) do
        local from = currPath .. k
        local to = newPath .. k
        if not utils.exists(from) or crypto.md5file(from) ~= v[2] then
            list[k] = v
        else
            local pinfo = utils.pathinfo(to)
            utils.mkdir(pinfo.dirname, true)
            if not utils.copyFile(from, to) then  -- 复制失败，加入列表
                list[k] = v
            elseif crypto.md5file(to) ~= v[2] then  -- 文件签名不正确，加入列表
                list[k] = v
                utils.removeFile(to)
            end
        end
    end
    return list
end

function utils.calcDownloadProgress(taskList, TASK)
    local taskList = taskList or {}
    utils.logFile("utils.calcDownloadProgress()")
    -- 总文件数, 下载成功的文件数, 总大小, 已完成的大小, 下载中的大小
    local totalFiles, finishFiles, totalSize, finishSize, inProgressSize = 0, 0, 1, 0, 0
    for _,v in pairs(taskList) do
        if #v ~= 6 then
            break
        end
        local filePath, fileSize, fileMD5, fileState, failCount, downloadSize = unpack(v)
        totalFiles = totalFiles + 1
        totalSize = totalSize + fileSize
        if fileState == TASK.success then
            finishFiles = finishFiles + 1
            finishSize = finishSize + fileSize
        elseif fileState == TASK.progress then
            inProgressSize = inProgressSize + downloadSize
        end
    end
    local percent = 7 + math.ceil(math.min(90, (finishSize + inProgressSize) / totalSize * 0.9 * 100))
    utils.logFile("after calcDownloadProgress: ", totalFiles, finishFiles, totalSize, finishSize, inProgressSize, percent)
    return totalFiles, finishFiles, totalSize, finishSize, inProgressSize, percent
end

return utils
