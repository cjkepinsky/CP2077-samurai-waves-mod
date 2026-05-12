local PlayerRules = {}
PlayerRules.__index = PlayerRules

local function lower(value)
    return string.lower(tostring(value or ""))
end

function PlayerRules.new(deps)
    return setmetatable({
        state = deps.state,
        settings = deps.settings,
        waves = deps.waves,
        hud = deps.hud,
        log = deps.log,
        activeWaveIndex = nil,
        activeWave = nil,
        activeRule = nil,
        timer = 0,
        savedWeaponSlots = nil,
        grantedKatana = false,
        quickhackImmunityObjects = {},
        katanaHitObjects = {},
        invalidDefeatObjects = {},
        lastWarnAt = nil
    }, PlayerRules)
end

function PlayerRules:getRule(wave)
    local rule = wave and wave.playerWeaponRule
    if type(rule) ~= "table" then return nil end

    if rule.type == "katanaOnly" or rule.katanaOnly == true then
        return rule
    end

    return nil
end

function PlayerRules:isRuleActive()
    return self.activeRule ~= nil and self.activeWaveIndex ~= nil
end

function PlayerRules:getWarnInterval()
    return self.settings.PLAYER_WEAPON_RULE_WARN_INTERVAL or 3.0
end

function PlayerRules:getEnforceInterval()
    return self.settings.PLAYER_WEAPON_RULE_INTERVAL or 0.35
end

function PlayerRules:getKatanaItem()
    return (self.activeRule and self.activeRule.katanaItem) or "Items.Preset_Katana_Default"
end

function PlayerRules:shouldBlockQuickhacks()
    return self.activeRule and self.activeRule.blockQuickhacks == true
end

function PlayerRules:getQuickhackImmunityStat()
    return (self.activeRule and self.activeRule.quickhackImmunityStat) or "QuickHackImmunity"
end

function PlayerRules:shouldRequireKatanaDefeat()
    return not self.activeRule or self.activeRule.requireKatanaHitForDefeat ~= false
end

function PlayerRules:makeItemID(item)
    if not item then return nil end

    local ok, result = pcall(function()
        return ItemID.FromTDBID(item)
    end)

    if ok and result then return result end

    local tdbid = item
    if type(item) == "string" and TweakDBID and TweakDBID.new then
        local okTDBID, resultTDBID = pcall(function()
            return TweakDBID.new(item)
        end)

        if okTDBID and resultTDBID then
            tdbid = resultTDBID
        end
    end

    ok, result = pcall(function()
        return ItemID.FromTDBID(tdbid)
    end)

    if ok and result then return result end
    return nil
end

function PlayerRules:itemIDHash(itemID)
    if not itemID then return nil end

    local ok, result = pcall(function()
        return itemID.id.hash
    end)

    if ok and result then return result end

    ok, result = pcall(function()
        return itemID.tdbid.hash
    end)

    if ok and result then return result end

    return nil
end

function PlayerRules:isEmptyItemID(itemID)
    local hash = self:itemIDHash(itemID)
    return not hash or hash == 0
end

function PlayerRules:tdbidToString(value)
    if not value then return "" end

    local ok, result = pcall(function()
        if TDBID and TDBID.ToStringDEBUG then
            return TDBID.ToStringDEBUG(value)
        end
    end)

    if ok and result then return tostring(result) end

    ok, result = pcall(function()
        return value.value
    end)

    if ok and result then return tostring(result) end

    return tostring(value)
end

function PlayerRules:itemIDToString(itemID)
    if not itemID then return "" end

    local ok, result = pcall(function()
        return self:tdbidToString(itemID.id)
    end)

    if ok and result and result ~= "" then return result end

    ok, result = pcall(function()
        return self:tdbidToString(itemID.tdbid)
    end)

    if ok and result and result ~= "" then return result end

    return tostring(itemID)
end

function PlayerRules:getPlayerEquipmentData()
    local player = Game.GetPlayer()
    if not player then return nil, nil, nil end

    local transactionSystem = nil
    pcall(function()
        transactionSystem = Game.GetTransactionSystem()
    end)

    local container = nil
    pcall(function()
        container = Game.GetScriptableSystemsContainer()
    end)

    if not container then return player, transactionSystem, nil end

    local equipmentSystem = nil
    pcall(function()
        equipmentSystem = container:Get("EquipmentSystem")
    end)

    if not equipmentSystem and CName and CName.new then
        pcall(function()
            equipmentSystem = container:Get(CName.new("EquipmentSystem"))
        end)
    end

    if not equipmentSystem then return player, transactionSystem, nil end

    local equipmentData = nil
    pcall(function()
        equipmentData = equipmentSystem:GetPlayerData(player)
    end)

    if equipmentData then
        pcall(function()
            equipmentData["GetItemInEquipSlot2"] = equipmentData["GetItemInEquipSlot;gamedataEquipmentAreaInt32"]
        end)
    end

    return player, transactionSystem, equipmentData
end

function PlayerRules:getWeaponSlot(equipmentData, slotIndex)
    if not equipmentData then return nil end

    local ok, result = pcall(function()
        return equipmentData:GetItemInEquipSlot2("Weapon", slotIndex)
    end)

    if ok and result then return result end

    ok, result = pcall(function()
        return equipmentData:GetItemInEquipSlot("Weapon", slotIndex)
    end)

    if ok and result then return result end

    return nil
end

function PlayerRules:isKatanaIDString(id)
    local text = lower(id)
    if text == "" then return false end

    if string.find(text, "katana", 1, true) then return true end

    local extra = self.activeRule and self.activeRule.allowedItemContains
    if type(extra) == "table" then
        for _, fragment in ipairs(extra) do
            if string.find(text, lower(fragment), 1, true) then
                return true
            end
        end
    end

    return false
end

function PlayerRules:isKatanaItemID(itemID)
    if self:isEmptyItemID(itemID) then return false end
    return self:isKatanaIDString(self:itemIDToString(itemID))
end

function PlayerRules:getWeaponRecordID(evt)
    if not evt or not evt.attackData then return "" end

    local ok, result = pcall(function()
        return evt.attackData.weapon.weaponRecord:GetID().value
    end)

    if ok and result then return tostring(result) end

    ok, result = pcall(function()
        return self:tdbidToString(evt.attackData.weapon.weaponRecord:GetID())
    end)

    if ok and result then return tostring(result) end

    return ""
end

function PlayerRules:isTrackedCurrentWaveNPC(npc)
    if not npc or not self.activeWaveIndex then return false end

    local meta = self.state.spawnedObjectMetas[npc]
    return meta and meta.waveIndex == self.activeWaveIndex
end

function PlayerRules:isPlayerInstigator(evt)
    if not evt or not evt.attackData then return false end

    local ok, result = pcall(function()
        return IsDefined(evt.attackData.instigator) and evt.attackData.instigator:IsPlayer()
    end)

    return ok and result == true
end

function PlayerRules:createStatModifier(stat, value)
    local ok, result = pcall(function()
        return RPGManager.CreateStatModifier(stat, gameStatModifierType.Additive, value)
    end)

    if ok and result then return result end

    ok, result = pcall(function()
        return Game["gameRPGManager::CreateStatModifier;gamedataStatTypegameStatModifierTypeFloat"](
            stat,
            "Additive",
            value
        )
    end)

    if ok and result then return result end
    return nil
end

function PlayerRules:addEntityStatModifier(entity, stat, value)
    if not entity then return false end

    local entityID = nil
    local ok = pcall(function()
        entityID = entity:GetEntityID()
    end)

    if not ok or not entityID then return false end

    local modifier = self:createStatModifier(stat, value)
    if not modifier then return false end

    local statsSystem = nil
    ok = pcall(function()
        statsSystem = Game.GetStatsSystem()
    end)

    if not ok or not statsSystem then return false end

    ok = pcall(function()
        statsSystem:AddModifier(entityID, modifier)
    end)

    if ok then return true end

    ok = pcall(function()
        statsSystem:AddSavedModifier(entityID, modifier)
    end)

    return ok == true
end

function PlayerRules:applyQuickhackImmunity(npc, meta)
    if not self:isRuleActive() then return false end
    if not self:shouldBlockQuickhacks() then return false end
    if not npc or not meta or meta.waveIndex ~= self.activeWaveIndex then return false end
    if self.quickhackImmunityObjects[npc] then return true end

    local stat = self:getQuickhackImmunityStat()
    local ok = self:addEntityStatModifier(npc, stat, 1.0)

    if ok then
        self.quickhackImmunityObjects[npc] = true
        self.log(
            "Player weapon rule applied quickhack immunity | wave=" ..
            tostring(self.activeWaveIndex) ..
            " | stat=" ..
            tostring(stat)
        )
    else
        self.log(
            "Player weapon rule failed to apply quickhack immunity | wave=" ..
            tostring(self.activeWaveIndex) ..
            " | stat=" ..
            tostring(stat)
        )
    end

    return ok
end

function PlayerRules:applyQuickhackImmunityToTrackedNPCs()
    if not self:isRuleActive() or not self:shouldBlockQuickhacks() then return end

    for _, npc in ipairs(self.state.spawnedObjects) do
        self:applyQuickhackImmunity(npc, self.state.spawnedObjectMetas[npc])
    end
end

function PlayerRules:onNPCTracked(npc, meta)
    self:applyQuickhackImmunity(npc, meta)
end

function PlayerRules:markKatanaHit(npc, weaponID)
    if not npc then return end

    self.katanaHitObjects[npc] = {
        weaponID = weaponID,
        time = self.state.elapsed or 0
    }

    self.log(
        "Player weapon rule katana hit registered | wave=" ..
        tostring(self.activeWaveIndex) ..
        " | weapon=" ..
        tostring(weaponID)
    )
end

function PlayerRules:hasKatanaHit(npc)
    return self.katanaHitObjects and self.katanaHitObjects[npc] ~= nil
end

function PlayerRules:validateDefeat(npc, meta, reason)
    if not self:isRuleActive() then return true end
    if not meta or meta.waveIndex ~= self.activeWaveIndex then return true end
    if not self:shouldRequireKatanaDefeat() then return true end
    if self:hasKatanaHit(npc) then return true end

    if not self.invalidDefeatObjects[npc] then
        self.invalidDefeatObjects[npc] = true
        self:flagViolation(reason or "defeat-without-katana-hit", "no-katana-hit")
    end

    return false
end

function PlayerRules:warn(message)
    local now = self.state.elapsed or 0
    if self.lastWarnAt and now - self.lastWarnAt < self:getWarnInterval() then return end

    self.lastWarnAt = now

    if self.hud then
        self.hud:show(message or "Katana only.")
    end
end

function PlayerRules:saveCurrentWeapons(equipmentData)
    local saved = {}

    for slot = 0, 2 do
        local itemID = self:getWeaponSlot(equipmentData, slot)

        if not self:isEmptyItemID(itemID) then
            table.insert(saved, {
                slot = slot,
                itemID = itemID,
                id = self:itemIDToString(itemID)
            })
        end
    end

    self.savedWeaponSlots = saved
end

function PlayerRules:giveKatanaIfNeeded(player, transactionSystem, katanaItemID)
    if not player or not transactionSystem or not katanaItemID then return end

    local quantity = nil
    local ok = pcall(function()
        quantity = transactionSystem:GetItemQuantity(player, katanaItemID)
    end)

    if ok and quantity and quantity > 0 then return end

    ok = pcall(function()
        transactionSystem:GiveItem(player, katanaItemID, 1)
    end)

    if ok then
        self.grantedKatana = true
        self.log("Player weapon rule granted fallback katana | item=" .. tostring(self:getKatanaItem()))
    end
end

function PlayerRules:equipItem(equipmentData, itemID)
    if not equipmentData or not itemID then return false end

    local ok = pcall(function()
        equipmentData:EquipItem(itemID)
    end)

    return ok == true
end

function PlayerRules:unequipItem(equipmentData, itemID)
    if not equipmentData or not itemID then return false end

    local ok = pcall(function()
        equipmentData:UnequipItem(itemID)
    end)

    return ok == true
end

function PlayerRules:ensureKatanaEquipped(player, transactionSystem, equipmentData)
    if not equipmentData then return false end

    for slot = 0, 2 do
        local itemID = self:getWeaponSlot(equipmentData, slot)
        if self:isKatanaItemID(itemID) then return true end
    end

    local katanaItemID = self:makeItemID(self:getKatanaItem())
    if not katanaItemID then
        self.log("Player weapon rule failed to make katana ItemID | item=" .. tostring(self:getKatanaItem()))
        return false
    end

    self:giveKatanaIfNeeded(player, transactionSystem, katanaItemID)

    if self:equipItem(equipmentData, katanaItemID) then
        self.log("Player weapon rule equipped katana | item=" .. tostring(self:getKatanaItem()))
        return true
    end

    self.log("Player weapon rule failed to equip katana | item=" .. tostring(self:getKatanaItem()))
    return false
end

function PlayerRules:enforceSlots()
    local player, transactionSystem, equipmentData = self:getPlayerEquipmentData()
    if not equipmentData then return end

    local removed = 0

    for slot = 0, 2 do
        local itemID = self:getWeaponSlot(equipmentData, slot)

        if not self:isEmptyItemID(itemID) and not self:isKatanaItemID(itemID) then
            if self:unequipItem(equipmentData, itemID) then
                removed = removed + 1
                self.log(
                    "Player weapon rule unequipped non-katana | wave=" ..
                    tostring(self.activeWaveIndex) ..
                    " | slot=" ..
                    tostring(slot) ..
                    " | item=" ..
                    tostring(self:itemIDToString(itemID))
                )
            end
        end
    end

    self:ensureKatanaEquipped(player, transactionSystem, equipmentData)

    if removed > 0 then
        self:warn((self.activeRule and self.activeRule.warningMessage) or "Katana only for this contract.")
    end
end

function PlayerRules:startWave(waveIndex, wave)
    local rule = self:getRule(wave)
    if not rule then
        self:stopWave("new-wave-no-rule")
        return
    end

    self.activeWaveIndex = waveIndex
    self.activeWave = wave
    self.activeRule = rule
    self.timer = 0
    self.grantedKatana = false
    self.quickhackImmunityObjects = {}
    self.katanaHitObjects = {}
    self.invalidDefeatObjects = {}
    self.lastWarnAt = nil
    self.state.playerWeaponRuleViolation = nil

    local _player, _transactionSystem, equipmentData = self:getPlayerEquipmentData()
    if equipmentData then
        self:saveCurrentWeapons(equipmentData)
        self:enforceSlots()
    else
        self.savedWeaponSlots = {}
        self.log("Player weapon rule started without equipment data | wave=" .. tostring(waveIndex))
    end

    self.log(
        "Player weapon rule active | wave=" ..
        tostring(waveIndex) ..
        " | type=" ..
        tostring(rule.type or "katanaOnly") ..
        " | action=" ..
        tostring(rule.violationAction or "restartWave") ..
        " | blockQuickhacks=" ..
        tostring(rule.blockQuickhacks == true) ..
        " | requireKatanaHitForDefeat=" ..
        tostring(rule.requireKatanaHitForDefeat ~= false) ..
        " | savedWeapons=" ..
        tostring(self.savedWeaponSlots and #self.savedWeaponSlots or 0)
    )

    self:warn(rule.startMessage or "Katana only for this contract.")
end

function PlayerRules:restoreWeapons()
    local _player, _transactionSystem, equipmentData = self:getPlayerEquipmentData()
    if not equipmentData then return end

    if self.grantedKatana and (not self.activeRule or self.activeRule.unequipGrantedKatanaOnEnd ~= false) then
        local katanaItemID = self:makeItemID(self:getKatanaItem())

        if katanaItemID and self:unequipItem(equipmentData, katanaItemID) then
            self.log("Player weapon rule unequipped granted katana | item=" .. tostring(self:getKatanaItem()))
        end
    end

    if not self.savedWeaponSlots or #self.savedWeaponSlots <= 0 then return end
    if self.activeRule and self.activeRule.restorePreviousWeapons == false then return end

    for _, item in ipairs(self.savedWeaponSlots) do
        if item.itemID and self:equipItem(equipmentData, item.itemID) then
            self.log(
                "Player weapon rule restored weapon | slot=" ..
                tostring(item.slot) ..
                " | item=" ..
                tostring(item.id)
            )
        end
    end
end

function PlayerRules:stopWave(reason)
    if not self:isRuleActive() then return end

    local waveIndex = self.activeWaveIndex
    self:restoreWeapons()

    self.log(
        "Player weapon rule stopped | wave=" ..
        tostring(waveIndex) ..
        " | reason=" ..
        tostring(reason or "unknown") ..
        " | grantedKatana=" ..
        tostring(self.grantedKatana)
    )

    self.activeWaveIndex = nil
    self.activeWave = nil
    self.activeRule = nil
    self.timer = 0
    self.savedWeaponSlots = nil
    self.grantedKatana = false
    self.quickhackImmunityObjects = {}
    self.katanaHitObjects = {}
    self.invalidDefeatObjects = {}
    self.lastWarnAt = nil
end

function PlayerRules:update(delta)
    if not self:isRuleActive() then return end

    self.timer = self.timer + delta
    if self.timer < self:getEnforceInterval() then return end

    self.timer = 0
    self:enforceSlots()
    self:applyQuickhackImmunityToTrackedNPCs()
end

function PlayerRules:flagViolation(reason, weaponID)
    if not self:isRuleActive() then return end
    if self.state.playerWeaponRuleViolation then return end

    local action = self.activeRule.violationAction or "restartWave"
    self.state.playerWeaponRuleViolation = {
        waveIndex = self.activeWaveIndex,
        action = action,
        reason = reason,
        weaponID = weaponID
    }

    self.log(
        "Player weapon rule violation | wave=" ..
        tostring(self.activeWaveIndex) ..
        " | action=" ..
        tostring(action) ..
        " | reason=" ..
        tostring(reason) ..
        " | weapon=" ..
        tostring(weaponID)
    )

    self:warn((self.activeRule and self.activeRule.violationMessage) or "Katana only. Restarting wave.")
end

function PlayerRules:onNPCPuppetHit(npc, evt)
    if not self:isRuleActive() then return end
    if not self:isTrackedCurrentWaveNPC(npc) then return end
    if not self:isPlayerInstigator(evt) then return end

    local weaponID = self:getWeaponRecordID(evt)

    if self:isKatanaIDString(weaponID) then
        self:markKatanaHit(npc, weaponID)
        return
    end

    if weaponID == "" then
        weaponID = "unknown"
    end

    self:flagViolation("non-katana-hit", weaponID)
end

return PlayerRules
