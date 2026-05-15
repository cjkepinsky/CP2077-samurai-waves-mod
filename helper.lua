local Helper = {}

local function getSourceDirectory(level)
    if not debug or not debug.getinfo then
        return ""
    end

    local info = debug.getinfo(level or 1, "S")
    local source = info and info.source or ""

    if string.sub(source, 1, 1) == "@" then
        source = string.sub(source, 2)
    end

    return source:match("^(.*[\\/])") or ""
end

local MOD_DIR = getSourceDirectory(1)

function Helper.getModDirectory()
    return MOD_DIR
end

function Helper.loadModFile(relativePath)
    local fullPath = MOD_DIR .. relativePath
    local ok, result = pcall(dofile, fullPath)

    if not ok then
        error("Failed to load " .. tostring(relativePath) .. ": " .. tostring(result))
    end

    return result
end

function Helper.characterTDBID(id)
    if string.sub(id, 1, 10) == "Character." then
        return id
    end

    return "Character." .. id
end

function Helper.resolveTDBID(id)
    if type(id) ~= "string" then return id end

    if not TweakDBID or not TweakDBID.new then
        return nil
    end

    return TweakDBID.new(id)
end

function Helper.nowStamp()
    local ok, result = pcall(function()
        return os.date("%H:%M:%S")
    end)

    if ok and result then return result end
    return "t+?"
end

function Helper.makeLogger(modName)
    return function(msg)
        local line = "[" .. tostring(modName) .. "][" .. Helper.nowStamp() .. "] " .. tostring(msg)

        print(line)

        pcall(function()
            local file = io.open(MOD_DIR .. "Waves.log", "a")

            if file then
                file:write(line .. "\n")
                file:close()
            end
        end)
    end
end

return Helper
