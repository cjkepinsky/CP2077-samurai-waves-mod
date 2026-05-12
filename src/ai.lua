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

function AI:getNPCWave(npc)
    local meta = self.state.spawnedObjectMetas[npc]
    local wave = meta and self.waves[meta.waveIndex] or nil

    return wave, meta
end

function AI:getHoldUntilPlayerDistance(wave)
    local distance = wave and tonumber(wave.holdUntilPlayerDistance)

    if distance and distance > 0 then
        return distance
    end

    return nil
end

function AI:isHoldingUntilPlayer(npc, wave, meta)
    if not npc then return false end

    if not wave or not meta then
        local resolvedWave, resolvedMeta = self:getNPCWave(npc)
        wave = wave or resolvedWave
        meta = meta or resolvedMeta
    end

    local holdDistance = self:getHoldUntilPlayerDistance(wave)
    if not holdDistance then return false end
    if meta and meta.holdReleased == true then return false end

    local dist = self:getDistanceFromPlayer(npc)

    if dist <= holdDistance then
        if meta then
            meta.holdReleased = true
            meta.holdReleasedAt = self.state.elapsed
        end

        self.log(
            "Hold-until-player released | wave=" ..
            tostring(wave and wave.name or "unknown") ..
            " | index=" ..
            tostring(meta and meta.spawnIndex or "unknown") ..
            " | dist=" ..
            tostring(math.floor(dist * 10) / 10) ..
            " | threshold=" ..
            tostring(holdDistance)
        )

        return false
    end

    return true
end

function AI:shouldSuppressHoldAwareness(npc, wave, meta)
    if not wave or not meta then
        local resolvedWave, resolvedMeta = self:getNPCWave(npc)
        wave = wave or resolvedWave
        meta = meta or resolvedMeta
    end

    if wave and wave.silentUntilPlayerDistance == false then
        return false
    end

    return self:isHoldingUntilPlayer(npc, wave, meta)
end

function AI:triggerHoldWakeAttack(npc, wave, meta)
    if not npc or not wave or wave.forceMeleeAttackOnWake ~= true then return false end
    if not meta or meta.holdReleased ~= true or meta.holdWakeAttackSent == true then return false end

    meta.holdWakeAttackSent = true

    local quietCombat = wave.suppressCombatBarks == true or wave.silentUntilPlayerDistance == true

    self:forceAggro(npc, {
        suppressReactionPreset = quietCombat,
        suppressReactionTrigger = quietCombat,
        suppressStimReaction = quietCombat,
        suppressCombatThreat = quietCombat and wave.quietWakeSuppressCombatThreat == true,
        suppressCombatPreset = quietCombat and wave.quietWakeSuppressCombatPreset == true
    })
    self:sendMeleeAttack(npc)

    self.log(
        "Hold wake attack sent | wave=" ..
        tostring(wave.name) ..
        " | index=" ..
        tostring(meta.spawnIndex or "unknown")
    )

    return true
end

function AI:setAttitudeToPlayer(npc, attitude)
    local player = Game.GetPlayer()
    if not player or not npc then return false end

    local ok = pcall(function()
        local npcAtt = npc:GetAttitudeAgent()
        local playerAtt = player:GetAttitudeAgent()

        if npcAtt and playerAtt then
            npcAtt:SetAttitudeTowards(playerAtt, attitude)
            playerAtt:SetAttitudeTowards(npcAtt, attitude)
        end
    end)

    return ok == true
end

function AI:setHostileToPlayer(npc)
    local ok = pcall(function()
        local npcAtt = npc:GetAttitudeAgent()

        if npcAtt then
            npcAtt:SetAttitudeGroup(n"hostile")
        end
    end)

    return self:setAttitudeToPlayer(npc, EAIAttitude.AIA_Hostile) or ok == true
end

function AI:setPassiveUntilRelease(npc, wave, meta)
    if not npc or not wave or wave.passiveUntilPlayerDistance == false then return false end
    if meta and meta.holdReleased == true then return false end

    local attitude = EAIAttitude.AIA_Neutral

    if wave.passiveUntilPlayerAttitude == "friendly" then
        attitude = EAIAttitude.AIA_Friendly
    end

    local ok = self:setAttitudeToPlayer(npc, attitude)

    if ok and meta and meta.passiveUntilReleaseLogged ~= true then
        meta.passiveUntilReleaseLogged = true
        self.log(
            "Passive hold attitude applied | wave=" ..
            tostring(wave.name or "unknown") ..
            " | index=" ..
            tostring(meta.spawnIndex or "unknown") ..
            " | attitude=" ..
            tostring(wave.passiveUntilPlayerAttitude or "neutral")
        )
    end

    return ok
end

function AI:getHeldHomeDistance(npc, meta)
    local home = meta and meta.pos or nil
    if not npc or not home then return nil end

    local ok, pos = pcall(function()
        return npc:GetWorldPosition()
    end)

    if ok and pos then
        return self.geometry.distance(pos, home)
    end

    return nil
end

function AI:enforceHoldPosition(npc, wave, meta)
    if not npc or not wave or not meta or not meta.pos then return false end
    if wave.holdPositionUntilPlayerDistance ~= true then return false end
    if meta.holdReleased == true then return false end

    local interval = tonumber(wave.holdPositionRefreshInterval) or 1.0

    if meta.lastHoldPositionCommandAt and self.state.elapsed - meta.lastHoldPositionCommandAt < interval then
        return false
    end

    local drift = self:getHeldHomeDistance(npc, meta)
    local tolerance = tonumber(wave.holdPositionTolerance) or 0.75
    if drift and drift <= tolerance then return false end

    meta.lastHoldPositionCommandAt = self.state.elapsed

    local sent = self:sendMoveToPosition(
        npc,
        meta.pos,
        wave.holdPositionMovementType or "Walk",
        tonumber(wave.holdPositionStopDistance) or 0.25,
        nil,
        {
            ignoreInCombat = true,
            removeAfterCombat = false,
            useStart = false,
            useStop = false,
            alwaysUseStealth = false
        }
    )

    if sent then
        self:setPassiveUntilRelease(npc, wave, meta)

        if meta.holdPositionLogged ~= true then
            meta.holdPositionLogged = true
            self.log(
                "Hold position enforced | wave=" ..
                tostring(wave.name or "unknown") ..
                " | index=" ..
                tostring(meta.spawnIndex or "unknown") ..
                " | drift=" ..
                tostring(drift and math.floor(drift * 10) / 10 or "unknown")
            )
        end
    end

    return sent
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

function AI:makeMoveCommand(positionSpec, movementType, desiredDistance, finishWhenDestinationReached, options)
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

    if options and options.facingTargetSpec then
        pcall(function() cmd.facingTarget = options.facingTargetSpec end)
        pcall(function() cmd.rotateEntityTowardsFacingTarget = true end)
    end

    local ignoreNavigation = self.settings.CHASE_IGNORE_NAVIGATION
    if options and options.ignoreNavigation ~= nil then
        ignoreNavigation = options.ignoreNavigation == true
    end

    pcall(function() cmd.ignoreNavigation = ignoreNavigation end)
    pcall(function() cmd.desiredDistanceFromTarget = stopDistance end)
    pcall(function() cmd.finishWhenDestinationReached = finishWhenDestinationReached ~= false end)
    pcall(function() cmd.movementType = Enum.new("moveMovementType", movement) end)
    pcall(function() cmd.movementType = movement end)

    if options then
        if options.alwaysUseStealth ~= nil then
            pcall(function() cmd.alwaysUseStealth = options.alwaysUseStealth == true end)
        end

        if options.useStart ~= nil then
            pcall(function() cmd.useStart = options.useStart == true end)
        end

        if options.useStop ~= nil then
            pcall(function() cmd.useStop = options.useStop == true end)
        end

        if options.removeAfterCombat ~= nil then
            pcall(function() cmd.removeAfterCombat = options.removeAfterCombat == true end)
        end

        if options.ignoreInCombat ~= nil then
            pcall(function() cmd.ignoreInCombat = options.ignoreInCombat == true end)
        end
    end

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

function AI:getNavigationSystem()
    local ok, nav = pcall(function()
        return Game.GetNavigationSystem()
    end)

    if ok and nav then return nav end

    ok, nav = pcall(function()
        return Game.GetAINavigationSystem()
    end)

    if ok and nav then return nav end

    return nil
end

function AI:getHumanNavmeshAgentSize()
    local ok, agentSize = pcall(function()
        return Enum.new("NavGenAgentSize", "Human")
    end)

    if ok and agentSize then return agentSize end

    ok, agentSize = pcall(function()
        return NavGenAgentSize and NavGenAgentSize.Human
    end)

    if ok and agentSize then return agentSize end

    return 0
end

function AI:extractNavmeshPoint(result, alternatePoint)
    local function asPoint(candidate)
        if not candidate then return nil end

        local ok, x, y, z, w = pcall(function()
            return candidate.x, candidate.y, candidate.z, candidate.w
        end)

        if ok and x and y and z then
            return { x = x, y = y, z = z, w = w or 1 }
        end

        return nil
    end

    local point = asPoint(result)
    if point then return point end

    if result then
        local okPoint, resultPoint = pcall(function()
            return result.point
        end)

        if okPoint then
            point = asPoint(resultPoint)
        end

        if point then return point end
    end

    return asPoint(alternatePoint)
end

function AI:findHumanNavmeshPoint(pos, radius)
    local nav = self:getNavigationSystem()
    if not nav then return nil end

    local origin = self.geometry.toV4(pos)
    local agentSize = self:getHumanNavmeshAgentSize()
    local attempts = {
        function()
            return nav:FindPointInSphereOnlyHumanNavmesh(origin, radius, agentSize, false)
        end,
        function()
            return nav.FindPointInSphereOnlyHumanNavmesh(nav, origin, radius, agentSize, false)
        end,
        function()
            return nav:FindPointInSphereOnlyHumanNavmesh(origin, radius, 0, false)
        end,
        function()
            return nav.FindPointInSphereOnlyHumanNavmesh(nav, origin, radius, 0, false)
        end
    }

    for _, attempt in ipairs(attempts) do
        local ok, result, alternatePoint = pcall(attempt)

        if ok then
            local point = self:extractNavmeshPoint(result, alternatePoint)

            if point then
                local navPos = { x = point.x, y = point.y, z = point.z, w = point.w or 1 }

                if self.geometry.distance(pos, navPos) <= radius + 0.01 then
                    return navPos
                end
            end
        end
    end

    return nil
end

function AI:projectSearchTargetToHumanNavmesh(wave, target, fallback)
    local radius = wave and (wave.searchTargetHumanNavmeshCheckRadius or wave.humanNavmeshCheckRadius) or nil
    if not radius or radius <= 0 then return target end

    local navPos = self:findHumanNavmeshPoint(target, radius)
    if navPos then return navPos end

    return fallback or target
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

function AI:switchToPrimaryWeapon(npc)
    local cmd = self:makeCommand("AISwitchToPrimaryWeaponCommand")
    if not cmd then return false end

    pcall(function() cmd.unEquip = false end)

    return self:sendCommand(npc, cmd)
end

function AI:sendLookAtTarget(npc, duration)
    local playerRef = self:getPlayerEntityReference()
    if not playerRef then return false end

    local cmd = self:makeCommand("AIInjectLookatTargetCommand")
    if not cmd then return false end

    pcall(function() cmd.targetPuppetRef = playerRef end)
    pcall(function() cmd.duration = duration or 10.0 end)
    pcall(function() cmd.immediately = true end)

    return self:sendCommand(npc, cmd)
end

function AI:sendMoveToPosition(npc, targetPos, movementType, desiredDistance, logLabel, options)
    if not npc or not targetPos then return false end

    self:wake(npc)

    local positionSpec = self:makePositionSpec({
        x = targetPos.x,
        y = targetPos.y,
        z = targetPos.z,
        w = 1
    })

    if not positionSpec then return false end

    local moveOptions = options

    if options and options.facingTarget then
        local facingSpec = self:makePositionSpec({
            x = options.facingTarget.x,
            y = options.facingTarget.y,
            z = options.facingTarget.z,
            w = 1
        })

        if facingSpec then
            moveOptions = {}
            for key, value in pairs(options) do
                moveOptions[key] = value
            end
            moveOptions.facingTargetSpec = facingSpec
        end
    end

    local cmd = self:makeMoveCommand(positionSpec, movementType, desiredDistance, nil, moveOptions)

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

function AI:prime(npc, options)
    local player = Game.GetPlayer()
    if not player or not npc then return end

    options = options or {}

    self:wake(npc)
    self:setHostileToPlayer(npc)

    if options.suppressReactionPreset == true then
        return
    end

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

function AI:primeQuietReady(npc, wave, meta)
    if not npc or not wave or wave.readyUntilPlayerDistance ~= true then return false end
    meta = meta or self.state.spawnedObjectMetas[npc]
    if not meta then return false end

    local refreshInterval = tonumber(wave.quietReadyRefreshInterval) or 4.0
    local readyMode = wave.quietReadyMode or "aware"

    if
        meta.quietReadyPrimed == true and
        meta.quietReadyPrimedAt and
        self.state.elapsed - meta.quietReadyPrimedAt < refreshInterval
    then
        return true
    end

    meta.quietReadyPrimed = true
    meta.quietReadyPrimedAt = self.state.elapsed

    self:setPassiveUntilRelease(npc, wave, meta)

    if readyMode == "weaponOnly" then
        if wave.wakeQuietReady == true then
            self:wake(npc)
        end
    else
        self:prime(npc, { suppressReactionPreset = true })
    end

    self:switchToPrimaryWeapon(npc)

    if readyMode ~= "weaponOnly" and wave.lookAtPlayerUntilPlayerDistance ~= false then
        self:sendLookAtTarget(npc, refreshInterval + 0.5)
    end

    local statuses = wave.quietReadyStatusEffects
    if type(statuses) == "table" then
        for _, statusId in ipairs(statuses) do
            self:applyStatusEffect(npc, statusId)
        end
    end

    if meta.quietReadyLogged ~= true then
        meta.quietReadyLogged = true
        self.log(
            "Quiet ready applied | wave=" ..
            tostring(wave.name or "unknown") ..
            " | index=" ..
            tostring(meta.spawnIndex or "unknown") ..
            " | mode=" ..
            tostring(readyMode)
        )
    end

    return true
end

function AI:primeSearchAlert(npc, wave)
    if not npc then return end

    self:prime(npc)
    self:setAggressiveCombatPreset(npc)
    self:switchToPrimaryWeapon(npc)
    self:sendLookAtTarget(npc, 10.0)

    pcall(function()
        local player = Game.GetPlayer()
        local stim = npc:GetStimReactionComponent()
        if player and stim then
            stim:ActivateReactionLookAt(player, true, false, 10.0, true)
        end
    end)

    local statuses = (wave and wave.searchAlertStatusEffects) or self.settings.SEARCH_ALERT_STATUS_EFFECTS
    if type(statuses) ~= "table" then return end

    for _, statusId in ipairs(statuses) do
        self:applyStatusEffect(npc, statusId)
    end
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

function AI:shouldForceCombatWithPlayer(npc, wave, meta)
    if not wave or not meta then
        local resolvedWave, resolvedMeta = self:getNPCWave(npc)
        wave = wave or resolvedWave
        meta = meta or resolvedMeta
    end

    if self:isHoldingUntilPlayer(npc, wave, meta) then
        return false
    end

    local dist = self:getDistanceFromPlayer(npc)
    local autoCombatDistance = (wave and tonumber(wave.autoCombatDistance)) or self.settings.AUTO_COMBAT_DISTANCE
    local combatJoinDistance = (wave and tonumber(wave.combatJoinDistance)) or self.settings.COMBAT_JOIN_DISTANCE

    if dist <= autoCombatDistance then
        return true
    end

    return self:isPlayerInCombat() and dist <= combatJoinDistance
end

function AI:sendSearchMoveAroundHome(npc, allowPlayerDirectedSearch)
    if not npc or self:isNPCInCombat(npc) then return false end

    local meta = self.state.spawnedObjectMetas[npc]
    local home = meta and meta.pos or nil
    if not home then return false end
    local wave = meta and self.waves[meta.waveIndex] or nil

    if self:isHoldingUntilPlayer(npc, wave, meta) then
        return false
    end

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

    local localSearchOnly = wave and wave.searchAroundHomeOnly == true
    local canUsePlayerPosition = (not localSearchOnly) or allowPlayerDirectedSearch == true

    if localSearchOnly then
        self:primeSearchAlert(npc, wave)
    end

    if playerPos and canUsePlayerPosition then
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
                local autoCombatDistance =
                    (wave and tonumber(wave.autoCombatDistance)) or
                    self.settings.AUTO_COMBAT_DISTANCE
                local step = math.min(
                    stepDistance,
                    math.max(2.0, distToPlayer - autoCombatDistance)
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

    local searchLeashDistance = (wave and wave.searchLeashDistance) or self.settings.SEARCH_LEASH_DISTANCE

    if target == home and self.geometry.distance(currentPos, home) <= searchLeashDistance then
        local phase = ((meta.spawnIndex or 1) * 1.618) + (math.floor(self.state.elapsed / self.settings.CHASE_PLAYER_INTERVAL) * 0.9)
        local searchRadius = (wave and wave.searchRadius) or self.settings.SEARCH_RADIUS

        target = {
            x = home.x + math.cos(phase) * searchRadius,
            y = home.y + math.sin(phase) * searchRadius,
            z = home.z,
            w = 1
        }

        logLabel =
            "SearchMoveLocal | wave=" ..
            tostring(wave and wave.name or "unknown")
    end

    local searchMoveOptions = nil

    if localSearchOnly then
        searchMoveOptions = {
            alwaysUseStealth = wave and wave.searchAlwaysUseStealth == true,
            facingTarget = playerPos,
            useStart = true,
            useStop = true,
            removeAfterCombat = true,
            ignoreInCombat = false
        }
    end

    target = self:projectSearchTargetToHumanNavmesh(wave, target, home)

    return self:sendMoveToPosition(
        npc,
        target,
        (wave and wave.searchMovementType) or self.settings.SEARCH_MOVEMENT_TYPE,
        (wave and wave.searchStopDistance) or self.settings.SEARCH_STOP_DISTANCE,
        logLabel,
        searchMoveOptions
    )
end

function AI:forceAggro(npc, options)
    local player = Game.GetPlayer()
    if not player or not npc then return end

    options = options or {}

    self:wake(npc)
    self:prime(npc, {
        suppressReactionPreset = options.suppressReactionPreset == true
    })

    if options.suppressReactionTrigger ~= true then
        pcall(function()
            local reactionComp = npc.reactionComponent
            if reactionComp then
                reactionComp:TriggerCombat(player)
            end
        end)
    end

    if options.suppressStimReaction ~= true then
        pcall(function()
            local stim = npc:GetStimReactionComponent()
            if stim then
                stim:ActivateReactionLookAt(player, true, false, 30.0, true)
            end
        end)
    end

    pcall(function()
        local controller = npc:GetAIControllerComponent()
        if controller then
            controller:SetBehaviorArgument(n"CombatTarget", ToVariant(player))
            controller:SetBehaviorArgument(n"MoveTarget", ToVariant(player))
        end
    end)

    if options.suppressCombatThreat ~= true then
        self:sendCombatThreat(npc)
    end

    if options.suppressCombatPreset ~= true then
        self:setAggressiveCombatPreset(npc)
    end
end

function AI:chase(npc, forceCommand)
    if not npc then return end

    local meta = self.state.spawnedObjectMetas[npc]
    local wave = meta and self.waves[meta.waveIndex] or nil

    if not forceCommand and self:isHoldingUntilPlayer(npc, wave, meta) then
        return
    end

    if wave and wave.disableAIMovement then
        self:prime(npc)
        return
    end

    if wave and wave.disableDirectChase then
        self:prime(npc)
        self:sendSearchMoveAroundHome(npc, true)
        return
    end

    local dist = self:getDistanceFromPlayer(npc)
    local directChaseDistance =
        (wave and tonumber(wave.directChaseDistance)) or
        self.settings.DIRECT_CHASE_DISTANCE or
        self.settings.AUTO_COMBAT_DISTANCE or
        18.0

    if not forceCommand and dist > directChaseDistance then
        self:prime(npc)
        self:sendSearchMoveAroundHome(npc, true)
        return
    end

    self:forceAggro(npc)

    if wave and wave.forceMeleeAttack then
        self:sendMeleeAttack(npc)
    end

    self:sendMoveToPlayer(npc, forceCommand)
end

function AI:isNPCConfirmedDefeated(npc)
    if not npc then return false end

    local okDefined, defined = pcall(function()
        return IsDefined(npc)
    end)

    if not okDefined or defined ~= true then return false end

    local checks = {
        "IsDead",
        "IsDeadNoStatPool",
        "IsDefeated",
        "IsIncapacitated",
        "IsUnconscious",
        "IsAboutToDie",
        "IsAboutToBeDefeated",
        "IsAboutToDieOrDefeated"
    }

    for _, methodName in ipairs(checks) do
        local ok, result = pcall(function()
            local method = npc[methodName]
            if method then return method(npc) end
            return false
        end)

        if ok and result == true then return true end
    end

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
            string.find(stateText, "incapacitat")
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

function AI:isNPCDefeated(npc)
    if not npc then return true end

    local okDefined, defined = pcall(function()
        return IsDefined(npc)
    end)

    if not okDefined or defined ~= true then return true end
    if self:isNPCConfirmedDefeated(npc) then return true end

    local activeOk, active = pcall(function()
        local method = npc.IsActive
        if method then return method(npc) end
        return true
    end)

    if activeOk and active == false then return true end

    local turnedOffOk, turnedOff = pcall(function()
        local method = npc.IsTurnedOffNoStatusEffect
        if method then return method(npc) end
        return false
    end)

    return turnedOffOk and turnedOff == true
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
    if self:shouldSuppressHoldAwareness(npc) then
        local _, meta = self:getNPCWave(npc)

        if meta and meta.holdAwarenessSuppressedLogged ~= true then
            meta.holdAwarenessSuppressedLogged = true
            self.log(
                "Spawn awareness suppressed by hold-until-player | wave=" ..
                tostring(meta.waveName or "unknown") ..
                " | index=" ..
                tostring(meta.spawnIndex or "unknown")
            )
        end

        return
    end

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
                local meta = self.state.spawnedObjectMetas[item.npc]
                local wave = meta and self.waves[meta.waveIndex] or nil

                if not self:shouldSuppressHoldAwareness(item.npc, wave, meta) then
                    self.log("Delayed awareness refresh: " .. tostring(item.reason))
                    self:prime(item.npc)

                    if wave and (wave.forceMeleeAttack or wave.alwaysSearchPlayer) then
                        self:updateEncounterNPC(item.npc, true)
                    end
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

    if self:isHoldingUntilPlayer(npc, wave, meta) then
        self:setPassiveUntilRelease(npc, wave, meta)
        self:enforceHoldPosition(npc, wave, meta)
        return
    end

    local wakeAttackSent = self:triggerHoldWakeAttack(npc, wave, meta)

    if wave and wave.disableAIMovement then
        if not wakeAttackSent then
            self:prime(npc)
        end

        return
    end

    self:prime(npc)

    if self:isNPCInCombat(npc) or self:shouldForceCombatWithPlayer(npc, wave, meta) then
        self:chase(npc, false)
    elseif allowSearchMove then
        self:sendSearchMoveAroundHome(npc, false)
    end
end

function AI:updateHeldNPCs()
    for _, npc in ipairs(self.state.spawnedObjects) do
        local wave, meta = self:getNPCWave(npc)

        if wave and meta and self:getHoldUntilPlayerDistance(wave) then
            if self:isHoldingUntilPlayer(npc, wave, meta) then
                self:setPassiveUntilRelease(npc, wave, meta)
                self:primeQuietReady(npc, wave, meta)
                self:enforceHoldPosition(npc, wave, meta)
            elseif wave.forceMeleeAttackOnWake == true and meta.holdWakeAttackSent ~= true then
                self:updateEncounterNPC(npc, false)
            end
        end
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
