local MissionController = {}
MissionController.__index = MissionController

local function tableIsEmpty(t)
    for _, _ in pairs(t) do
        return false
    end
    return true
end

function MissionController.new(deps)
    return setmetatable({
        modName = deps.modName or "Samurai Waves",
        modVersion = deps.modVersion or "unknown",
        state = deps.state,
        settings = deps.settings,
        waves = deps.waves,
        geometry = deps.geometry,
        planner = deps.planner,
        markers = deps.markers,
        treasure = deps.treasure,
        playerRules = deps.playerRules,
        hud = deps.hud,
        ai = deps.ai,
        spawner = deps.spawner,
        log = deps.log,
        autoStartHandled = false,
        autoStartTimer = 0
    }, MissionController)
end

function MissionController:hasPendingWaveWork(waveIndex)
    for _, item in ipairs(self.state.spawnQueue) do
        if item.waveIndex == waveIndex then return true end
    end

    for _, item in ipairs(self.state.pendingSpawnTracks) do
        if item.meta and item.meta.waveIndex == waveIndex then return true end
    end

    for _, meta in pairs(self.state.pendingRequests) do
        if meta.waveIndex == waveIndex then return true end
    end

    for _, meta in ipairs(self.state.pendingNoHashRequests) do
        if meta.waveIndex == waveIndex then return true end
    end

    return false
end

function MissionController:getTreasureFallbackPos(wave, firstQueuedPos)
    if wave and wave.spawnLine then
        return self.geometry.linePoint(wave.spawnLine.edgeA, wave.spawnLine.edgeB, 3, 2)
    end

    return firstQueuedPos
end

function MissionController:getWaveMinTrackedForCompletion(wave)
    if not wave then return 1 end
    local configured = tonumber(wave.minTrackedForCompletion)
    if configured then
        return math.max(1, math.floor(configured))
    end

    local ratio = self.settings.WAVE_COMPLETION_MIN_TRACKED_RATIO or 0.5
    local floorCount = self.settings.WAVE_COMPLETION_MIN_TRACKED_COUNT or 3
    local required = math.ceil((wave.count or 1) * ratio)

    return math.max(1, math.min(wave.count or required, math.max(floorCount, required)))
end

function MissionController:getWaveUnknownRestartLimit(wave)
    if wave then
        local configured = tonumber(wave.unknownRestartLimit)

        if configured then
            return math.max(0, math.floor(configured))
        end
    end

    local configured = tonumber(self.settings.WAVE_UNKNOWN_RESTART_LIMIT)
    if configured then
        return math.max(0, math.floor(configured))
    end

    return 0
end

function MissionController:getWaveSpawnRequestMaxDistance(wave)
    if wave then
        local configured = tonumber(wave.spawnRequestMaxDistance or wave.spawnActivationDistance)

        if configured then
            return configured
        end
    end

    return tonumber(self.settings.SPAWN_REQUEST_MAX_DISTANCE)
end

function MissionController:isQueuedSpawnCloseEnough(item)
    if not item or not item.wave then return true end

    local maxDistance = self:getWaveSpawnRequestMaxDistance(item.wave)
    if not maxDistance or maxDistance <= 0 then return true end

    local player = Game.GetPlayer()
    if not player then return false end

    local pos = item.pos or self.planner:getSafeSpawnPoint(item.wave, item.spawnIndex)
    if not pos then return true end

    local distance = self.geometry.distance(player:GetWorldPosition(), pos)
    if distance <= maxDistance then
        return true
    end

    local logInterval = self.settings.SPAWN_DISTANCE_WAIT_LOG_INTERVAL or 5.0
    local now = self.state.elapsed or 0

    if not item.lastSpawnDistanceWaitLogAt or now - item.lastSpawnDistanceWaitLogAt >= logInterval then
        item.lastSpawnDistanceWaitLogAt = now

        self.log(
            "Spawn request waiting for player proximity | wave=" ..
            tostring(item.wave.name) ..
            " | index=" ..
            tostring(item.spawnIndex) ..
            " | dist=" ..
            tostring(math.floor(distance)) ..
            " | maxDist=" ..
            tostring(maxDistance)
        )
    end

    return false
end

function MissionController:shouldDespawnDefeatedNPC(wave)
    return wave and wave.despawnDefeatedNPCs == true
end

function MissionController:markNPCDefeated(npc, meta, waveIndex, defeatedObjects)
    defeatedObjects[npc] = true

    local wave = self.waves[waveIndex]
    if not self:shouldDespawnDefeatedNPC(wave) then return end

    if not self.state.waveDespawnedDefeatedObjects then self.state.waveDespawnedDefeatedObjects = {} end
    if not self.state.waveDespawnedDefeatedObjects[waveIndex] then self.state.waveDespawnedDefeatedObjects[waveIndex] = {} end

    local despawnedObjects = self.state.waveDespawnedDefeatedObjects[waveIndex]
    if despawnedObjects[npc] then return end

    despawnedObjects[npc] = true

    self.log(
        "Defeated NPC despawned to hide body | wave=" ..
        tostring(waveIndex) ..
        " | index=" ..
        tostring(meta and meta.spawnIndex or "unknown") ..
        " | waveName=" ..
        tostring(wave and wave.name or "unknown")
    )

    self.spawner:despawnNPC(npc)
end

function MissionController:tryMarkNPCDefeated(npc, reason)
    if not npc then return false end

    local meta = self.state.spawnedObjectMetas[npc]
    local waveIndex = meta and meta.waveIndex or nil
    if not waveIndex then return false end

    if not self.spawner:isDefined(npc) then return false end
    if not self.ai:isNPCConfirmedDefeated(npc) then return false end

    if not self.state.waveDefeatedObjects then self.state.waveDefeatedObjects = {} end
    if not self.state.waveDefeatedObjects[waveIndex] then self.state.waveDefeatedObjects[waveIndex] = {} end

    local defeatedObjects = self.state.waveDefeatedObjects[waveIndex]
    if defeatedObjects[npc] then return true end

    if self.playerRules and not self.playerRules:validateDefeat(npc, meta, reason or "defeat-detected") then
        return false
    end

    self.log(
        "Defeated NPC detected immediately | wave=" ..
        tostring(waveIndex) ..
        " | index=" ..
        tostring(meta.spawnIndex or "unknown") ..
        " | reason=" ..
        tostring(reason or "unknown")
    )

    self:markNPCDefeated(npc, meta, waveIndex, defeatedObjects)
    return true
end

function MissionController:schedulePostHitDefeatChecks(npc, reason)
    if not npc then return false end

    local meta = self.state.spawnedObjectMetas[npc]
    local wave = meta and self.waves[meta.waveIndex] or nil

    if not meta or not self:shouldDespawnDefeatedNPC(wave) then return false end

    local now = self.state.elapsed or 0
    if meta.lastPostHitDefeatCheckQueuedAt and now - meta.lastPostHitDefeatCheckQueuedAt < 0.2 then
        return false
    end

    meta.lastPostHitDefeatCheckQueuedAt = now

    if not self.state.pendingDefeatChecks then self.state.pendingDefeatChecks = {} end

    local delays = { 0.05, 0.2, 0.6 }
    for _, delay in ipairs(delays) do
        table.insert(self.state.pendingDefeatChecks, {
            npc = npc,
            fireAt = now + delay,
            reason = reason or "post-hit"
        })
    end

    return true
end

function MissionController:updatePendingDefeatChecks()
    if not self.state.pendingDefeatChecks then return end

    for i = #self.state.pendingDefeatChecks, 1, -1 do
        local item = self.state.pendingDefeatChecks[i]

        if self.state.elapsed >= item.fireAt then
            self:tryMarkNPCDefeated(item.npc, item.reason or "post-hit")
            table.remove(self.state.pendingDefeatChecks, i)
        end
    end
end

function MissionController:countWaveNPCs(waveIndex)
    local total = 0
    local active = 0
    local valid = 0
    local defeated = 0
    local unknown = 0

    if not self.state.waveDefeatedObjects then self.state.waveDefeatedObjects = {} end
    if not self.state.waveDefeatedObjects[waveIndex] then self.state.waveDefeatedObjects[waveIndex] = {} end
    local defeatedObjects = self.state.waveDefeatedObjects[waveIndex]

    for _, npc in ipairs(self.state.spawnedObjects) do
        local meta = self.state.spawnedObjectMetas[npc]

        if meta and meta.waveIndex == waveIndex then
            total = total + 1

            if defeatedObjects[npc] then
                defeated = defeated + 1
            elseif self.spawner:isDefined(npc) then
                valid = valid + 1

                if self.ai:isNPCConfirmedDefeated(npc) then
                    if self.playerRules and not self.playerRules:validateDefeat(npc, meta, "defeat-without-katana-hit") then
                        active = active + 1
                    else
                        self:markNPCDefeated(npc, meta, waveIndex, defeatedObjects)
                        defeated = defeated + 1
                    end
                else
                    active = active + 1
                end
            else
                if self.playerRules then
                    self.playerRules:validateDefeat(npc, meta, "unknown-without-katana-hit", {
                        suppressViolation = true
                    })
                end
                unknown = unknown + 1
            end
        end
    end

    return total, active, valid, defeated, unknown
end

function MissionController:handlePlayerWeaponRuleViolation()
    if not self.state.playerWeaponRuleViolation then return false end

    local violation = self.state.playerWeaponRuleViolation

    if violation.waveIndex == self.state.currentWaveIndex and violation.action == "restartWave" then
        self:restartWave(violation.waveIndex, "player-weapon-rule")
        return true
    end

    self.state.playerWeaponRuleViolation = nil
    return false
end

function MissionController:isInvitationEnabled()
    return self.settings.INVITATION_ENABLED ~= false
end

function MissionController:isAutoStartEnabled()
    return self.settings.AUTO_START_ENABLED == true
end

function MissionController:getInvitationAcceptedFact()
    return self.settings.INVITATION_ACCEPTED_FACT or "samurai_waves_invitation_accepted"
end

function MissionController:updateAutoStart(delta)
    if self.autoStartHandled then return end

    if not self:isAutoStartEnabled() then
        self.autoStartHandled = true
        return
    end

    if self.state.missionActive then
        self.autoStartHandled = true
        return
    end

    if not Game.GetPlayer() then return end

    self.autoStartTimer = self.autoStartTimer + delta

    local delay = tonumber(self.settings.AUTO_START_DELAY) or 0
    if self.autoStartTimer < delay then return end

    self.autoStartHandled = true
    self:startMission("auto-start")
end

function MissionController:getQuestFact(factName)
    if not factName or factName == "" then return nil end

    local ok, value = pcall(function()
        local questsSystem = Game.GetQuestsSystem()
        if not questsSystem then return nil end
        return questsSystem:GetFactStr(factName)
    end)

    if ok then return value end
    return nil
end

function MissionController:setQuestFact(factName, value)
    if not factName or factName == "" then return false end

    local ok = pcall(function()
        local questsSystem = Game.GetQuestsSystem()
        if not questsSystem then return end
        questsSystem:SetFactStr(factName, value)
    end)

    return ok == true
end

function MissionController:updateInvitation(delta)
    if not self:isInvitationEnabled() then return end
    if self.state.missionActive then return end

    self.state.invitationFactPollTimer = (self.state.invitationFactPollTimer or 0) + delta

    local interval = self.settings.INVITATION_FACT_POLL_INTERVAL or 1.0
    if interval <= 0 then return end
    if self.state.invitationFactPollTimer < interval then return end

    self.state.invitationFactPollTimer = 0

    local factName = self:getInvitationAcceptedFact()
    local value = tonumber(self:getQuestFact(factName)) or 0

    if value <= 0 then return end

    self.log(
        "Invitation fact accepted; starting mission | fact=" ..
        tostring(factName) ..
        " | value=" ..
        tostring(value)
    )

    if self.settings.INVITATION_RESET_FACT_ON_START ~= false then
        self:setQuestFact(factName, 0)
    end

    self:startMission("invitation-fact")
end

function MissionController:handleUnknownWaveCollapse(waveIndex, total, defeated, unknown, minTrackedForCompletion)
    if defeated > 0 then return false end
    if total <= 0 then return false end
    if unknown ~= total then return false end

    local wave = self.waves[waveIndex]
    local restartLimit = self:getWaveUnknownRestartLimit(wave)
    if restartLimit <= 0 then return false end

    if not self.state.waveUnknownRestartCounts then self.state.waveUnknownRestartCounts = {} end

    local restartCount = self.state.waveUnknownRestartCounts[waveIndex] or 0

    if restartCount >= restartLimit then
        if self.state.lastCompletionBlockedLogTime == nil or self.state.elapsed - self.state.lastCompletionBlockedLogTime >= 5.0 then
            self.state.lastCompletionBlockedLogTime = self.state.elapsed

            self.log(
                "Wave collapse restart limit reached; completion blocked | wave=" ..
                tostring(waveIndex) ..
                " | tracked=" ..
                tostring(total) ..
                " | unknown=" ..
                tostring(unknown) ..
                " | required=" ..
                tostring(minTrackedForCompletion) ..
                " | restartLimit=" ..
                tostring(restartLimit)
            )
        end

        return true
    end

    restartCount = restartCount + 1
    self.state.waveUnknownRestartCounts[waveIndex] = restartCount

    self.log(
        "Wave collapsed into unknown NPCs before any confirmed defeat; restarting initialization | wave=" ..
        tostring(waveIndex) ..
        " | tracked=" ..
        tostring(total) ..
        " | unknown=" ..
        tostring(unknown) ..
        " | required=" ..
        tostring(minTrackedForCompletion) ..
        " | restart=" ..
        tostring(restartCount) ..
        "/" ..
        tostring(restartLimit)
    )

    if self.playerRules then self.playerRules:stopWave("unknown-collapse") end
    if self.treasure then self.treasure:clear() end
    self.spawner:despawnAll()
    self:queueWave(waveIndex, {
        keepNavigationMarker = self.state.activeMappin ~= nil and self.state.currentMarkerWaveIndex == waveIndex
    })

    return true
end

function MissionController:restartWave(waveIndex, reason)
    if not waveIndex or waveIndex <= 0 then return false end

    self.log(
        "Restarting wave | wave=" ..
        tostring(waveIndex) ..
        " | reason=" ..
        tostring(reason or "unknown")
    )

    if self.playerRules then
        self.playerRules:stopWave("restart")
    end

    if self.treasure then self.treasure:clear() end
    self.spawner:despawnAll()

    self.state.currentWaveIndex = 0
    self.state.waveCompletionHandled = false
    self.state.playerWeaponRuleViolation = nil
    self.state.lastCompletionWaitLogTime = nil
    self.state.lastCompletionBlockedLogTime = nil

    self:queueWave(waveIndex, {
        keepNavigationMarker = self.state.activeMappin ~= nil and self.state.currentMarkerWaveIndex == waveIndex
    })

    return true
end

function MissionController:scheduleSpawnTracking(objects, meta)
    if not objects or #objects <= 0 or not meta then return end

    table.insert(self.state.pendingSpawnTracks, {
        objects = objects,
        meta = meta,
        fireAt = self.state.elapsed + (self.settings.SPAWN_TRACK_DELAY or 0.15)
    })

    self.log(
        "Spawn tracking scheduled | wave=" ..
        tostring(meta.waveName) ..
        " | index=" ..
        tostring(meta.spawnIndex) ..
        " | objects=" ..
        tostring(#objects)
    )
end

function MissionController:processSpawnTracking(objects, meta)
    local trackedThisResult = {}
    if not self.state.waveAliveSeen then self.state.waveAliveSeen = {} end

    for _, spawnedObject in ipairs(objects) do
        if self.spawner:trackSpawnedObject(spawnedObject, meta) then
            table.insert(trackedThisResult, spawnedObject)

            if self.playerRules then
                self.playerRules:onNPCTracked(spawnedObject, meta)
            end

            if meta and meta.waveIndex and not self.ai:isNPCConfirmedDefeated(spawnedObject) then
                self.state.waveAliveSeen[meta.waveIndex] = true
            end
        end
    end

    self.ai:setAllSpawnedFriendly()

    for _, spawnedObject in ipairs(trackedThisResult) do
        local wave, meta = self.ai:getNPCWave(spawnedObject)

        if self.ai:shouldSuppressHoldAwareness(spawnedObject, wave, meta) then
            self.ai:primeQuietReady(spawnedObject, wave, meta)
        else
            self.ai:prime(spawnedObject)
        end
    end

    self.ai:setAllSpawnedFriendly()
end

function MissionController:updatePendingSpawnTracks()
    for i = #self.state.pendingSpawnTracks, 1, -1 do
        local item = self.state.pendingSpawnTracks[i]

        if self.state.elapsed >= item.fireAt then
            self:processSpawnTracking(item.objects, item.meta)
            table.remove(self.state.pendingSpawnTracks, i)
        end
    end
end

function MissionController:queueWave(waveIndex, options)
    local wave = self.waves[waveIndex]

    if not wave then
        self.log("No wave at index: " .. tostring(waveIndex))
        return
    end

    local keepNavigationMarker =
        options and
        options.keepNavigationMarker == true and
        self.state.activeMappin ~= nil and
        self.state.currentMarkerWaveIndex == waveIndex

    self.state.missionActive = true
    if not keepNavigationMarker then
        self.markers:clear()
    else
        self.state.markerTriggerActive = false

        self.log(
            "Keeping wave navigation marker during active wave | wave=" ..
            tostring(waveIndex)
        )
    end

    self:clearPendingWaveMarker()

    self.log("Queueing " .. wave.name .. " | count=" .. tostring(wave.count))

    self.state.currentWaveIndex = waveIndex
    self.state.highestWaveStarted = waveIndex
    self.state.waveCompletionHandled = false
    self.state.lastWaveStartTime = self.state.elapsed
    self.state.lastCompletionWaitLogTime = nil
    self.state.lastCompletionBlockedLogTime = nil
    if not self.state.waveAliveSeen then self.state.waveAliveSeen = {} end
    self.state.waveAliveSeen[waveIndex] = false
    if not self.state.waveDefeatedObjects then self.state.waveDefeatedObjects = {} end
    self.state.waveDefeatedObjects[waveIndex] = {}
    if not self.state.waveDespawnedDefeatedObjects then self.state.waveDespawnedDefeatedObjects = {} end
    self.state.waveDespawnedDefeatedObjects[waveIndex] = {}
    self.state.countdownLogTimer = 0
    self.state.waveCompletionTimer = 0

    self.hud:showWaveStart(waveIndex, wave)
    self.log(wave.name .. " started.")

    if self.playerRules then
        self.playerRules:startWave(waveIndex, wave)
    end

    local firstQueuedPos = nil

    for i = 1, wave.count do
        local pos = self.planner:getSafeSpawnPoint(wave, i)
        local npc = self.planner:getWaveNPC(wave, i)

        if not firstQueuedPos then
            firstQueuedPos = pos
        end

        table.insert(self.state.spawnQueue, {
            pos = pos,
            npc = npc,
            wave = wave,
            waveIndex = waveIndex,
            spawnIndex = i,
            retryCount = 0,
            fallbackRetryCount = 0
        })

        self.log(
            wave.name ..
            " queued #" ..
            tostring(i) ..
            " x=" ..
            tostring(pos.x) ..
            " y=" ..
            tostring(pos.y) ..
            " z=" ..
            tostring(pos.z)
        )
    end

    if not keepNavigationMarker then
        self.markers:setCombatMarker(firstQueuedPos, waveIndex)
    end

    if self.treasure then
        self.treasure:activateForWave(waveIndex, wave, self:getTreasureFallbackPos(wave, firstQueuedPos))
    end
end

function MissionController:forceWave(waveIndex)
    self.log("Manual force wave requested | wave=" .. tostring(waveIndex))

    self.markers:clear()
    if self.playerRules then self.playerRules:stopWave("force-wave") end
    if self.treasure then self.treasure:clear() end
    self.spawner:despawnAll()

    self.state.currentWaveIndex = 0
    self.state.currentMarkerWaveIndex = nil
    self.state.pendingMarkerWaveIndex = nil
    self.state.waveCompletionHandled = false
    if not self.state.waveUnknownRestartCounts then self.state.waveUnknownRestartCounts = {} end
    self.state.waveUnknownRestartCounts[waveIndex] = 0
    self.state.lastCompletionWaitLogTime = nil
    self.state.lastCompletionBlockedLogTime = nil

    self:queueWave(waveIndex)
end

function MissionController:clearPendingWaveMarker()
    self.state.pendingMarkerWaveIndex = nil
    self.state.markerRegisterRetryTimer = 0
end

function MissionController:setWaveNavigationMarker(waveIndex, reason)
    self.state.pendingMarkerWaveIndex = waveIndex
    self.state.markerRegisterRetryTimer = self.settings.MARKER_REGISTER_RETRY_INTERVAL or 1.0

    local ok = self.markers:setWaveMarker(waveIndex)

    if ok then
        self:clearPendingWaveMarker()
        return true
    end

    self.log(
        "Wave marker pending retry | wave=" ..
        tostring(waveIndex) ..
        " | reason=" ..
        tostring(reason or "unknown")
    )

    return false
end

function MissionController:updatePendingWaveMarker(delta)
    if not self.state.missionActive then return end
    if self.state.currentWaveIndex > 0 then return end
    if self.state.markerActive and self.state.markerRouteReady then return end

    if not self.state.pendingMarkerWaveIndex and self.state.highestWaveStarted < #self.waves then
        self.state.pendingMarkerWaveIndex = self.state.highestWaveStarted + 1
        self.state.markerRegisterRetryTimer = 0
        self.log("Recovering missing wave marker | wave=" .. tostring(self.state.pendingMarkerWaveIndex))
    end

    if not self.state.pendingMarkerWaveIndex then return end

    self.state.markerRegisterRetryTimer = (self.state.markerRegisterRetryTimer or 0) - delta

    if self.state.markerRegisterRetryTimer > 0 then return end

    self.state.markerRegisterRetryTimer = self.settings.MARKER_REGISTER_RETRY_INTERVAL or 1.0

    self.log("Retrying wave marker | wave=" .. tostring(self.state.pendingMarkerWaveIndex))
    self:setWaveNavigationMarker(self.state.pendingMarkerWaveIndex, "retry")
end

function MissionController:updateWaveCompletion()
    if not self.state.missionActive then return end
    if self.state.currentWaveIndex <= 0 then return end
    if self.state.waveCompletionHandled then return end

    if self.state.waveCompletionTimer > 0 then return end
    self.state.waveCompletionTimer = self.settings.WAVE_COMPLETION_CHECK_INTERVAL

    if self:hasPendingWaveWork(self.state.currentWaveIndex) then return end
    if self.state.lastWaveStartTime ~= nil and self.state.elapsed - self.state.lastWaveStartTime < 3.0 then return end

    local wave = self.waves[self.state.currentWaveIndex]
    local minTrackedForCompletion = self:getWaveMinTrackedForCompletion(wave)
    local total, active, valid, defeated, unknown = self:countWaveNPCs(self.state.currentWaveIndex)
    local effectiveDefeated = defeated + unknown

    if self:handlePlayerWeaponRuleViolation() then
        return
    end

    if self:handleUnknownWaveCollapse(self.state.currentWaveIndex, total, defeated, unknown, minTrackedForCompletion) then
        return
    end

    if total < minTrackedForCompletion or self.state.waveAliveSeen[self.state.currentWaveIndex] ~= true then
        if self.state.lastCompletionBlockedLogTime == nil or self.state.elapsed - self.state.lastCompletionBlockedLogTime >= 5.0 then
            self.state.lastCompletionBlockedLogTime = self.state.elapsed

            self.log(
                "Wave completion blocked: wave was not fully established | wave=" ..
                tostring(self.state.currentWaveIndex) ..
                " | tracked=" ..
                tostring(total) ..
                " | valid=" ..
                tostring(valid) ..
                " | defeated=" ..
                tostring(defeated) ..
                " | unknown=" ..
                tostring(unknown) ..
                " | aliveSeen=" ..
                tostring(self.state.waveAliveSeen[self.state.currentWaveIndex] == true) ..
                " | required=" ..
                tostring(minTrackedForCompletion)
            )
        end

        return
    end

    if active > 0 then
        if self.state.lastCompletionWaitLogTime == nil or self.state.elapsed - self.state.lastCompletionWaitLogTime >= 5.0 then
            self.state.lastCompletionWaitLogTime = self.state.elapsed

            self.log(
                "Wave completion waiting | wave=" ..
                tostring(self.state.currentWaveIndex) ..
                " | active=" ..
                tostring(active) ..
                " | tracked=" ..
                tostring(total) ..
                " | valid=" ..
                tostring(valid) ..
                " | defeated=" ..
                tostring(defeated) ..
                " | unknown=" ..
                tostring(unknown) ..
                " | effectiveDefeated=" ..
                tostring(effectiveDefeated)
            )
        end

        return
    end

    if unknown > 0 then
        self.log(
            "Wave completion treating unknown NPCs as defeated | wave=" ..
            tostring(self.state.currentWaveIndex) ..
            " | defeated=" ..
            tostring(defeated) ..
            " | unknown=" ..
            tostring(unknown) ..
            " | effectiveDefeated=" ..
            tostring(effectiveDefeated)
        )
    end

    if effectiveDefeated < minTrackedForCompletion then
        if self.state.lastCompletionBlockedLogTime == nil or self.state.elapsed - self.state.lastCompletionBlockedLogTime >= 5.0 then
            self.state.lastCompletionBlockedLogTime = self.state.elapsed

            self.log(
                "Wave completion blocked: not enough confirmed defeats | wave=" ..
                tostring(self.state.currentWaveIndex) ..
                " | defeated=" ..
                tostring(defeated) ..
                " | unknown=" ..
                tostring(unknown) ..
                " | effectiveDefeated=" ..
                tostring(effectiveDefeated) ..
                " | required=" ..
                tostring(minTrackedForCompletion)
            )
        end

        return
    end

    self.state.waveCompletionHandled = true
    self.state.lastCompletionWaitLogTime = nil
    local completedWaveIndex = self.state.currentWaveIndex

    self.log(
        "Wave completed | wave=" ..
        tostring(completedWaveIndex) ..
        " | trackedInWave=" ..
        tostring(total) ..
        " | defeated=" ..
        tostring(defeated) ..
        " | unknownAsDefeated=" ..
        tostring(unknown)
    )

    if self.treasure then
        self.treasure:claimWave(completedWaveIndex)
    end

    if self.playerRules then
        self.playerRules:stopWave("completed")
    end

    if completedWaveIndex < #self.waves then
        local nextWave = completedWaveIndex + 1
        self.state.currentWaveIndex = 0
        self:setWaveNavigationMarker(nextWave, "wave-completed")
        self.hud:show("Wave cleared. Go to the next location.")
    else
        self.state.currentWaveIndex = 0
        self.state.missionActive = false
        self.markers:clear()
        self.hud:show("Samurai Waves completed.")
        self.log("Mission completed")
    end
end

function MissionController:startMission(source)
    self.log(
        "Starting mission | version=" ..
        tostring(self.modVersion) ..
        " | source=" ..
        tostring(source or "manual")
    )

    self.spawner:despawnAll()
    if self.playerRules then self.playerRules:stopWave("mission-start") end
    self.markers:clear()
    if self.treasure then self.treasure:clear() end

    self.state:resetMission()
    self.state:resetTimers()
    self.state.missionActive = true
    self.state.markerActive = false
    self.state.lastHUDText = ""
    self.state.invitationFactPollTimer = 0

    self:setWaveNavigationMarker(1, "mission-start")

    self.log("Mission started. Go to marker.")
end

function MissionController:stopMission()
    self.log("Stopping mission")

    self.state.missionActive = false
    self.state.markerActive = false
    self.state.currentWaveIndex = 0
    self.state.highestWaveStarted = 0
    self.state.currentMarkerWaveIndex = nil
    self.state.pendingMarkerWaveIndex = nil
    self.state.waveCompletionHandled = false
    self.state.lastWaveStartTime = nil
    self.state.lastCompletionWaitLogTime = nil
    self.state.lastCompletionBlockedLogTime = nil

    self.markers:clear()
    if self.playerRules then self.playerRules:stopWave("mission-stop") end
    if self.treasure then self.treasure:clear() end
    self.spawner:despawnAll()

    self.hud:show(" ")
    self.state.lastHUDText = ""
end

function MissionController:checkMission()
    if not self.state.missionActive then return end

    local player = Game.GetPlayer()
    if not player then return end

    if self.state.markerActive and self.state.markerTriggerActive and self.state.currentMarkerWaveIndex ~= nil then
        local playerPos = player:GetWorldPosition()
        local markerWave = self.waves[self.state.currentMarkerWaveIndex]
        local triggerDistance = (markerWave and markerWave.triggerDistance) or self.settings.START_TRIGGER_DISTANCE
        local targetPos = self.planner:getWaveMarkerPos(self.state.currentMarkerWaveIndex)
        local dist = self.geometry.distance(playerPos, targetPos)

        if dist <= triggerDistance then
            local waveToStart = self.state.currentMarkerWaveIndex

            self.log(
                "Player reached wave marker | wave=" ..
                tostring(waveToStart) ..
                " | distance=" ..
                tostring(dist) ..
                " | triggerDistance=" ..
                tostring(triggerDistance)
            )

            self:clearPendingWaveMarker()
            self.state.markerTriggerActive = false
            self:queueWave(waveToStart, { keepNavigationMarker = true })
        end
    end
end

function MissionController:debugState()
    self.log("=== DEBUG STATE ===")
    self.log("modName=" .. tostring(self.modName))
    self.log("modVersion=" .. tostring(self.modVersion))
    self.log("missionActive=" .. tostring(self.state.missionActive))
    self.log("markerActive=" .. tostring(self.state.markerActive))
    self.log("markerRouteReady=" .. tostring(self.state.markerRouteReady))
    self.log("markerTriggerActive=" .. tostring(self.state.markerTriggerActive))
    self.log("currentWaveIndex=" .. tostring(self.state.currentWaveIndex))
    self.log("highestWaveStarted=" .. tostring(self.state.highestWaveStarted))
    self.log("currentMarkerWaveIndex=" .. tostring(self.state.currentMarkerWaveIndex))
    self.log("pendingMarkerWaveIndex=" .. tostring(self.state.pendingMarkerWaveIndex))
    self.log("activeRouteCarrierMappin=" .. tostring(self.state.activeRouteCarrierMappin))
    self.log("markerRegisterRetryTimer=" .. tostring(self.state.markerRegisterRetryTimer))
    self.log("waveCompletionHandled=" .. tostring(self.state.waveCompletionHandled))
    self.log("totalWaves=" .. tostring(#self.waves))
    self.log("spawnQueue=" .. tostring(#self.state.spawnQueue))
    self.log("pendingSpawnTracks=" .. tostring(#self.state.pendingSpawnTracks))
    self.log("pendingRequestsEmpty=" .. tostring(tableIsEmpty(self.state.pendingRequests)))
    self.log("hashPending=" .. tostring(self.spawner:countPendingRequests()))
    self.log("noHashPending=" .. tostring(#self.state.pendingNoHashRequests))
    self.log("delayedCombatActions=" .. tostring(#self.state.delayedCombatActions))
    self.log("pendingDefeatChecks=" .. tostring(self.state.pendingDefeatChecks and #self.state.pendingDefeatChecks or 0))
    self.log("pendingTeleportCorrections=" .. tostring(#self.state.pendingTeleportCorrections))
    self.log("activeTreasure=" .. tostring(self.state.activeTreasure ~= nil))
    self.log("trackedNPCs=" .. tostring(self.spawner:countTrackedNPCs()))
    self.log("validNPCs=" .. tostring(self.spawner:countValidNPCs()))
    self.log("elapsed=" .. tostring(self.state.elapsed))
    self.log("lastWaveStartTime=" .. tostring(self.state.lastWaveStartTime))
    self.log("lastCompletionWaitLogTime=" .. tostring(self.state.lastCompletionWaitLogTime))
    self.log("lastCompletionBlockedLogTime=" .. tostring(self.state.lastCompletionBlockedLogTime))
    self.log("currentWaveAliveSeen=" .. tostring(self.state.waveAliveSeen[self.state.currentWaveIndex] == true))
    self.log("currentWaveUnknownRestarts=" .. tostring(self.state.waveUnknownRestartCounts and self.state.waveUnknownRestartCounts[self.state.currentWaveIndex] or 0))
    self.log("waveCompletionTimer=" .. tostring(self.state.waveCompletionTimer))
    self.log("chasePlayerTimer=" .. tostring(self.state.chasePlayerTimer))
    self.log("lastHUDText=" .. tostring(self.state.lastHUDText))
    self.log("playerWeaponRuleActive=" .. tostring(self.playerRules and self.playerRules:isRuleActive() or false))
    self.log("playerWeaponRuleViolation=" .. tostring(self.state.playerWeaponRuleViolation ~= nil))
    self.log("invitationAcceptedFact=" .. tostring(self:getInvitationAcceptedFact()))
    self.log("invitationAcceptedFactValue=" .. tostring(self:getQuestFact(self:getInvitationAcceptedFact())))
    self.log("invitationFactPollTimer=" .. tostring(self.state.invitationFactPollTimer))

    if self.state.currentWaveIndex > 0 then
        local total, active, valid, defeated, unknown = self:countWaveNPCs(self.state.currentWaveIndex)
        self.log("currentWaveTracked=" .. tostring(total))
        self.log("currentWaveActive=" .. tostring(active))
        self.log("currentWaveValid=" .. tostring(valid))
        self.log("currentWaveDefeated=" .. tostring(defeated))
        self.log("currentWaveUnknown=" .. tostring(unknown))
    end

    local player = Game.GetPlayer()
    if player then
        self.log("playerInCombat=" .. tostring(player:IsInCombat()))
    end

    for i, npc in ipairs(self.state.spawnedObjects) do
        if npc then
            local hash = self.spawner:getEntityHash(npc)
            local meta = self.state.spawnedObjectMetas[npc]

            pcall(function()
                local pos = npc:GetWorldPosition()
                self.log(
                    "npc #" ..
                    tostring(i) ..
                    " hash=" ..
                    tostring(hash) ..
                    " wave=" ..
                    tostring(meta and meta.waveIndex or "unknown") ..
                    " defeated=" ..
                    tostring(self.ai:isNPCDefeated(npc)) ..
                    " dist=" ..
                    tostring(math.floor(self.ai:getDistanceFromPlayer(npc))) ..
                    " pos=" ..
                    tostring(pos.x) ..
                    "," ..
                    tostring(pos.y) ..
                    "," ..
                    tostring(pos.z)
                )
            end)
        else
            self.log("npc #" .. tostring(i) .. " nil")
        end
    end
end

function MissionController:registerHotkeys()
    registerHotkey("WavesStartMission", "Samurai Waves - start mission", function()
        self:startMission()
    end)

    registerHotkey("WavesStopMission", "Samurai Waves - stop mission", function()
        self:stopMission()
    end)

    registerHotkey("WavesTestMarkerOnPlayer", "Samurai Waves - test marker on player", function()
        self.markers:testMarkerOnPlayer()
    end)

    registerHotkey("WavesDebugState", "Samurai Waves - debug state", function()
        self:debugState()
    end)

    local registeredForceWaveHotkeys = {}

    local function getForceWaveHotkeyIndex(wave, fallbackIndex)
        local waveName = wave and wave.name or nil

        if type(waveName) == "string" then
            local displayIndex = string.match(waveName, "^%s*Wave%s+(%d+)")

            if displayIndex then
                return tonumber(displayIndex)
            end
        end

        return fallbackIndex
    end

    local function getForceWaveHotkeyDescription(hotkeyIndex, wave, fallbackIndex)
        local description = "Samurai Waves - force Wave " .. tostring(hotkeyIndex)
        local waveName = wave and wave.name or nil

        if type(waveName) == "string" then
            local suffix = string.match(waveName, "^%s*Wave%s+%d+%s*%-%s*(.+)$")

            if suffix and suffix ~= "" then
                description = description .. " - " .. suffix
            end
        end

        if hotkeyIndex ~= fallbackIndex then
            description = description .. " (slot " .. tostring(fallbackIndex) .. ")"
        end

        return description
    end

    local function registerForceWaveHotkey(hotkeyIndex, waveIndex, description)
        if not hotkeyIndex or registeredForceWaveHotkeys[hotkeyIndex] then
            return false
        end

        registeredForceWaveHotkeys[hotkeyIndex] = true

        registerHotkey("WavesForceWave" .. tostring(hotkeyIndex), description, function()
            self:forceWave(waveIndex)
        end)

        self.log(
            "Force wave hotkey registered | id=WavesForceWave" ..
            tostring(hotkeyIndex) ..
            " | waveIndex=" ..
            tostring(waveIndex)
        )

        return true
    end

    for waveIndex = 1, #self.waves do
        local wave = self.waves[waveIndex]
        local hotkeyIndex = getForceWaveHotkeyIndex(wave, waveIndex)

        registerForceWaveHotkey(
            hotkeyIndex,
            waveIndex,
            getForceWaveHotkeyDescription(hotkeyIndex, wave, waveIndex)
        )
    end

    for waveIndex = 1, #self.waves do
        local wave = self.waves[waveIndex]
        local displayIndex = getForceWaveHotkeyIndex(wave, waveIndex)

        if displayIndex ~= waveIndex then
            registerForceWaveHotkey(
                waveIndex,
                waveIndex,
                "Samurai Waves - force list item " .. tostring(waveIndex) .. " - " .. tostring(wave and wave.name or "unknown")
            )
        end
    end

    registerHotkey("WavesForceAggro", "Samurai Waves - force aggro all", function()
        self.log("Manual force aggro all")
        self.ai:forceAggroAll()
    end)

    registerHotkey("WavesChasePlayer", "Samurai Waves - chase player all", function()
        self.log("Manual chase player all")
        self.ai:forceAggroAll()
    end)

    registerHotkey("WavesDespawnAll", "Samurai Waves - despawn all NPCs", function()
        self.spawner:despawnAll()
    end)

    registerHotkey("WavesKillAll", "Samurai Waves - kill all spawned NPCs", function()
        local attempted, affected = self.ai:killAllSpawned()
        self.hud:show("Kill all spawned NPCs: " .. tostring(affected) .. "/" .. tostring(attempted))
    end)

    registerHotkey("WavesShowHUD", "Samurai Waves - show HUD countdown", function()
        self.log("Manual show HUD countdown")
        self.hud:updateCountdown(true)
    end)
end

function MissionController:onInit()
    self.log("Loaded | version=" .. tostring(self.modVersion))

    ObserveAfter("NPCPuppet", "OnHit", function(npc, evt)
        if self.playerRules then
            self.playerRules:onNPCPuppetHit(npc, evt)
        end

        if not self:tryMarkNPCDefeated(npc, "on-hit") then
            self:schedulePostHitDefeatChecks(npc, "post-hit")
        end
    end)

    ObserveAfter("PreventionSpawnSystem", "SpawnRequestFinished", function(_, result)
        self.log("SpawnRequestFinished observed AFTER")

        local objects = self.spawner:extractSpawnedObjects(result)
        local meta = self.spawner:acceptSpawnResult(result, objects)
        if not meta then return end

        self.log(
            "SpawnRequestFinished objects extracted: " ..
            tostring(#objects) ..
            " | wave=" ..
            tostring(meta.waveName) ..
            " | index=" ..
            tostring(meta.spawnIndex) ..
            " | npc=" ..
            tostring(meta.npcSpawnRecord or meta.npc or "unknown")
        )

        if #objects == 0 then
            self.log(
                "WARNING: accepted spawn result, but no spawned objects found | wave=" ..
                tostring(meta.waveName) ..
                " | index=" ..
                tostring(meta.spawnIndex) ..
                " | npc=" ..
                tostring(meta.npcSpawnRecord or meta.npc or "unknown")
            )

            if meta.skipEmptySpawnRetries then
                self.log(
                    "Empty spawn result retry skipped | wave=" ..
                    tostring(meta.waveName) ..
                    " | index=" ..
                    tostring(meta.spawnIndex) ..
                    " | npc=" ..
                    tostring(meta.npcSpawnRecord or meta.npc or "unknown")
                )

                return
            end

            if not self.spawner:requeueFallbackSpawn(meta, "accepted spawn result without objects") then
                self.spawner:requeueSameSpawn(meta, "accepted spawn result without objects")
            end

            return
        end

        self:scheduleSpawnTracking(objects, meta)
    end)
end

function MissionController:onUpdate(delta)
    self.state.elapsed = self.state.elapsed + delta
    self.state.spawnQueueTimer = self.state.spawnQueueTimer + delta
    self.state.globalAggroTimer = self.state.globalAggroTimer + delta
    self.state.chasePlayerTimer = self.state.chasePlayerTimer + delta
    self.state.countdownLogTimer = self.state.countdownLogTimer - delta
    self.state.hudCountdownTimer = self.state.hudCountdownTimer - delta
    self.state.spawnTimeoutTimer = self.state.spawnTimeoutTimer - delta
    self.state.waveCompletionTimer = self.state.waveCompletionTimer - delta

    self:updateAutoStart(delta)
    self:updateInvitation(delta)
    self:checkMission()
    self:updatePendingWaveMarker(delta)
    self.markers:update(delta)
    self.hud:updateCountdown(false)
    self.hud:updatePending()
    self:updatePendingSpawnTracks()
    self.spawner:updateTeleportCorrections()
    if self.playerRules then
        self.playerRules:update(delta)
    end
    self:updatePendingDefeatChecks()
    self.ai:updateHeldNPCs()
    self.ai:updateDelayedAwareness()
    self.spawner:checkSpawnTimeouts()

    if
        #self.state.spawnQueue > 0 and
        self.state.spawnQueueTimer >= self.settings.SPAWN_INTERVAL and
        not self.spawner:hasPendingSpawnRequests() and
        self:isQueuedSpawnCloseEnough(self.state.spawnQueue[1])
    then
        self.state.spawnQueueTimer = 0
        local item = table.remove(self.state.spawnQueue, 1)

        self.log(
            "Spawning queued NPC | wave=" ..
            tostring(item.wave.name) ..
            " | index=" ..
            tostring(item.spawnIndex) ..
            " | npc=" ..
            tostring(item.npc or "unknown") ..
            " | retry=" ..
            tostring(item.retryCount or 0) ..
            " | fallback=" ..
            tostring(item.forcedFallback or false) ..
            " | remaining=" ..
            tostring(#self.state.spawnQueue)
        )

        self.spawner:requestSpawnItem(item)
    end

    if self.state.currentWaveIndex > 0 and self.state.globalAggroTimer >= self.settings.GLOBAL_AGGRO_INTERVAL then
        self.state.globalAggroTimer = 0
        self.ai:updateEncounterNPCs(false)
    end

    if self.state.currentWaveIndex > 0 and self.state.chasePlayerTimer >= self.settings.CHASE_PLAYER_INTERVAL then
        self.state.chasePlayerTimer = 0
        self.ai:updateEncounterNPCs(true)
    end

    if self:handlePlayerWeaponRuleViolation() then return end

    self:updateWaveCompletion()
end

return MissionController
