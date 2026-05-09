local AI = {}
AI.__index = AI

function AI.new(deps)
    return setmetatable({
        state = deps.state,
        settings = deps.settings,
        waves = deps.waves,
        geometry = deps.geometry,
        log = deps.log,
        playerEntityReference = nil,
        playerEntityReferenceWarningLogged = false
    }, AI)
end

function AI:getDistanceFromPlayer(entity)
    local player = Game.GetPlayer()
    if not player or not entity then return 9999 end

    local ok, result = pcall(function()
        return self.geometry.distance(player:GetWorldPosition(), entity:GetWorldPosition())
    end)

    if ok and result then return result end
    return 9999
end

function AI:wake(npc)
    if not npc then return end

    pcall(function()
        local controller = npc:GetAIControllerComponent()
        if controller then
            controller:OnAttach()
        end
    end)
end

function AI:setAllSpawnedFriendly()
    for i = 1, #self.state.spawnedObjects do
        local a = self.state.spawnedObjects[i]

        if a then
            pcall(function()
                local aAtt = a:GetAttitudeAgent()
                if not aAtt then return end

                for j = i + 1, #self.state.spawnedObjects do
                    local b = self.state.spawnedObjects[j]

                    if b and b ~= a then
                        local bAtt = b:GetAttitudeAgent()

                        if bAtt then
                            aAtt:SetAttitudeTowards(bAtt, EAIAttitude.AIA_Friendly)
                            bAtt:SetAttitudeTowards(aAtt, EAIAttitude.AIA_Friendly)
                        end
                    end
                end
            end)
        end
    end
end

function AI:makePositionSpec(pos)
    local ok, result = pcall(function()
        local worldPos = NewObject("WorldPosition")
        local vec = self.geometry.toV4(pos)

        local okSetA = pcall(function()
            worldPos:SetVector4(worldPos, vec)
        end)

        if not okSetA then
            pcall(function()
                worldPos:SetVector4(vec)
            end)
        end

        local spec = NewObject("AIPositionSpec")
        local okSpecA = pcall(function()
            spec:SetWorldPosition(spec, worldPos)
        end)

        if not okSpecA then
            pcall(function()
                spec:SetWorldPosition(worldPos)
            end)
        end

        return spec
    end)

    if ok and result then return result end

    self.log("makePositionSpec FAILED: " .. tostring(result))
    return nil
end

function AI:makeCommand(commandName)
    local cmd = nil

    pcall(function()
        cmd = NewObject(commandName)
    end)

    if cmd then return cmd end

    pcall(function()
        cmd = NewObject("handle:" .. commandName)
    end)

    return cmd
end

function AI:makeMoveCommand(positionSpec, movementType, desiredDistance, finishWhenDestinationReached)
    local cmd = nil

    pcall(function()
        cmd = NewObject("handle:AIMoveToCommand")
    end)

    if not cmd then
        pcall(function()
            cmd = NewObject("AIMoveToCommand")
        end)
    end

    if not cmd then return nil end

    local movement = movementType or self.settings.CHASE_MOVEMENT_TYPE
    local stopDistance = desiredDistance or self.settings.CHASE_STOP_DISTANCE

    pcall(function() cmd.movementTarget = positionSpec end)
    pcall(function() cmd.rotateEntityTowardsFacingTarget = true end)
    pcall(function() cmd.ignoreNavigation = self.settings.CHASE_IGNORE_NAVIGATION end)
    pcall(function() cmd.desiredDistanceFromTarget = stopDistance end)
    pcall(function() cmd.finishWhenDestinationReached = finishWhenDestinationReached ~= false end)
    pcall(function() cmd.movementType = Enum.new("moveMovementType", movement) end)
    pcall(function() cmd.movementType = movement end)

    return cmd
end

function AI:getPlayerEntityReference()
    if self.playerEntityReference then
        return self.playerEntityReference
    end

    local ok, result = pcall(function()
        return CreateEntityReference("#player", {})
    end)

    if ok and result then
        self.playerEntityReference = result
        return result
    end

    ok, result = pcall(function()
        return CreateEntityReference("#player", nil)
    end)

    if ok and result then
        self.playerEntityReference = result
        return result
    end

    if not self.playerEntityReferenceWarningLogged then
        self.playerEntityReferenceWarningLogged = true
        self.log("CreateEntityReference(#player) unavailable; combat threat command disabled")
    end

    return nil
end

function AI:sendCommand(npc, cmd)
    if not npc or not cmd then return false end

    local sent = false

    pcall(function()
        local controller = npc:GetAIControllerComponent()
        if controller then
            controller:SendCommand(cmd)
            sent = true
        end
    end)

    return sent
end

function AI:sendCombatThreat(npc)
    local playerRef = self:getPlayerEntityReference()
    if not playerRef then return false end

    local cmd = self:makeCommand("AIInjectCombatThreatCommand")
    if not cmd then return false end

    pcall(function() cmd.targetPuppetRef = playerRef end)
    pcall(function() cmd.duration = 120.0 end)
    pcall(function() cmd.dontForceHostileAttitude = false end)
    pcall(function() cmd.isPersistent = true end)

    return self:sendCommand(npc, cmd)
end

function AI:sendMeleeAttack(npc)
    local playerRef = self:getPlayerEntityReference()
    if not playerRef then return false end

    local cmd = self:makeCommand("AIMeleeAttackCommand")
    if not cmd then return false end

    pcall(function() cmd.targetOverridePuppetRef = playerRef end)
    pcall(function() cmd.duration = 4.0 end)

    return self:sendCommand(npc, cmd)
end

function AI:setAggressiveCombatPreset(npc)
    local cmd = self:makeCommand("AISetCombatPresetCommand")
    if not cmd then return false end

    pcall(function()
        cmd.combatPreset = Enum.new("EAICombatPreset", "IsAggressive")
    end)

    return self:sendCommand(npc, cmd)
end

function AI:sendMoveToPosition(npc, targetPos, movementType, desiredDistance, logLabel)
    if not npc or not targetPos then return false end

    self:wake(npc)

    local positionSpec = self:makePositionSpec({
        x = targetPos.x,
        y = targetPos.y,
        z = targetPos.z,
        w = 1
    })

    if not positionSpec then return false end

    local cmd = self:makeMoveCommand(positionSpec, movementType, desiredDistance)

    if not cmd then
        self.log(tostring(logLabel or "MoveToPosition") .. " FAILED: could not create AIMoveToCommand")
        return false
    end

    local sent = self:sendCommand(npc, cmd)

    if sent and logLabel then
        self.log(tostring(logLabel) .. " sent")
    end

    return sent
end

function AI:sendMoveToPlayer(npc, forceCommand)
    local player = Game.GetPlayer()
    if not player or not npc then return false end

    local npcPos = nil
    local playerPos = nil

    local okPos = pcall(function()
        npcPos = npc:GetWorldPosition()
        playerPos = player:GetWorldPosition()
    end)

    if not okPos or not npcPos or not playerPos then
        return false
    end

    local dist = self.geometry.distance(npcPos, playerPos)

    if not forceCommand and dist <= self.settings.CHASE_REISSUE_DISTANCE then
        return false
    end

    return self:sendMoveToPosition(
        npc,
        { x = playerPos.x, y = playerPos.y, z = playerPos.z, w = 1 },
        self.settings.CHASE_MOVEMENT_TYPE,
        self.settings.CHASE_STOP_DISTANCE,
        "MoveToPlayer | dist=" .. tostring(math.floor(dist))
    )
end

function AI:prime(npc)
    local player = Game.GetPlayer()
    if not player or not npc then return end

    self:wake(npc)

    pcall(function()
        local npcAtt = npc:GetAttitudeAgent()
        local playerAtt = player:GetAttitudeAgent()

        if npcAtt and playerAtt then
            pcall(function() npcAtt:SetAttitudeGroup(n"hostile") end)
            npcAtt:SetAttitudeTowards(playerAtt, EAIAttitude.AIA_Hostile)
            playerAtt:SetAttitudeTowards(npcAtt, EAIAttitude.AIA_Hostile)
        end
    end)

    pcall(function()
        local reactionComp = npc.reactionComponent

        if reactionComp then
            reactionComp:SetReactionPreset(
                TweakDBInterface.GetReactionPresetRecord(
                    TweakDBID.new("ReactionPresets.Ganger_Aggressive")
                )
            )
        end
    end)
end

function AI:isNPCInCombat(npc)
    if not npc then return false end

    local ok, result = pcall(function()
        local method = npc.IsInCombat
        if method then
            return method(npc)
        end

        return false
    end)

    if ok and result == true then return true end

    ok, result = pcall(function()
        local reactionComp = npc.reactionComponent

        if reactionComp and reactionComp.IsInCombat then
            return reactionComp:IsInCombat()
        end

        return false
    end)

    if ok and result == true then return true end

    ok, result = pcall(function()
        return npc:GetHighLevelStateFromBlackboard()
    end)

    if ok and result then
        local state = string.lower(tostring(result))
        if string.find(state, "combat") then return true end
    end

    return false
end

function AI:isPlayerInCombat()
    local player = Game.GetPlayer()
    if not player then return false end

    local ok, result = pcall(function()
        return player:IsInCombat()
    end)

    return ok and result == true
end

function AI:shouldForceCombatWithPlayer(npc)
    local dist = self:getDistanceFromPlayer(npc)

    if dist <= self.settings.AUTO_COMBAT_DISTANCE then
        return true
    end

    return self:isPlayerInCombat() and dist <= self.settings.COMBAT_JOIN_DISTANCE
end

function AI:sendSearchMoveAroundHome(npc)
    if not npc or self:isNPCInCombat(npc) then return false end

    local meta = self.state.spawnedObjectMetas[npc]
    local home = meta and meta.pos or nil
    if not home then return false end
    local wave = meta and self.waves[meta.waveIndex] or nil

    local currentPos = nil
    local okPos = pcall(function()
        currentPos = npc:GetWorldPosition()
    end)

    if not okPos or not currentPos then return false end

    local target = home
    local player = Game.GetPlayer()
    local playerPos = nil
    local logLabel = nil

    pcall(function()
        if player then
            playerPos = player:GetWorldPosition()
        end
    end)

    if playerPos then
        local distToPlayer = self.geometry.distance(currentPos, playerPos)
        local homeDistToPlayer = self.geometry.distance(home, playerPos)
        local searchRadius = (wave and wave.searchPlayerRadius) or self.settings.SEARCH_PLAYER_RADIUS
        local alwaysSearchPlayer = wave and wave.alwaysSearchPlayer == true

        if alwaysSearchPlayer or distToPlayer <= searchRadius or homeDistToPlayer <= searchRadius then
            local dx = playerPos.x - currentPos.x
            local dy = playerPos.y - currentPos.y
            local len = math.sqrt(dx * dx + dy * dy)

            if len > 0.01 then
                local stepDistance = (wave and wave.searchStepDistance) or self.settings.SEARCH_STEP_DISTANCE
                local step = math.min(
                    stepDistance,
                    math.max(2.0, distToPlayer - self.settings.AUTO_COMBAT_DISTANCE)
                )

                target = {
                    x = currentPos.x + (dx / len) * step,
                    y = currentPos.y + (dy / len) * step,
                    z = currentPos.z,
                    w = 1
                }

                logLabel =
                    "SearchMove | wave=" ..
                    tostring(wave and wave.name or "unknown") ..
                    " | dist=" ..
                    tostring(math.floor(distToPlayer)) ..
                    " | step=" ..
                    tostring(math.floor(step))
            end
        end
    end

    if target == home and self.geometry.distance(currentPos, home) <= self.settings.SEARCH_LEASH_DISTANCE then
        local phase = ((meta.spawnIndex or 1) * 1.618) + (math.floor(self.state.elapsed / self.settings.CHASE_PLAYER_INTERVAL) * 0.9)

        target = {
            x = home.x + math.cos(phase) * self.settings.SEARCH_RADIUS,
            y = home.y + math.sin(phase) * self.settings.SEARCH_RADIUS,
            z = home.z,
            w = 1
        }
    end

    return self:sendMoveToPosition(
        npc,
        target,
        (wave and wave.searchMovementType) or self.settings.SEARCH_MOVEMENT_TYPE,
        self.settings.SEARCH_STOP_DISTANCE,
        logLabel
    )
end

function AI:forceAggro(npc)
    local player = Game.GetPlayer()
    if not player or not npc then return end

    self:wake(npc)
    self:prime(npc)

    pcall(function()
        local reactionComp = npc.reactionComponent
        if reactionComp then
            reactionComp:TriggerCombat(player)
        end
    end)

    pcall(function()
        local stim = npc:GetStimReactionComponent()
        if stim then
            stim:ActivateReactionLookAt(player, true, false, 30.0, true)
        end
    end)

    pcall(function()
        local controller = npc:GetAIControllerComponent()
        if controller then
            controller:SetBehaviorArgument(n"CombatTarget", ToVariant(player))
            controller:SetBehaviorArgument(n"MoveTarget", ToVariant(player))
        end
    end)

    self:sendCombatThreat(npc)
    self:setAggressiveCombatPreset(npc)
end

function AI:chase(npc, forceCommand)
    if not npc then return end

    local meta = self.state.spawnedObjectMetas[npc]
    local wave = meta and self.waves[meta.waveIndex] or nil

    if wave and wave.disableAIMovement then
        self:prime(npc)
        return
    end

    if wave and wave.disableDirectChase then
        self:prime(npc)
        self:sendSearchMoveAroundHome(npc)
        return
    end

    local dist = self:getDistanceFromPlayer(npc)
    local directChaseDistance = self.settings.DIRECT_CHASE_DISTANCE or self.settings.AUTO_COMBAT_DISTANCE or 18.0

    if not forceCommand and dist > directChaseDistance then
        self:prime(npc)
        self:sendSearchMoveAroundHome(npc)
        return
    end

    self:forceAggro(npc)

    if wave and wave.forceMeleeAttack then
        self:sendMeleeAttack(npc)
    end

    self:sendMoveToPlayer(npc, forceCommand)
end

function AI:isNPCDefeated(npc)
    if not npc then return true end

    local okDefined, defined = pcall(function()
        return IsDefined(npc)
    end)

    if not okDefined or defined ~= true then return true end

    local checks = {
        "IsDead",
        "IsDeadNoStatPool",
        "IsDefeated",
        "IsIncapacitated",
        "IsUnconscious",
        "IsAboutToDie",
        "IsAboutToBeDefeated",
        "IsAboutToDieOrDefeated",
        "IsTurnedOffNoStatusEffect"
    }

    for _, methodName in ipairs(checks) do
        local ok, result = pcall(function()
            local method = npc[methodName]
            if method then return method(npc) end
            return false
        end)

        if ok and result == true then return true end
    end

    local activeOk, active = pcall(function()
        local method = npc.IsActive
        if method then return method(npc) end
        return true
    end)

    if activeOk and active == false then return true end

    local stateOk, state = pcall(function()
        return npc:GetHighLevelStateFromBlackboard()
    end)

    if stateOk and state then
        if gamedataNPCHighLevelState then
            if state == gamedataNPCHighLevelState.Unconscious then return true end
            if gamedataNPCHighLevelState.Dead and state == gamedataNPCHighLevelState.Dead then return true end
        end

        local stateText = string.lower(tostring(state))
        if
            string.find(stateText, "dead") or
            string.find(stateText, "defeat") or
            string.find(stateText, "unconscious") or
            string.find(stateText, "incapacitat") or
            string.find(stateText, "disabled")
        then
            return true
        end
    end

    local healthOk, healthValue = pcall(function()
        local statPools = Game.GetStatPoolsSystem()
        if not statPools then return nil end
        return statPools:GetStatPoolValue(npc:GetEntityID(), gamedataStatPoolType.Health, false)
    end)

    if healthOk and healthValue ~= nil and healthValue <= 0 then return true end

    local statusOk, hasStatus = pcall(function()
        if not StatusEffectHelper or not TweakDBID then return false end

        local defeatedStatuses = {
            "BaseStatusEffect.Unconscious",
            "BaseStatusEffect.Defeated",
            "BaseStatusEffect.DefeatedWithRecover",
            "BaseStatusEffect.DefeatedWithRecovery",
            "BaseStatusEffect.DefeatedFinisherWorkspot",
            "BaseStatusEffect.Dead"
        }

        for _, statusId in ipairs(defeatedStatuses) do
            if StatusEffectHelper.HasStatusEffect(npc, TweakDBID.new(statusId)) then
                return true
            end
        end

        return false
    end)

    return statusOk and hasStatus == true
end

function AI:applyStatusEffect(npc, statusId)
    if not npc or not StatusEffectHelper or not TweakDBID then return false end

    local tdbid = TweakDBID.new(statusId)

    local ok = pcall(function()
        StatusEffectHelper.ApplyStatusEffect(npc, tdbid)
    end)

    if ok then return true end

    ok = pcall(function()
        StatusEffectHelper.ApplyStatusEffect(npc, tdbid, 1)
    end)

    return ok == true
end

function AI:killNPC(npc)
    if not npc then return false end
    if self:isNPCDefeated(npc) then return true end

    local affected = false
    local entityID = nil

    pcall(function()
        entityID = npc:GetEntityID()
    end)

    if entityID then
        local statPools = nil

        pcall(function()
            statPools = Game.GetStatPoolsSystem()
        end)

        if statPools then
            local attempts = {
                function()
                    statPools:RequestSettingStatPoolValue(entityID, gamedataStatPoolType.Health, 0, nil)
                end,
                function()
                    statPools:RequestSettingStatPoolValue(entityID, gamedataStatPoolType.Health, 0)
                end,
                function()
                    statPools:RequestChangingStatPoolValue(entityID, gamedataStatPoolType.Health, -999999, nil)
                end,
                function()
                    statPools:RequestChangingStatPoolValue(entityID, gamedataStatPoolType.Health, -999999)
                end
            }

            for _, attempt in ipairs(attempts) do
                local ok = pcall(attempt)

                if ok then
                    affected = true
                    break
                end
            end
        end
    end

    local defeatStatuses = {
        "BaseStatusEffect.Defeated",
        "BaseStatusEffect.Unconscious",
        "BaseStatusEffect.DefeatedWithRecover",
        "BaseStatusEffect.Dead"
    }

    for _, statusId in ipairs(defeatStatuses) do
        if self:applyStatusEffect(npc, statusId) then
            affected = true
            break
        end
    end

    local killAttempts = {
        function()
            npc:Kill()
        end,
        function()
            npc:Kill(Game.GetPlayer(), false)
        end,
        function()
            npc:Kill(nil, false)
        end
    }

    for _, attempt in ipairs(killAttempts) do
        local ok = pcall(attempt)

        if ok then
            affected = true
            break
        end
    end

    return affected
end

function AI:killAllSpawned()
    local attempted = 0
    local affected = 0

    for _, npc in ipairs(self.state.spawnedObjects) do
        if npc and not self:isNPCDefeated(npc) then
            attempted = attempted + 1

            if self:killNPC(npc) then
                affected = affected + 1
            end
        end
    end

    self.log(
        "Manual kill all spawned NPCs | attempted=" ..
        tostring(attempted) ..
        " | affected=" ..
        tostring(affected)
    )

    return attempted, affected
end

function AI:scheduleAwareness(npc, delay, reason)
    if not npc then return end

    table.insert(self.state.delayedCombatActions, {
        npc = npc,
        fireAt = self.state.elapsed + delay,
        reason = reason or "scheduled"
    })
end

function AI:scheduleSpawnAwarenessBurst(npc)
    local delays = self.settings.SPAWN_AWARENESS_DELAYS or { 0.45, 0.9, 1.5, 2.5, 4.0, 6.0 }

    for _, delay in ipairs(delays) do
        self:scheduleAwareness(npc, delay, "post-spawn wake " .. tostring(delay))
    end
end

function AI:updateDelayedAwareness()
    for i = #self.state.delayedCombatActions, 1, -1 do
        local item = self.state.delayedCombatActions[i]

        if self.state.elapsed >= item.fireAt then
            local okDefined, defined = pcall(function()
                return IsDefined(item.npc)
            end)

            if item.npc and okDefined and defined then
                self.log("Delayed awareness refresh: " .. tostring(item.reason))
                self:prime(item.npc)

                local meta = self.state.spawnedObjectMetas[item.npc]
                local wave = meta and self.waves[meta.waveIndex] or nil

                if wave and (wave.forceMeleeAttack or wave.alwaysSearchPlayer) then
                    self:updateEncounterNPC(item.npc, true)
                end
            end

            table.remove(self.state.delayedCombatActions, i)
        end
    end
end

function AI:updateEncounterNPC(npc, allowSearchMove)
    local okDefined, defined = pcall(function()
        return IsDefined(npc)
    end)

    if not npc or not okDefined or not defined then return end

    local meta = self.state.spawnedObjectMetas[npc]
    local wave = meta and self.waves[meta.waveIndex] or nil

    if wave and wave.disableAIMovement then
        self:prime(npc)
        return
    end

    self:prime(npc)

    if self:isNPCInCombat(npc) or self:shouldForceCombatWithPlayer(npc) then
        self:chase(npc, false)
    elseif allowSearchMove then
        self:sendSearchMoveAroundHome(npc)
    end
end

function AI:updateEncounterNPCs(allowSearchMove)
    self:setAllSpawnedFriendly()

    for _, npc in ipairs(self.state.spawnedObjects) do
        self:updateEncounterNPC(npc, allowSearchMove)
    end

    self:setAllSpawnedFriendly()
end

function AI:forceAggroAll()
    self:setAllSpawnedFriendly()

    for _, npc in ipairs(self.state.spawnedObjects) do
        local okDefined, defined = pcall(function()
            return IsDefined(npc)
        end)

        if npc and okDefined and defined then
            self:chase(npc, true)
        end
    end

    self:setAllSpawnedFriendly()
end

return AI
