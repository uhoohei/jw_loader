require "lfs"
local device = require("loader.device")
local json = require("loader.json")

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
    utils.logFile("utils.writeFile", path, string.len(content), mode)
    return utils.doWriteFile(path, content, mode)
end

local function getLogFileName()
    local path = device.writablePath
    return path .. "/jw_loader.txt"
end

function utils.logFile(...)
    local str = json.encode({...})
    print(str)
    utils.doWriteFile(getLogFileName(), str .. "\n", 'a+b')
end

function utils.removeLogFile()
    utils.removeFile(getLogFileName())
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
        if string.len(v) > 0 then
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
    local pos = string.len(path)
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

return utils
