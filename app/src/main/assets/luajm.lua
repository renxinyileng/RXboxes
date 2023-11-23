local function encode(str)
    local len = string.len(str)
    local ret = ""
    for i = 1, len do
        local char = string.sub(str, i, i)
        local ascii = string.byte(char)
        local newAscii = ascii + 10
        local newChar = string.char(newAscii)
        ret = ret .. newChar
    end
    return ret
end

local function decode(str)
    local len = string.len(str)
    local ret = ""
    for i = 1, len do
        local char = string.sub(str, i, i)
        local ascii = string.byte(char)
        local newAscii = ascii - 10
        local newChar = string.char(newAscii)
        ret = ret .. newChar
    end
    return ret
end

local function obfuscate(code)
    local encoded = encode(code)
    local obfuscated = string.reverse(encoded)
    return obfuscated
end

local function deobfuscate(code)
    local reversed = string.reverse(code)
    local decoded = decode(reversed)
    return decoded
end

local function test()
    local code = [[
        print("Hello, world!")
    ]]
    local obfuscated = obfuscate(code)
    print(obfuscated)
    local deobfuscated = deobfuscate(obfuscated)
    print(deobfuscated)
end

-- 定义一个函数，用于将字符串进行加密
local function encode(str)
    local len = string.len(str) -- 获取字符串长度
    local ret = "" -- 定义一个空字符串
    for i = 1, len do -- 循环遍历字符串
        local char = string.sub(str, i, i) -- 获取字符串中的单个字符
        local ascii = string.byte(char) -- 获取字符的 ASCII 码值
        local newAscii = ascii + 10 -- 将 ASCII 码值加上 10
        local newChar = string.char(newAscii) -- 将新的 ASCII 码值转换为字符
        ret = ret .. newChar -- 将新的字符添加到结果字符串中
    end
    return ret -- 返回加密后的字符串
end

-- 定义一个函数，用于将字符串进行解密
local function decode(str)
    local len = string.len(str) -- 获取字符串长度
    local ret = "" -- 定义一个空字符串
    for i = 1, len do -- 循环遍历字符串
        local char = string.sub(str, i, i) -- 获取字符串中的单个字符
        local ascii = string.byte(char) -- 获取字符的 ASCII 码值
        local newAscii = ascii - 10 -- 将 ASCII 码值减去 10
        local newChar = string.char(newAscii) -- 将新的 ASCII 码值转换为字符
        ret = ret .. newChar -- 将新的字符添加到结果字符串中
    end
    return ret -- 返回解密后的字符串
end

-- 定义一个函数，用于将 Lua 代码进行混淆
local function obfuscate(code)
    local encoded = encode(code) -- 对代码进行加密
    local obfuscated = string.reverse(encoded) -- 将加密后的字符串反转
    return obfuscated -- 返回混淆后的代码
end

-- 定义一个函数，用于将混淆后的 Lua 代码进行解混淆
local function deobfuscate(code)
    local reversed = string.reverse(code) -- 将混淆后的代码反转
    local decoded =    decode(reversed) -- 对反转后的字符串进行解密
local function encode(str)
    local len = string.len(str)
    local ret = ""
    for i = 1, len do
        local char = string.sub(str, i, i)
        local ascii = string.byte(char)
        local newAscii = ascii + 10
        local newChar = string.char(newAscii)
        ret = ret .. newChar
    end
    return ret
end

local function decode(str)
    local len = string.len(str)
    local ret = ""
    for i = 1, len do
        local char = string.sub(str, i, i)
        local ascii = string.byte(char)
        local newAscii = ascii - 10
        local newChar = string.char(newAscii)
        ret = ret .. newChar
    end
    return ret
end

local function obfuscate(code)
    local encoded = encode(code)
    local obfuscated = string.reverse(encoded)
    return obfuscated
end

local function deobfuscate(code)
    local reversed = string.reverse(code)
    local decoded =
    decode(reversed) -- 对反转后的字符串进行解密
    return decoded
end

local function test()
    local code = [[
        print("Hello, world!")
    ]]
    local obfuscated = obfuscate(code)
    print(obfuscated)
    local deobfuscated = deobfuscate(obfuscated)
    print(deobfuscated)
end

test()
-- 定义一个函数，用于将字符串进行加密
local function encode(str)
    local len = string.len(str) -- 获取字符串长度
    local ret = "" -- 定义一个空字符串
    for i = 1, len do -- 循环遍历字符串
        local char = string.sub(str, i, i) -- 获取字符串中的单个字符
        local ascii = string.byte(char) -- 获取字符的 ASCII 码值
        local newAscii = ascii + 10 -- 将 ASCII 码值加上 10
        local newChar = string.char(newAscii) -- 将新的 ASCII 码值转换为字符
        ret = ret .. newChar -- 将新的        字符添加到结果字符串中
    end
    return ret -- 返回加密后的字符串
end

-- 定义一个函数，用于将字符串进行解密
local function decode(str)
    local len = string.len(str) -- 获取字符串长度
    local ret = "" -- 定义一个空字符串
    for i = 1, len do -- 循环遍历字符串
        local char = string.sub(str, i, i) -- 获取字符串中的单个字符
        local ascii = string.byte(char) -- 获取字符的 ASCII 码值
        local newAscii = ascii - 10 -- 将 ASCII 码值减去 10
        local newChar = string.char(newAscii) -- 将新的 ASCII 码值转换为字符
        ret = ret .. newChar -- 将新的字符添加到结果字符串中
    end
    return ret -- 返回解密后的字符串
end

-- 定义一个函数，用于将 Lua 代码进行混淆
local function obfuscate(code)
    local encoded = encode(code) -- 对代码进行加密
    local obfuscated = string.reverse(encoded) -- 将加密后的字符串反转
    return obfuscated -- 返回混淆后的代码
end

-- 定义一个函数，用于将混淆后的 Lua 代码进行解混淆
local function deobfuscate(code)
    local reversed = string.reverse(code) -- 将混淆后的代码反转
    local decoded = decode(reversed) -- 对反转后的字符串进行解密
    return decoded -- 返回解混淆后的代码
end

-- 定义一个测试函数，用于测试加密和解密功能
local function test()
    local code = [[
        print("Hello, world!")
    ]]
    local obfuscated = obfuscate(code) -- 对代码进行混淆
    print(obfuscated) -- 输出混淆后的代码
    local deobfuscated = deobfuscate(obfuscated) -- 对混淆后的代码进行解混淆
    print(deobfuscated) -- 输出解混淆后的代码
end