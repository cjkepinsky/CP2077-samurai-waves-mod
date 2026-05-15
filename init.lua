local MOD_NAME = "Waves"
local MOD_VERSION = "0.9.21"
local MOD_LOG_NAME = MOD_NAME .. " v" .. MOD_VERSION

print("[" .. MOD_LOG_NAME .. "] file loaded")


-- NOTKI
-- meatheads zespawnowali w windzie..
-- smart hunter w mojej lokalizacji
-- samurai: po pojawieniu się w okolicy marker znika, spawn w lokalizacji

-- =========================================================
-- Bootstrap
-- =========================================================

local function loadHelper()
    local modDir = ""

    if debug and debug.getinfo then
        local source = debug.getinfo(1, "S").source or ""

        if string.sub(source, 1, 1) == "@" then
            source = string.sub(source, 2)
        end

        modDir = source:match("^(.*[\\/])") or ""
    end

    local ok, result = pcall(dofile, modDir .. "helper.lua")

    if not ok then
        error("Failed to load helper.lua: " .. tostring(result))
    end

    return result
end

local Helper = loadHelper()
local log = Helper.makeLogger(MOD_LOG_NAME)

-- =========================================================
-- Configuration
-- =========================================================

local settings = Helper.loadModFile("config/settings.lua")
if type(settings) ~= "table" then
    error("config/settings.lua must return a table")
end

local waveConfigFactory = Helper.loadModFile("config/waves.lua")
if type(waveConfigFactory) ~= "function" then
    error("config/waves.lua must return a factory function")
end

local waveConfig = waveConfigFactory(Helper.characterTDBID)
if type(waveConfig) ~= "table" then
    error("config/waves.lua must return a table")
end

local waves = waveConfig.waves
local spawnLines = waveConfig.spawnLines

if type(waves) ~= "table" or type(spawnLines) ~= "table" or type(spawnLines[1]) ~= "table" then
    error("config/waves.lua must provide waves and at least one fallback spawn line")
end

-- =========================================================
-- Runtime
-- =========================================================

local Geometry = Helper.loadModFile("src/geometry.lua")
local State = Helper.loadModFile("src/state.lua")
local HUD = Helper.loadModFile("src/hud.lua")
local SpawnPlanner = Helper.loadModFile("src/spawn_planner.lua")
local MarkerManager = Helper.loadModFile("src/markers.lua")
local Treasure = Helper.loadModFile("src/treasure.lua")
local PlayerRules = Helper.loadModFile("src/player_rules.lua")
local AIManager = Helper.loadModFile("src/ai.lua")
local Spawner = Helper.loadModFile("src/spawner.lua")
local MissionController = Helper.loadModFile("src/mission_controller.lua")

local state = State.new()
state:resetTimers()

local planner = SpawnPlanner.new({
    settings = settings,
    waves = waves,
    spawnLines = spawnLines,
    geometry = Geometry,
    log = log
})

local hud = HUD.new({
    state = state,
    settings = settings,
    log = log
})

local markers = MarkerManager.new({
    state = state,
    settings = settings,
    planner = planner,
    geometry = Geometry,
    log = log
})

local treasure = Treasure.new({
    state = state,
    geometry = Geometry,
    hud = hud,
    log = log
})

local playerRules = PlayerRules.new({
    state = state,
    settings = settings,
    waves = waves,
    hud = hud,
    log = log
})

local ai = AIManager.new({
    state = state,
    settings = settings,
    waves = waves,
    geometry = Geometry,
    log = log
})

local spawner = Spawner.new({
    state = state,
    settings = settings,
    waves = waves,
    planner = planner,
    ai = ai,
    geometry = Geometry,
    resolveTDBID = Helper.resolveTDBID,
    log = log
})

local mission = MissionController.new({
    modName = MOD_NAME,
    modVersion = MOD_VERSION,
    state = state,
    settings = settings,
    waves = waves,
    geometry = Geometry,
    planner = planner,
    markers = markers,
    treasure = treasure,
    playerRules = playerRules,
    hud = hud,
    ai = ai,
    spawner = spawner,
    log = log
})

-- =========================================================
-- Public Flow
-- =========================================================

mission:registerHotkeys()

registerForEvent("onInit", function()
    mission:onInit()
end)

registerForEvent("onUpdate", function(delta)
    mission:onUpdate(delta)
end)
