local crypto = {}

function crypto.md5file(path)
    if not path then
        print("crypto.md5file() - invalid filename")
        return nil
    end
    path = tostring(path)
    return cc.Crypto:MD5File(path)
end

return crypto
