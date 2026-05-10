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
        state = deps.state,
        settings = deps.settings,
        waves = deps.waves,
        geometry = deps.geometry,
        planner = deps.planner,
        markers = deps.markers,
        treasure = deps.treasure,
        hud = deps.hud,
        ai = deps.ai,
        spawner = deps.spawner,
        log = deps.log
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
                    defeatedObjects[npc] = true
                    defeated = defeated + 1
                else
                    active = active + 1
                end
            else
                unknown = unknown + 1
            end
        end
    end

    return total, active, valid, defeated, unknown
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

            if meta and meta.waveIndex and not self.ai:isNPCConfirmedDefeated(spawnedObject) then
                self.state.waveAliveSeen[meta.waveIndex] = true
            end
        end
    end

    self.ai:setAllSpawnedFriendly()

    for _, spawnedObject in ipairs(trackedThisResult) do
        self.ai:prime(spawnedObject)
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

function MissionController:queueWave(waveIndex)
    local wave = self.waves[waveIndex]

    if not wave then
        self.log("No wave at index: " .. tostring(waveIndex))
        return
    end

    self.state.missionActive = true
    self.markers:clear()

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
    self.state.countdownLogTimer = 0
    self.state.waveCompletionTimer = 0

    self.hud:showWaveStart(waveIndex, wave)
    self.log(wave.name .. " started.")

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

    self.markers:setCombatMarker(firstQueuedPos, waveIndex)

    if self.treasure then
        self.treasure:activateForWave(waveIndex, wave, self:getTreasureFallbackPos(wave, firstQueuedPos))
    end
end

function MissionController:forceWave(waveIndex)
    self.log("Manual force wave requested | wave=" .. tostring(waveIndex))

    self.markers:clear()
    if self.treasure then self.treasure:clear() end
    self.spawner:despawnAll()

    self.state.currentWaveIndex = 0
    self.state.currentMarkerWaveIndex = nil
    self.state.waveCompletionHandled = false
    self.state.lastCompletionWaitLogTime = nil
    self.state.lastCompletionBlockedLogTime = nil

    self:queueWave(waveIndex)
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

    if unknown > 0 then
        if self.state.lastCompletionBlockedLogTime == nil or self.state.elapsed - self.state.lastCompletionBlockedLogTime >= 5.0 then
            self.state.lastCompletionBlockedLogTime = self.state.elapsed

            self.log(
                "Wave completion blocked: tracked NPCs lost before confirmed defeat | wave=" ..
                tostring(self.state.currentWaveIndex) ..
                " | active=" ..
                tostring(active) ..
                " | valid=" ..
                tostring(valid) ..
                " | defeated=" ..
                tostring(defeated) ..
                " | unknown=" ..
                tostring(unknown)
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
                tostring(unknown)
            )
        end

        return
    end

    if defeated < minTrackedForCompletion then
        if self.state.lastCompletionBlockedLogTime == nil or self.state.elapsed - self.state.lastCompletionBlockedLogTime >= 5.0 then
            self.state.lastCompletionBlockedLogTime = self.state.elapsed

            self.log(
                "Wave completion blocked: not enough confirmed defeats | wave=" ..
                tostring(self.state.currentWaveIndex) ..
                " | defeated=" ..
                tostring(defeated) ..
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
        tostring(total)
    )

    if self.treasure then
        self.treasure:claimWave(completedWaveIndex)
    end

    if completedWaveIndex < #self.waves then
        local nextWave = completedWaveIndex + 1
        self.state.currentWaveIndex = 0
        self.markers:setWaveMarker(nextWave)
        self.hud:show("Wave cleared. Go to the next location.")
    else
        self.state.currentWaveIndex = 0
        self.state.missionActive = false
        self.markers:clear()
        self.hud:show("Run V, run! completed.")
        self.log("Mission completed")
    end
end

function MissionController:startMission()
    self.log("Starting mission")

    self.spawner:despawnAll()
    self.markers:clear()
    if self.treasure then self.treasure:clear() end

    self.state:resetMission()
    self.state:resetTimers()
    self.state.missionActive = true
    self.state.markerActive = false
    self.state.lastHUDText = ""

    self.markers:setWaveMarker(1)

    self.log("Mission started. Go to marker.")
end

function MissionController:stopMission()
    self.log("Stopping mission")

    self.state.missionActive = false
    self.state.markerActive = false
    self.state.currentWaveIndex = 0
    self.state.highestWaveStarted = 0
    self.state.currentMarkerWaveIndex = nil
    self.state.waveCompletionHandled = false
    self.state.lastWaveStartTime = nil
    self.state.lastCompletionWaitLogTime = nil
    self.state.lastCompletionBlockedLogTime = nil

    self.markers:clear()
    if self.treasure then self.treasure:clear() end
    self.spawner:despawnAll()

    self.hud:show(" ")
    self.state.lastHUDText = ""
end

function MissionController:checkMission()
    if not self.state.missionActive then return end

    local player = Game.GetPlayer()
    if not player then return end

    if self.state.markerActive and self.state.currentMarkerWaveIndex ~= nil then
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

            self.markers:clear()
            self:queueWave(waveToStart)
        end
    end
end

function MissionController:debugState()
    self.log("=== DEBUG STATE ===")
    self.log("missionActive=" .. tostring(self.state.missionActive))
    self.log("markerActive=" .. tostring(self.state.markerActive))
    self.log("currentWaveIndex=" .. tostring(self.state.currentWaveIndex))
    self.log("highestWaveStarted=" .. tostring(self.state.highestWaveStarted))
    self.log("currentMarkerWaveIndex=" .. tostring(self.state.currentMarkerWaveIndex))
    self.log("waveCompletionHandled=" .. tostring(self.state.waveCompletionHandled))
    self.log("totalWaves=" .. tostring(#self.waves))
    self.log("spawnQueue=" .. tostring(#self.state.spawnQueue))
    self.log("pendingSpawnTracks=" .. tostring(#self.state.pendingSpawnTracks))
    self.log("pendingRequestsEmpty=" .. tostring(tableIsEmpty(self.state.pendingRequests)))
    self.log("hashPending=" .. tostring(self.spawner:countPendingRequests()))
    self.log("noHashPending=" .. tostring(#self.state.pendingNoHashRequests))
    self.log("delayedCombatActions=" .. tostring(#self.state.delayedCombatActions))
    self.log("pendingTeleportCorrections=" .. tostring(#self.state.pendingTeleportCorrections))
    self.log("activeTreasure=" .. tostring(self.state.activeTreasure ~= nil))
    self.log("trackedNPCs=" .. tostring(self.spawner:countTrackedNPCs()))
    self.log("validNPCs=" .. tostring(self.spawner:countValidNPCs()))
    self.log("elapsed=" .. tostring(self.state.elapsed))
    self.log("lastWaveStartTime=" .. tostring(self.state.lastWaveStartTime))
    self.log("lastCompletionWaitLogTime=" .. tostring(self.state.lastCompletionWaitLogTime))
    self.log("lastCompletionBlockedLogTime=" .. tostring(self.state.lastCompletionBlockedLogTime))
    self.log("currentWaveAliveSeen=" .. tostring(self.state.waveAliveSeen[self.state.currentWaveIndex] == true))
    self.log("waveCompletionTimer=" .. tostring(self.state.waveCompletionTimer))
    self.log("chasePlayerTimer=" .. tostring(self.state.chasePlayerTimer))
    self.log("lastHUDText=" .. tostring(self.state.lastHUDText))

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
    registerHotkey("RunVRunStartMission", "Run V, run! - start mission", function()
        self:startMission()
    end)

    registerHotkey("RunVRunStopMission", "Run V, run! - stop mission", function()
        self:stopMission()
    end)

    registerHotkey("RunVRunTestMarkerOnPlayer", "Run V, run! - test marker on player", function()
        self.markers:testMarkerOnPlayer()
    end)

    registerHotkey("RunVRunDebugState", "Run V, run! - debug state", function()
        self:debugState()
    end)

    for waveIndex = 1, #self.waves do
        local index = waveIndex

        registerHotkey("RunVRunForceWave" .. tostring(index), "Run V, run! - force Wave " .. tostring(index), function()
            self:forceWave(index)
        end)
    end

    registerHotkey("RunVRunForceAggro", "Run V, run! - force aggro all", function()
        self.log("Manual force aggro all")
        self.ai:forceAggroAll()
    end)

    registerHotkey("RunVRunChasePlayer", "Run V, run! - chase player all", function()
        self.log("Manual chase player all")
        self.ai:forceAggroAll()
    end)

    registerHotkey("RunVRunDespawnAll", "Run V, run! - despawn all NPCs", function()
        self.spawner:despawnAll()
    end)

    registerHotkey("RunVRunKillAll", "Run V, run! - kill all spawned NPCs", function()
        local attempted, affected = self.ai:killAllSpawned()
        self.hud:show("Kill all spawned NPCs: " .. tostring(affected) .. "/" .. tostring(attempted))
    end)

    registerHotkey("RunVRunShowHUD", "Run V, run! - show HUD countdown", function()
        self.log("Manual show HUD countdown")
        self.hud:updateCountdown(true)
    end)
end

function MissionController:onInit()
    self.log("Loaded")

    ObserveAfter("PreventionSpawnSystem", "SpawnRequestFinished", function(_, result)
        self.log("SpawnRequestFinished observed AFTER")

        local objects = self.spawner:extractSpawnedObjects(result)
        local meta = self.spawner:acceptSpawnResult(result, objects)
        if not meta then return end

        self.log(
            "SpawnRequestFinished objects extracted: " ..
            tostring(#objects) ..
            " | wave=" ..
            tostring(meta.waveName)
        )

        if #objects == 0 then
            self.log("WARNING: accepted spawn result, but no spawned objects found")

            if meta.skipEmptySpawnRetries then
                self.log(
                    "Empty spawn result retry skipped | wave=" ..
                    tostring(meta.waveName) ..
                    " | index=" ..
                    tostring(meta.spawnIndex)
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

    self:checkMission()
    self.hud:updateCountdown(false)
    self.hud:updatePending()
    self:updatePendingSpawnTracks()
    self.spawner:updateTeleportCorrections()
    self.ai:updateDelayedAwareness()
    self.spawner:checkSpawnTimeouts()

    if
        #self.state.spawnQueue > 0 and
        self.state.spawnQueueTimer >= self.settings.SPAWN_INTERVAL and
        not self.spawner:hasPendingSpawnRequests()
    then
        self.state.spawnQueueTimer = 0
        local item = table.remove(self.state.spawnQueue, 1)

        self.log(
            "Spawning queued NPC | wave=" ..
            tostring(item.wave.name) ..
            " | index=" ..
            tostring(item.spawnIndex) ..
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

    self:updateWaveCompletion()
end

return MissionController
