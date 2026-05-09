local Markers = {}
Markers.__index = Markers

function Markers.new(deps)
    return setmetatable({
        state = deps.state,
        planner = deps.planner,
        geometry = deps.geometry,
        log = deps.log
    }, Markers)
end

function Markers:activateRoute(mappinId, pos)
    pcall(function()
        Game.GetMappinSystem():SetMappinActive(mappinId, true)
    end)

    local ok, err = pcall(function()
        Game.GetMappinSystem():SetMappinTracked(mappinId, true)
    end)

    if not ok then
        self.log("SetMappinTracked failed: " .. tostring(err))
    end
end

function Markers:deactivateRoute(mappinId)
    pcall(function()
        Game.GetMappinSystem():SetMappinTracked(mappinId, false)
    end)
end

function Markers:clearTrackedRoute()
    pcall(function()
        Game.GetMappinSystem():UntrackMappin()
    end)
end

function Markers:createRouteMappinData()
    local mappinData = nil

    pcall(function()
        mappinData = MappinData.new()
    end)

    if mappinData then
        mappinData.mappinType = "Mappins.DefaultStaticMappin"
        mappinData.active = true
        mappinData.visibleThroughWalls = true

        if gamedataMappinVariant and gamedataMappinVariant.CustomPositionVariant then
            mappinData.variant = gamedataMappinVariant.CustomPositionVariant
        else
            mappinData.variant = Enum.new("gamedataMappinVariant", "CustomPositionVariant")
        end

        return mappinData
    end

    mappinData = NewObject("gamemappinsMappinData")
    mappinData.mappinType = TweakDBID.new("Mappins.DefaultStaticMappin")
    mappinData.variant = Enum.new("gamedataMappinVariant", "CustomPositionVariant")
    mappinData.active = true
    mappinData.visibleThroughWalls = true

    return mappinData
end

function Markers:clear()
    if self.state.activeMappin then
        self:deactivateRoute(self.state.activeMappin)

        pcall(function()
            Game.GetMappinSystem():UnregisterMappin(self.state.activeMappin)
        end)

        self.state.activeMappin = nil
        self.log("Marker cleared")
    end

    self.state.markerActive = false
    self.state.currentMarkerWaveIndex = nil
end

function Markers:setWaveMarker(waveIndex)
    self:clear()
    self:clearTrackedRoute()

    local markerPos = self.planner:getWaveMarkerPos(waveIndex)
    if not markerPos then
        self.log("Wave marker skipped: no marker position for wave=" .. tostring(waveIndex))
        return false
    end

    local pos = self.geometry.toV4(markerPos)

    local ok, result = pcall(function()
        local mappinData = self:createRouteMappinData()
        return Game.GetMappinSystem():RegisterMappin(mappinData, pos)
    end)

    if ok and result then
        self.state.activeMappin = result
        self.state.markerActive = true
        self.state.currentMarkerWaveIndex = waveIndex
        self:activateRoute(result, pos)
        self.log("Wave marker registered | wave=" .. tostring(waveIndex))
        return true
    end

    self.log("Wave marker FAILED | wave=" .. tostring(waveIndex) .. " | err=" .. tostring(result))
    return false
end

function Markers:setCombatMarker(posData, waveIndex)
    self:clear()
    self:clearTrackedRoute()

    if not posData then
        self.log("Combat marker skipped: no position for wave=" .. tostring(waveIndex))
        return false
    end

    local pos = self.geometry.toV4(posData)

    local ok, result = pcall(function()
        local mappinData = self:createRouteMappinData()
        return Game.GetMappinSystem():RegisterMappin(mappinData, pos)
    end)

    if ok and result then
        self.state.activeMappin = result
        self.state.markerActive = false
        self.state.currentMarkerWaveIndex = nil
        self:activateRoute(result, pos)
        self.log("Combat marker registered | wave=" .. tostring(waveIndex))
        return true
    end

    self.log("Combat marker FAILED | wave=" .. tostring(waveIndex) .. " | err=" .. tostring(result))
    return false
end

function Markers:testMarkerOnPlayer()
    local player = Game.GetPlayer()
    if not player then
        self.log("No player")
        return
    end

    self:clear()

    local playerPos = player:GetWorldPosition()
    local pos = Vector4.new(playerPos.x, playerPos.y, playerPos.z, 1)

    local ok, result = pcall(function()
        local mappinData = self:createRouteMappinData()
        return Game.GetMappinSystem():RegisterMappin(mappinData, pos)
    end)

    if ok and result then
        self.state.activeMappin = result
        self.state.markerActive = true
        self:activateRoute(result, pos)
        self.log("Test marker on player registered")
    else
        self.log("Test marker FAILED: " .. tostring(result))
    end
end

return Markers
