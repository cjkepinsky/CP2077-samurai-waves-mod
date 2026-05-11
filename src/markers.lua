local Markers = {}
Markers.__index = Markers

local ROUTE_MAPPIN_STYLES = {
    {
        name = "custom-position",
        mappinType = "Mappins.CustomPositionMappinDefinition",
        variants = { "CustomPositionVariant" }
    },
    {
        name = "quest-contract",
        mappinType = "Mappins.QuestStaticMappinDefinition",
        variants = { "NCPDGigVariant", "Zzz06_NCPDGigVariant", "PointOfInterest_MinorActivityVariant", "MinorActivityVariant", "DefaultQuestVariant" }
    },
    {
        name = "contract-poi",
        mappinType = "Mappins.StaticPointOfInterestMappinDefinition",
        variants = { "PointOfInterest_BountyHuntVariant", "BountyHuntVariant", "PointOfInterest_ClientInDistressVariant", "ClientInDistressVariant", "PointOfInterest_MinorActivityVariant", "MinorActivityVariant" }
    },
    {
        name = "legacy-default",
        mappinType = "Mappins.DefaultStaticMappin",
        variants = { "CustomPositionVariant" }
    }
}

function Markers.new(deps)
    return setmetatable({
        state = deps.state,
        settings = deps.settings,
        planner = deps.planner,
        geometry = deps.geometry,
        log = deps.log
    }, Markers)
end

function Markers:getRouteRefreshInterval()
    return (self.settings and self.settings.MARKER_ROUTE_REFRESH_INTERVAL) or 1.25
end

function Markers:copyPos(pos)
    if not pos then return nil end

    return {
        x = pos.x,
        y = pos.y,
        z = pos.z,
        w = pos.w or 1
    }
end

function Markers:trySetTrackingAlternative(sourceMappinId, targetMappinId)
    if not sourceMappinId or not targetMappinId then return false end

    return pcall(function()
        Game.GetMappinSystem():SetMappinTrackingAlternative(sourceMappinId, targetMappinId)
    end)
end

function Markers:getManuallyTrackedMappin()
    local okId, trackedId = pcall(function()
        return Game.GetMappinSystem():GetManuallyTrackedMappinID()
    end)

    if not okId or not trackedId then return nil, nil end

    local okMappin, trackedMappin = pcall(function()
        return Game.GetMappinSystem():GetMappin(trackedId)
    end)

    if not okMappin or not trackedMappin then return nil, nil end

    return trackedId, trackedMappin
end

function Markers:applyRouteCarrier(mappinId)
    local trackedId = self:getManuallyTrackedMappin()

    if trackedId and self:trySetTrackingAlternative(trackedId, mappinId) then
        if tostring(self.state.activeRouteCarrierMappin) ~= tostring(trackedId) then
            self.log(
                "Wave route carrier attached | wave=" ..
                tostring(self.state.currentMarkerWaveIndex) ..
                " | carrier=" ..
                tostring(trackedId)
            )
        end

        self.state.activeRouteCarrierMappin = trackedId
        return true, "manual"
    end

    if self:trySetTrackingAlternative(mappinId, mappinId) then
        self.state.activeRouteCarrierMappin = nil
        return false, "self-alternative"
    end

    self.state.activeRouteCarrierMappin = nil
    return false, "none"
end

function Markers:activateRoute(mappinId, pos, options)
    local mappinSystem = Game.GetMappinSystem()
    options = options or {}
    local positionSet = false
    local activeSet = false
    local trackingSet = false
    local routeCarrierSet = false
    local routeCarrier = "none"

    if options.untrack == true then
        pcall(function()
            mappinSystem:UntrackMappin()
        end)
    end

    positionSet = pcall(function()
        mappinSystem:SetMappinPosition(mappinId, pos)
    end)

    activeSet = pcall(function()
        mappinSystem:SetMappinActive(mappinId, true)
    end)

    local okTrackFunction, trackFunction = pcall(function()
        return mappinSystem.SetMappinTracked
    end)

    if okTrackFunction and trackFunction then
        trackingSet = pcall(function()
            mappinSystem:SetMappinTracked(mappinId, true)
        end)
    end

    if not trackingSet and options.allowCarrier ~= false then
        routeCarrierSet, routeCarrier = self:applyRouteCarrier(mappinId)
    elseif not trackingSet then
        self:trySetTrackingAlternative(mappinId, mappinId)
        routeCarrier = "disabled"
    end

    if not options.silent then
        self.log(
            "Marker activated | positionSet=" ..
            tostring(positionSet) ..
            " | activeSet=" ..
            tostring(activeSet) ..
            " | trackingSet=" ..
            tostring(trackingSet) ..
            " | routeCarrierSet=" ..
            tostring(routeCarrierSet) ..
            " | routeCarrier=" ..
            tostring(routeCarrier)
        )
    end

    return positionSet and activeSet, (trackingSet or routeCarrierSet), routeCarrier
end

function Markers:deactivateRoute(mappinId)
    self:resetRouteCarrierAlternative()

    pcall(function()
        Game.GetMappinSystem():SetMappinActive(mappinId, false)
    end)
end

function Markers:resetRouteCarrierAlternative()
    if not self.state.activeRouteCarrierMappin then return end

    pcall(function()
        Game.GetMappinSystem():SetMappinTrackingAlternative(
            self.state.activeRouteCarrierMappin,
            self.state.activeRouteCarrierMappin
        )
    end)

    self.state.activeRouteCarrierMappin = nil
end

function Markers:clearTrackedRoute()
    pcall(function()
        Game.GetMappinSystem():UntrackMappin()
    end)
end

function Markers:setMappinType(mappinData, mappinType, preferTweakDBID)
    local attempts = {}

    if preferTweakDBID then
        attempts = {
            function() mappinData.mappinType = TweakDBID.new(mappinType) end,
            function() mappinData.mappinType = mappinType end
        }
    else
        attempts = {
            function() mappinData.mappinType = mappinType end,
            function() mappinData.mappinType = TweakDBID.new(mappinType) end
        }
    end

    for _, attempt in ipairs(attempts) do
        local ok = pcall(attempt)
        if ok then return true end
    end

    return false
end

function Markers:setMappinVariant(mappinData, variants)
    for _, variantName in ipairs(variants or {}) do
        local okEnum, variant = pcall(function()
            if gamedataMappinVariant and gamedataMappinVariant[variantName] then
                return gamedataMappinVariant[variantName]
            end

            return Enum.new("gamedataMappinVariant", variantName)
        end)

        if okEnum and variant then
            local okSet = pcall(function()
                mappinData.variant = variant
            end)

            if okSet then return variantName end
        end
    end

    return nil
end

function Markers:createRouteMappinData(style)
    local mappinData = nil

    pcall(function()
        mappinData = MappinData.new()
    end)

    style = style or ROUTE_MAPPIN_STYLES[1]

    if mappinData then
        mappinData.active = true
        mappinData.visibleThroughWalls = true
        self:setMappinType(mappinData, style.mappinType, false)
        local variantName = self:setMappinVariant(mappinData, style.variants)

        pcall(function() mappinData.debugCaption = "Waves" end)

        return mappinData, variantName
    end

    mappinData = NewObject("gamemappinsMappinData")
    mappinData.active = true
    mappinData.visibleThroughWalls = true
    self:setMappinType(mappinData, style.mappinType, true)
    local variantName = self:setMappinVariant(mappinData, style.variants)
    pcall(function() mappinData.debugCaption = "Waves" end)

    return mappinData, variantName
end

function Markers:registerRouteMappin(pos)
    local lastError = nil

    for _, style in ipairs(ROUTE_MAPPIN_STYLES) do
        local ok, result, variantName = pcall(function()
            local mappinData, usedVariant = self:createRouteMappinData(style)
            return Game.GetMappinSystem():RegisterMappin(mappinData, pos), usedVariant
        end)

        if ok and result then
            return result, style.name, variantName
        end

        lastError = result
        self.log(
            "Route mappin style failed | style=" ..
            tostring(style.name) ..
            " | err=" ..
            tostring(result)
        )
    end

    return nil, nil, nil, lastError
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
    self.state.activeMappinPos = nil
    self.state.activeRouteCarrierMappin = nil
    self.state.markerRouteRefreshTimer = 0
end

function Markers:setWaveMarker(waveIndex)
    self:clear()

    local markerPos = self.planner:getWaveMarkerPos(waveIndex)
    if not markerPos then
        self.log("Wave marker skipped: no marker position for wave=" .. tostring(waveIndex))
        return false
    end

    local pos = self.geometry.toV4(markerPos)

    local result, styleName, variantName, err = self:registerRouteMappin(pos)

    if result then
        self.state.activeMappin = result
        self.state.markerActive = true
        self.state.currentMarkerWaveIndex = waveIndex
        self.state.activeMappinPos = self:copyPos(markerPos)
        self.state.markerRouteRefreshTimer = self:getRouteRefreshInterval()
        local markerOk, routeOk, routeCarrier = self:activateRoute(result, pos)

        self.log(
            "Wave marker registered | wave=" ..
            tostring(waveIndex) ..
            " | style=" ..
            tostring(styleName) ..
            " | variant=" ..
            tostring(variantName) ..
            " | x=" ..
            tostring(markerPos.x) ..
            " | y=" ..
            tostring(markerPos.y) ..
            " | z=" ..
            tostring(markerPos.z) ..
            " | markerOk=" ..
            tostring(markerOk) ..
            " | routeOk=" ..
            tostring(routeOk) ..
            " | routeCarrier=" ..
            tostring(routeCarrier)
        )
        return markerOk
    end

    self.log("Wave marker FAILED | wave=" .. tostring(waveIndex) .. " | err=" .. tostring(err))
    return false
end

function Markers:setCombatMarker(posData, waveIndex)
    self:clear()

    if not posData then
        self.log("Combat marker skipped: no position for wave=" .. tostring(waveIndex))
        return false
    end

    local pos = self.geometry.toV4(posData)

    local result, styleName, variantName, err = self:registerRouteMappin(pos)

    if result then
        self.state.activeMappin = result
        self.state.markerActive = false
        self.state.currentMarkerWaveIndex = nil
        self.state.activeMappinPos = self:copyPos(posData)
        self.state.markerRouteRefreshTimer = 0
        self:activateRoute(result, pos, { allowCarrier = false })
        self.log(
            "Combat marker registered | wave=" ..
            tostring(waveIndex) ..
            " | style=" ..
            tostring(styleName) ..
            " | variant=" ..
            tostring(variantName)
        )
        return true
    end

    self.log("Combat marker FAILED | wave=" .. tostring(waveIndex) .. " | err=" .. tostring(err))
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

    local result, styleName, variantName, err = self:registerRouteMappin(pos)

    if result then
        self.state.activeMappin = result
        self.state.markerActive = true
        self.state.activeMappinPos = {
            x = playerPos.x,
            y = playerPos.y,
            z = playerPos.z,
            w = 1
        }
        self.state.markerRouteRefreshTimer = self:getRouteRefreshInterval()
        self:activateRoute(result, pos)
        self.log(
            "Test marker on player registered | style=" ..
            tostring(styleName) ..
            " | variant=" ..
            tostring(variantName)
        )
    else
        self.log("Test marker FAILED: " .. tostring(err))
    end
end

function Markers:refreshActiveWaveRoute(reason)
    if not self.state.markerActive then return false end
    if not self.state.activeMappin then return false end
    if not self.state.activeMappinPos then return false end
    if self.state.currentMarkerWaveIndex == nil then return false end

    local pos = self.geometry.toV4(self.state.activeMappinPos)
    local ok = self:activateRoute(self.state.activeMappin, pos, { silent = true })

    if not ok then
        self.log(
            "Marker route refresh FAILED | wave=" ..
            tostring(self.state.currentMarkerWaveIndex) ..
            " | reason=" ..
            tostring(reason or "periodic")
        )
        return self:recreateActiveWaveMarker(reason or "refresh-failed")
    end

    return true
end

function Markers:recreateActiveWaveMarker(reason)
    local waveIndex = self.state.currentMarkerWaveIndex
    local markerPos = self:copyPos(self.state.activeMappinPos)
    local oldMappin = self.state.activeMappin

    if not waveIndex or not markerPos then return false end

    self.log(
        "Recreating wave marker | wave=" ..
        tostring(waveIndex) ..
        " | reason=" ..
        tostring(reason or "unknown")
    )

    if oldMappin then
        pcall(function()
            Game.GetMappinSystem():UnregisterMappin(oldMappin)
        end)
    end

    self.state.activeMappin = nil
    self.state.markerActive = false
    self.state.currentMarkerWaveIndex = nil
    self.state.activeMappinPos = nil
    self.state.markerRouteRefreshTimer = 0

    return self:setWaveMarker(waveIndex)
end

function Markers:update(delta)
    if not self.state.markerActive or not self.state.activeMappin or not self.state.activeMappinPos then
        self.state.markerRouteRefreshTimer = 0
        return
    end

    if self.state.currentMarkerWaveIndex == nil then
        self.state.markerRouteRefreshTimer = 0
        return
    end

    self.state.markerRouteRefreshTimer = (self.state.markerRouteRefreshTimer or 0) - delta

    if self.state.markerRouteRefreshTimer <= 0 then
        self.state.markerRouteRefreshTimer = self:getRouteRefreshInterval()
        self:refreshActiveWaveRoute("periodic")
    end
end

return Markers
