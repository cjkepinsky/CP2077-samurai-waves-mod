local Treasure = {}
Treasure.__index = Treasure

function Treasure.new(deps)
    return setmetatable({
        state = deps.state,
        geometry = deps.geometry,
        hud = deps.hud,
        log = deps.log
    }, Treasure)
end

function Treasure:createMappinData()
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

        pcall(function() mappinData.debugCaption = "Stash" end)
        return mappinData
    end

    mappinData = NewObject("gamemappinsMappinData")
    mappinData.mappinType = TweakDBID.new("Mappins.DefaultStaticMappin")
    mappinData.variant = Enum.new("gamedataMappinVariant", "CustomPositionVariant")
    mappinData.active = true
    mappinData.visibleThroughWalls = true
    pcall(function() mappinData.debugCaption = "Stash" end)

    return mappinData
end

function Treasure:getWaveTreasure(wave)
    if not wave or type(wave.treasure) ~= "table" then return nil end
    return wave.treasure
end

function Treasure:getTreasurePos(wave, fallbackPos)
    local treasure = self:getWaveTreasure(wave)
    if not treasure then return nil end

    return treasure.pos or wave.treasurePos or fallbackPos
end

function Treasure:registerMarker(posData, waveIndex)
    if not posData then return false end

    local pos = self.geometry.toV4(posData)
    local ok, result = pcall(function()
        local mappinData = self:createMappinData()
        return Game.GetMappinSystem():RegisterMappin(mappinData, pos)
    end)

    if ok and result then
        self.state.activeTreasureMappin = result

        pcall(function()
            Game.GetMappinSystem():SetMappinActive(result, true)
        end)

        self.log("Treasure marker registered | wave=" .. tostring(waveIndex))
        return true
    end

    self.log("Treasure marker FAILED | wave=" .. tostring(waveIndex) .. " | err=" .. tostring(result))
    return false
end

function Treasure:clear()
    if self.state.activeTreasureMappin then
        local mappinId = self.state.activeTreasureMappin

        pcall(function()
            Game.GetMappinSystem():SetMappinActive(mappinId, false)
        end)

        pcall(function()
            Game.GetMappinSystem():UnregisterMappin(mappinId)
        end)

        self.state.activeTreasureMappin = nil
        self.log("Treasure marker cleared")
    end

    self.state.activeTreasure = nil
end

function Treasure:showHUD(text)
    if self.hud and self.hud.schedule then
        self.hud:schedule(text, 0.4)
        return
    end

    if self.hud and self.hud.show then
        self.hud:show(text)
    end
end

function Treasure:activateForWave(waveIndex, wave, fallbackPos)
    self:clear()

    local treasure = self:getWaveTreasure(wave)
    if not treasure then return false end

    local pos = self:getTreasurePos(wave, fallbackPos)
    if not pos then
        self.log("Treasure skipped: no position | wave=" .. tostring(waveIndex))
        return false
    end

    local rewardMoney = math.floor(tonumber(treasure.rewardMoney or treasure.money or 0) or 0)

    self.state.activeTreasure = {
        waveIndex = waveIndex,
        pos = { x = pos.x, y = pos.y, z = pos.z, w = pos.w or 1 },
        rewardMoney = rewardMoney,
        claimed = false
    }

    self:registerMarker(pos, waveIndex)

    self.log(
        "Treasure active | wave=" ..
        tostring(waveIndex) ..
        " | rewardMoney=" ..
        tostring(rewardMoney)
    )

    return true
end

function Treasure:grantMoney(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end

    local ok = pcall(function()
        Game.AddToInventory("Items.money", amount)
    end)

    if ok then return true end

    ok = pcall(function()
        Game.AddToInventory(TweakDBID.new("Items.money"), amount)
    end)

    if ok then return true end

    ok = pcall(function()
        local player = Game.GetPlayer()
        local transactionSystem = Game.GetTransactionSystem()
        if player and transactionSystem then
            transactionSystem:GiveItem(player, TweakDBID.new("Items.money"), amount)
        else
            error("transaction system unavailable")
        end
    end)

    return ok == true
end

function Treasure:claimWave(waveIndex)
    if not self.state.claimedTreasures then
        self.state.claimedTreasures = {}
    end

    if self.state.claimedTreasures[waveIndex] then
        self:clear()
        return false
    end

    local active = self.state.activeTreasure
    if not active or active.waveIndex ~= waveIndex or active.claimed then
        return false
    end

    active.claimed = true
    self.state.claimedTreasures[waveIndex] = true

    local ok = self:grantMoney(active.rewardMoney)

    if ok then
        self:showHUD("Wave stash secured: +" .. tostring(active.rewardMoney) .. " eddies.")
        self.log("Treasure claimed | wave=" .. tostring(waveIndex) .. " | rewardMoney=" .. tostring(active.rewardMoney))
    else
        self:showHUD("Wave stash secured, but reward grant failed.")
        self.log("Treasure reward FAILED | wave=" .. tostring(waveIndex) .. " | rewardMoney=" .. tostring(active.rewardMoney))
    end

    self:clear()
    return ok
end

return Treasure
