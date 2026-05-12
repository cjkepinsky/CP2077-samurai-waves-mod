local Spawner = {}
Spawner.__index = Spawner

function Spawner.new(deps)
    return setmetatable({
        state = deps.state,
        settings = deps.settings,
        waves = deps.waves,
        planner = deps.planner,
        ai = deps.ai,
        geometry = deps.geometry,
        resolveTDBID = deps.resolveTDBID,
        log = deps.log
    }, Spawner)
end

function Spawner:isDefined(obj)
    if not obj then return false end

    local ok, result = pcall(function()
        return IsDefined(obj)
    end)

    return ok and result == true
end

function Spawner:getEntityHash(obj)
    if not obj then return nil end

    local ok, result = pcall(function()
        return obj:GetEntityID().hash
    end)

    if ok and result then return result end
    return nil
end

function Spawner:getObjectWorldPosition(obj)
    if not obj then return nil end

    local ok, result = pcall(function()
        return obj:GetWorldPosition()
    end)

    if ok and result then return result end
    return nil
end

function Spawner:getObjectDistanceFromPosition(obj, pos)
    if not obj or not pos then return nil end

    local objPos = self:getObjectWorldPosition(obj)
    if not objPos then return nil end

    return self.geometry.distance(objPos, pos)
end

function Spawner:getClosestObjectDistance(objects, pos)
    if not objects or not pos then return nil end

    local bestDistance = nil

    for _, obj in ipairs(objects) do
        local distance = self:getObjectDistanceFromPosition(obj, pos)

        if distance and (not bestDistance or distance < bestDistance) then
            bestDistance = distance
        end
    end

    return bestDistance
end

function Spawner:findNoHashSpawnMatch(objects)
    local bestIndex = nil
    local bestDistance = nil

    for i, meta in ipairs(self.state.pendingNoHashRequests) do
        local distance = self:getClosestObjectDistance(objects, meta.pos)

        if distance and (not bestDistance or distance < bestDistance) then
            bestIndex = i
            bestDistance = distance
        end
    end

    local maxDistance = self.settings.NO_HASH_SPAWN_MATCH_DISTANCE or 120.0

    if bestIndex and bestDistance and bestDistance <= maxDistance then
        return bestIndex, bestDistance
    end

    return nil, bestDistance
end

function Spawner:countPendingRequests()
    local count = 0

    for _, _ in pairs(self.state.pendingRequests) do
        count = count + 1
    end

    return count
end

function Spawner:hasPendingSpawnRequests()
    local maxPendingNoHash = self.settings.MAX_PENDING_NO_HASH_REQUESTS or 1
    if maxPendingNoHash < 1 then maxPendingNoHash = 1 end

    return self:countPendingRequests() > 0 or #self.state.pendingNoHashRequests >= maxPendingNoHash
end

function Spawner:countTrackedNPCs()
    return #self.state.spawnedObjects
end

function Spawner:countValidNPCs()
    local count = 0

    for _, npc in ipairs(self.state.spawnedObjects) do
        if self:isDefined(npc) then
            count = count + 1
        end
    end

    return count
end

function Spawner:setTransformPositionSafe(transform, pos)
    local vec = self.geometry.toV4(pos)

    local okA = pcall(function()
        transform:SetPosition(vec)
    end)

    if okA then return true end

    local okB = pcall(function()
        transform:SetPosition(transform, vec)
    end)

    return okB == true
end

function Spawner:getTransformPositionSafe(transform)
    if not transform then return nil end

    local okA, resultA = pcall(function()
        return transform:GetPosition()
    end)

    if okA and resultA then return resultA end

    local okB, resultB = pcall(function()
        return transform:GetPosition(transform)
    end)

    if okB and resultB then return resultB end

    return nil
end

function Spawner:createSpawnTransform(player, pos)
    local attempts = {
        {
            name = "WorldTransform.new",
            create = function()
                return WorldTransform.new()
            end
        },
        {
            name = "NewObject(WorldTransform)",
            create = function()
                return NewObject("WorldTransform")
            end
        },
        {
            name = "player:GetWorldTransform",
            create = function()
                return player:GetWorldTransform()
            end
        }
    }

    for _, attempt in ipairs(attempts) do
        local ok, transform = pcall(attempt.create)

        if ok and transform and self:setTransformPositionSafe(transform, pos) then
            return transform, attempt.name
        end
    end

    return nil, "none"
end

function Spawner:shouldEnforceMinSpawnDistance(wave, usesExactSpawnPoints)
    if wave and wave.lockSpawnPosition then return false end

    return (not usesExactSpawnPoints) or (wave and wave.enforceMinSpawnDistance == true)
end

function Spawner:verifySpawnTransform(transform, expectedPos, playerPos, waveName, spawnIndex)
    local actualPos = self:getTransformPositionSafe(transform)

    if not actualPos then
        self.log(
            "WARNING: spawn transform position could not be verified | wave=" ..
            tostring(waveName) ..
            " | index=" ..
            tostring(spawnIndex)
        )
        return true
    end

    local distanceToExpected = self.geometry.distance(actualPos, expectedPos)

    if distanceToExpected <= 1.0 then
        return true
    end

    local distanceToPlayer = playerPos and self.geometry.distance(actualPos, playerPos) or 9999

    self.log(
        "ERROR: spawn transform points away from final position. Spawn cancelled | wave=" ..
        tostring(waveName) ..
        " | index=" ..
        tostring(spawnIndex) ..
        " | transformDist=" ..
        tostring(math.floor(distanceToExpected)) ..
        " | transformPlayerDist=" ..
        tostring(math.floor(distanceToPlayer))
    )

    return false
end

function Spawner:getNavigationSystem()
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

function Spawner:isNavmeshStatusOK(status)
    if status == nil then return true end
    if status == 0 then return true end

    local okEnum, isOK = pcall(function()
        return worldNavigationRequestStatus and status == worldNavigationRequestStatus.OK
    end)

    if okEnum and isOK then return true end

    local text = string.lower(tostring(status))
    return text == "ok" or string.find(text, "ok") ~= nil
end

function Spawner:getNavmeshResultStatus(result)
    if not result then return nil end

    local ok, status = pcall(function()
        return result.status
    end)

    if ok then return status end
    return nil
end

function Spawner:getHumanNavmeshAgentSize()
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

function Spawner:extractNavmeshPoint(result, alternatePoint)
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

        if point then
            return point
        end
    end

    return asPoint(alternatePoint)
end

function Spawner:findHumanNavmeshPoint(pos, radius)
    local nav = self:getNavigationSystem()
    if not nav then
        return nil, nil, nil, "navigation system unavailable"
    end

    local origin = self.geometry.toV4(pos)
    local agentSize = self:getHumanNavmeshAgentSize()

    local attempts = {
        {
            name = "colon/vector/radius/human/false",
            call = function()
                return nav:FindPointInSphereOnlyHumanNavmesh(origin, radius, agentSize, false)
            end
        },
        {
            name = "dot/vector/radius/human/false",
            call = function()
                return nav.FindPointInSphereOnlyHumanNavmesh(nav, origin, radius, agentSize, false)
            end
        },
        {
            name = "colon/vector/radius/0/false",
            call = function()
                return nav:FindPointInSphereOnlyHumanNavmesh(origin, radius, 0, false)
            end
        },
        {
            name = "dot/vector/radius/0/false",
            call = function()
                return nav.FindPointInSphereOnlyHumanNavmesh(nav, origin, radius, 0, false)
            end
        }
    }

    local errors = {}
    local function addAttemptError(message)
        errors[#errors + 1] = message
    end

    for _, attempt in ipairs(attempts) do
        local ok, result, alternatePoint = pcall(attempt.call)

        if ok then
            local status =
                self:getNavmeshResultStatus(result) or
                self:getNavmeshResultStatus(alternatePoint)
            local point = self:extractNavmeshPoint(result, alternatePoint)

            if point and self:isNavmeshStatusOK(status) then
                local navPos = {
                    x = point.x,
                    y = point.y,
                    z = point.z,
                    w = point.w or 1
                }
                local distance = self.geometry.distance(pos, navPos)

                if distance <= radius + 0.01 then
                    return true, navPos, distance, tostring(status or "OK")
                end

                return false, nil, distance, "navmesh point outside radius"
            end

            if status ~= nil and not self:isNavmeshStatusOK(status) then
                return false, nil, nil, "status=" .. tostring(status)
            end

            addAttemptError(attempt.name .. " returned no point")
        else
            addAttemptError(attempt.name .. " failed: " .. tostring(result))
        end
    end

    if #errors > 0 then
        return nil, nil, nil, table.concat(errors, " ; ")
    end

    return nil, nil, nil, "navmesh query returned no point"
end

function Spawner:applyHumanNavmeshCheck(wave, pos, spawnIndex)
    local radius = wave and wave.humanNavmeshCheckRadius or nil
    if not radius or radius <= 0 then return true, pos end
    local required = wave and wave.humanNavmeshRequired == true

    local ok, navPos, distance, detail = self:findHumanNavmeshPoint(pos, radius)

    if ok and navPos then
        self.log(
            "Human navmesh check OK | wave=" ..
            tostring(wave.name) ..
            " | index=" ..
            tostring(spawnIndex) ..
            " | radius=" ..
            tostring(radius) ..
            " | offset=" ..
            tostring(distance)
        )

        return true, navPos
    end

    if not required then
        self.log(
            "WARNING: human navmesh check failed; using configured spawn point | wave=" ..
            tostring(wave.name) ..
            " | index=" ..
            tostring(spawnIndex) ..
            " | radius=" ..
            tostring(radius) ..
            " | detail=" ..
            tostring(detail) ..
            " | x=" ..
            tostring(pos.x) ..
            " | y=" ..
            tostring(pos.y) ..
            " | z=" ..
            tostring(pos.z)
        )

        return true, pos
    end

    if ok == nil then
        self.log(
            "ERROR: human navmesh check unavailable. Spawn cancelled | wave=" ..
            tostring(wave.name) ..
            " | index=" ..
            tostring(spawnIndex) ..
            " | radius=" ..
            tostring(radius) ..
            " | detail=" ..
            tostring(detail)
        )

        return false, pos
    end

    self.log(
        "ERROR: human navmesh check failed. Spawn cancelled | wave=" ..
        tostring(wave.name) ..
        " | index=" ..
        tostring(spawnIndex) ..
        " | radius=" ..
        tostring(radius) ..
        " | detail=" ..
        tostring(detail) ..
        " | x=" ..
        tostring(pos.x) ..
        " | y=" ..
        tostring(pos.y) ..
        " | z=" ..
        tostring(pos.z)
    )

    return false, pos
end

function Spawner:teleportEntityToPos(entity, pos)
    if not entity or not pos then return false end

    local okCommand = pcall(function()
        local teleportCmd = nil

        if AITeleportCommand and AITeleportCommand.new then
            teleportCmd = AITeleportCommand.new()
        else
            teleportCmd = NewObject("AITeleportCommand")
        end

        teleportCmd.position = self.geometry.toV4(pos)
        teleportCmd.rotation = 0
        teleportCmd.doNavTest = false

        local controller = entity:GetAIControllerComponent()
        if not controller then
            error("AI controller unavailable")
        end

        controller:SendCommand(teleportCmd)
    end)

    if okCommand then return true end

    local ok1 = pcall(function()
        Game.GetTeleportationFacility():Teleport(
            entity,
            ToVector4 { x = pos.x, y = pos.y, z = pos.z, w = 1 },
            ToEulerAngles { roll = 0, pitch = 0, yaw = 0 }
        )
    end)

    if ok1 then return true end

    local ok2 = pcall(function()
        Game.GetTeleportationFacility():Teleport(
            entity,
            Vector4.new(pos.x, pos.y, pos.z, 1),
            EulerAngles.new(0, 0, 0)
        )
    end)

    return ok2 == true
end

function Spawner:isPostSpawnTeleportCorrectionEnabled(meta)
    if self.settings.POST_SPAWN_TELEPORT_CORRECTION_ENABLED == false then
        return false
    end

    if meta and meta.disablePostSpawnCorrection then
        return false
    end

    return true
end

function Spawner:scheduleTeleportCorrections(npc, meta)
    if not npc or not meta or not meta.pos then return end
    if not self:isPostSpawnTeleportCorrectionEnabled(meta) then return end

    if not self.state.pendingTeleportCorrections then
        self.state.pendingTeleportCorrections = {}
    end

    local delays = self.settings.POST_SPAWN_TELEPORT_CORRECTION_DELAYS or { 0.1, 0.35, 0.8 }

    for _, delay in ipairs(delays) do
        table.insert(self.state.pendingTeleportCorrections, {
            npc = npc,
            pos = {
                x = meta.pos.x,
                y = meta.pos.y,
                z = meta.pos.z,
                w = meta.pos.w or 1
            },
            fireAt = self.state.elapsed + delay,
            waveName = meta.waveName,
            spawnIndex = meta.spawnIndex
        })
    end
end

function Spawner:updateTeleportCorrections()
    local pending = self.state.pendingTeleportCorrections
    if not pending then return end

    if self.settings.POST_SPAWN_TELEPORT_CORRECTION_ENABLED == false then
        self.state.pendingTeleportCorrections = {}
        return
    end

    local tolerance =
        self.settings.TELEPORT_CORRECTION_TOLERANCE or
        self.settings.SPAWN_POSITION_TOLERANCE or
        8.0

    for i = #pending, 1, -1 do
        local item = pending[i]

        if self.state.elapsed >= item.fireAt then
            if item.npc and item.pos and self:isDefined(item.npc) then
                local expectedDistance = self:getObjectDistanceFromPosition(item.npc, item.pos)

                if expectedDistance and expectedDistance > tolerance then
                    local teleportOk = self:teleportEntityToPos(item.npc, item.pos)

                    self.log(
                        "Delayed teleport correction | wave=" ..
                        tostring(item.waveName) ..
                        " | index=" ..
                        tostring(item.spawnIndex) ..
                        " | expectedDist=" ..
                        tostring(math.floor(expectedDistance)) ..
                        " | teleportOk=" ..
                        tostring(teleportOk)
                    )
                end
            end

            table.remove(pending, i)
        end
    end
end

function Spawner:despawnNPC(npc)
    if not npc then return end

    self:teleportEntityToPos(npc, { x = 9999, y = 9999, z = 0, w = 1 })

    pcall(function()
        Game.GetPreventionSpawnSystem():RequestDespawn(npc:GetEntityID())
    end)
end

function Spawner:requeueSameSpawn(meta, reason)
    if not meta or not meta.waveIndex then return false end

    local wave = self.waves[meta.waveIndex]
    if not wave then return false end

    local retryCount = (meta.retryCount or 0) + 1

    if retryCount > self.settings.MAX_BAD_POSITION_RETRIES then
        self.log(
            "Requeue same spawn skipped: retry limit reached | wave=" ..
            tostring(meta.waveName) ..
            " | index=" ..
            tostring(meta.spawnIndex) ..
            " | reason=" ..
            tostring(reason)
        )
        return false
    end

    table.insert(self.state.spawnQueue, {
        npc = meta.npc,
        wave = wave,
        waveIndex = meta.waveIndex,
        spawnIndex = meta.spawnIndex,
        pos = meta.pos,
        retryCount = retryCount,
        fallbackRetryCount = meta.fallbackRetryCount or 0,
        forcedFallback = meta.forcedFallback or false
    })

    self.log(
        "Requeued same spawn | wave=" ..
        tostring(meta.waveName) ..
        " | index=" ..
        tostring(meta.spawnIndex) ..
        " | retry=" ..
        tostring(retryCount) ..
        " | reason=" ..
        tostring(reason)
    )

    return true
end

function Spawner:requeueFallbackSpawn(meta, reason)
    if not meta or not meta.waveIndex then return false end

    local wave = self.waves[meta.waveIndex]
    if not wave or not wave.fallbackNpc then return false end

    local fallbackRetryCount = (meta.fallbackRetryCount or 0) + 1

    if fallbackRetryCount > self.settings.MAX_FALLBACK_RETRIES then
        self.log(
            "Fallback spawn skipped: retry limit reached | wave=" ..
            tostring(meta.waveName) ..
            " | index=" ..
            tostring(meta.spawnIndex) ..
            " | reason=" ..
            tostring(reason)
        )
        return false
    end

    table.insert(self.state.spawnQueue, {
        npc = wave.fallbackNpc,
        wave = wave,
        waveIndex = meta.waveIndex,
        spawnIndex = meta.spawnIndex,
        pos = meta.pos,
        retryCount = meta.retryCount or 0,
        fallbackRetryCount = fallbackRetryCount,
        forcedFallback = true
    })

    self.log(
        "Requeued fallback spawn | wave=" ..
        tostring(meta.waveName) ..
        " | index=" ..
        tostring(meta.spawnIndex) ..
        " | fallbackRetry=" ..
        tostring(fallbackRetryCount) ..
        " | reason=" ..
        tostring(reason)
    )

    return true
end

function Spawner:trackSpawnedObject(obj, meta)
    if not obj then
        self.log("trackSpawnedObject skipped: nil")
        return false
    end

    local expectedPos = meta and meta.pos or nil

    if expectedPos and not self:isPostSpawnTeleportCorrectionEnabled(meta) then
        local playerDist = self.ai:getDistanceFromPlayer(obj)
        local expectedDistance = self:getObjectDistanceFromPosition(obj, expectedPos)
        local playerDistText = playerDist and tostring(math.floor(playerDist)) or "unknown"
        local expectedDistanceText = expectedDistance and tostring(math.floor(expectedDistance)) or "unknown"

        self.log(
            "Post-spawn correction skipped | wave=" ..
            tostring(meta.waveName) ..
            " | index=" ..
            tostring(meta.spawnIndex) ..
            " | globalEnabled=" ..
            tostring(self.settings.POST_SPAWN_TELEPORT_CORRECTION_ENABLED ~= false) ..
            " | waveDisabled=" ..
            tostring(meta and meta.disablePostSpawnCorrection == true) ..
            " | distFromPlayer=" ..
            playerDistText ..
            " | expectedDist=" ..
            expectedDistanceText
        )
    elseif expectedPos then
        local minSpawnDistance = (meta and meta.minSpawnDistance) or self.settings.MIN_SPAWN_DISTANCE_FROM_PLAYER
        local enforceMinSpawnDistance = meta and meta.enforceMinSpawnDistance
        local beforeDist = self.ai:getDistanceFromPlayer(obj)
        local teleportOk = self:teleportEntityToPos(obj, expectedPos)
        local afterDist = self.ai:getDistanceFromPlayer(obj)
        local expectedDistance = self:getObjectDistanceFromPosition(obj, expectedPos)
        local expectedDistanceText = expectedDistance and tostring(math.floor(expectedDistance)) or "unknown"

        self.log(
            "Post-spawn teleport | wave=" ..
            tostring(meta.waveName) ..
            " | index=" ..
            tostring(meta.spawnIndex) ..
            " | teleportOk=" ..
            tostring(teleportOk) ..
            " | beforeDist=" ..
            tostring(math.floor(beforeDist)) ..
            " | afterDist=" ..
            tostring(math.floor(afterDist)) ..
            " | expectedDist=" ..
            expectedDistanceText
        )

        self:scheduleTeleportCorrections(obj, meta)

        if (not meta.usesExactSpawnPoints or enforceMinSpawnDistance) and afterDist < minSpawnDistance then
            self.log(
                "WARNING: NPC still reports too close immediately after teleport command | wave=" ..
                tostring(meta.waveName) ..
                " | index=" ..
                tostring(meta.spawnIndex) ..
                " | dist=" ..
                tostring(math.floor(afterDist)) ..
                " | minDist=" ..
                tostring(math.floor(minSpawnDistance))
            )
        end

        local positionTolerance = self.settings.SPAWN_POSITION_TOLERANCE or 15.0

        if expectedDistance and expectedDistance > positionTolerance then
            self.log(
                "WARNING: NPC position still differs from expected after teleport | wave=" ..
                tostring(meta.waveName) ..
                " | index=" ..
                tostring(meta.spawnIndex) ..
                " | expectedDist=" ..
                tostring(math.floor(expectedDistance)) ..
                " | tolerance=" ..
                tostring(math.floor(positionTolerance))
            )
        end
    end

    local hash = self:getEntityHash(obj)

    if hash and self.state.spawnedObjectHashes[hash] then
        self.log("NPC already tracked: " .. tostring(hash))
        return false
    end

    if hash then
        self.state.spawnedObjectHashes[hash] = true
    end

    table.insert(self.state.spawnedObjects, obj)
    self.state.spawnedObjectMetas[obj] = meta or {}

    self.log(
        "NPC tracked | wave=" ..
        tostring(meta and meta.waveName or "unknown") ..
        " | index=" ..
        tostring(meta and meta.spawnIndex or "unknown") ..
        " | hash=" ..
        tostring(hash) ..
        " | distFromPlayer=" ..
        tostring(math.floor(self.ai:getDistanceFromPlayer(obj))) ..
        " | trackedNPCs=" ..
        tostring(self:countTrackedNPCs()) ..
        " | validNPCs=" ..
        tostring(self:countValidNPCs())
    )

    self.ai:scheduleSpawnAwarenessBurst(obj)

    return true
end

function Spawner:acceptSpawnResult(result, objects)
    local reqHash = nil
    local resultRequestID = nil

    pcall(function()
        if result and result.requestID then
            resultRequestID = result.requestID
            reqHash = result.requestID.hash
        end
    end)

    if reqHash and self.state.pendingRequests[reqHash] then
        local meta = self.state.pendingRequests[reqHash]
        self.state.pendingRequests[reqHash] = nil

        self.log(
            "SpawnRequestFinished accepted by HASH | reqHash=" ..
            tostring(reqHash) ..
            " | wave=" ..
            tostring(meta.waveName) ..
            " | index=" ..
            tostring(meta.spawnIndex)
        )

        return meta
    end

    if not reqHash and resultRequestID and #self.state.pendingNoHashRequests > 0 then
        for i, meta in ipairs(self.state.pendingNoHashRequests) do
            if meta.requestID and meta.requestID == resultRequestID then
                table.remove(self.state.pendingNoHashRequests, i)

                self.log(
                    "SpawnRequestFinished accepted by REQUEST-ID object | wave=" ..
                    tostring(meta.waveName) ..
                    " | index=" ..
                    tostring(meta.spawnIndex) ..
                    " | noHashPending=" ..
                    tostring(#self.state.pendingNoHashRequests)
                )

                return meta
            end
        end
    end

    if not reqHash and #self.state.pendingNoHashRequests > 0 then
        if objects and #objects > 0 then
            local matchIndex, matchDistance = self:findNoHashSpawnMatch(objects)

            if matchIndex then
                local meta = table.remove(self.state.pendingNoHashRequests, matchIndex)

                self.log(
                    "SpawnRequestFinished accepted by NO-HASH position match | wave=" ..
                    tostring(meta.waveName) ..
                    " | index=" ..
                    tostring(meta.spawnIndex) ..
                    " | matchDist=" ..
                    tostring(math.floor(matchDistance)) ..
                    " | noHashPending=" ..
                    tostring(#self.state.pendingNoHashRequests)
                )

                return meta
            end

            if not matchIndex and resultRequestID then
                local closestText = matchDistance and tostring(math.floor(matchDistance)) or "unknown"

                self.log(
                    "SpawnRequestFinished no REQUEST-ID match and no position match | closestDist=" ..
                    closestText ..
                    " | noHashPending=" ..
                    tostring(#self.state.pendingNoHashRequests)
                )
            elseif not matchIndex then
                local closestText = matchDistance and tostring(math.floor(matchDistance)) or "unknown"

                self.log(
                    "SpawnRequestFinished using NO-HASH FIFO fallback | closestDist=" ..
                    closestText ..
                    " | noHashPending=" ..
                    tostring(#self.state.pendingNoHashRequests)
                )
            end
        end

        if resultRequestID and #self.state.pendingNoHashRequests > 1 then
            self.log(
                "SpawnRequestFinished ignored: requestID object did not match multiple pending requests | noHashPending=" ..
                tostring(#self.state.pendingNoHashRequests)
            )

            return nil
        elseif resultRequestID then
            local meta = table.remove(self.state.pendingNoHashRequests, 1)

            self.log(
                "SpawnRequestFinished accepted by single-pending fallback after REQUEST-ID mismatch | wave=" ..
                tostring(meta.waveName) ..
                " | index=" ..
                tostring(meta.spawnIndex)
            )

            return meta
        end

        local meta = table.remove(self.state.pendingNoHashRequests, 1)

        self.log(
            "SpawnRequestFinished accepted by NO-HASH queue | wave=" ..
            tostring(meta.waveName) ..
            " | index=" ..
            tostring(meta.spawnIndex) ..
            " | noHashPending=" ..
            tostring(#self.state.pendingNoHashRequests)
        )

        return meta
    end

    self.log(
        "SpawnRequestFinished ignored | reqHash=" ..
        tostring(reqHash) ..
        " | hashPending=" ..
        tostring(self:countPendingRequests()) ..
        " | noHashPending=" ..
        tostring(#self.state.pendingNoHashRequests)
    )

    return nil
end

function Spawner:extractSpawnedObjects(result)
    local objects = {}

    local function addObject(obj)
        if obj then table.insert(objects, obj) end
    end

    pcall(function()
        if result.spawnedObjects then
            for _, obj in ipairs(result.spawnedObjects) do addObject(obj) end
        end
    end)

    pcall(function() if result.spawnedObject then addObject(result.spawnedObject) end end)
    pcall(function() if result.spawnedEntity then addObject(result.spawnedEntity) end end)

    pcall(function()
        if result.spawnedEntities then
            for _, obj in ipairs(result.spawnedEntities) do addObject(obj) end
        end
    end)

    pcall(function()
        if result.spawnedUnits then
            for _, obj in ipairs(result.spawnedUnits) do addObject(obj) end
        end
    end)

    return objects
end

function Spawner:requestSpawnItem(item)
    local player = Game.GetPlayer()

    if not player then
        self.log("No player")
        return
    end

    if not item or not item.wave or not item.npc then
        self.log("requestSpawnItem skipped: invalid item")
        return
    end

    local finalPos = item.pos or self.planner:getSafeSpawnPoint(item.wave, item.spawnIndex)
    local playerPos = player:GetWorldPosition()
    local spawnDistance = self.geometry.distance(playerPos, finalPos)
    local usesExactSpawnPoints = item.wave.spawnPoints and #item.wave.spawnPoints > 0
    local minSpawnDistance = self.planner:getWaveMinSpawnDistance(item.wave)
    local enforceMinSpawnDistance = self:shouldEnforceMinSpawnDistance(item.wave, usesExactSpawnPoints)

    if enforceMinSpawnDistance and spawnDistance < minSpawnDistance then
        local originalDistance = spawnDistance
        finalPos = self.planner:getFarthestSpawnPointFromPlayer(item.wave, item.spawnIndex)

        if item.wave.pushSpawnAway then
            finalPos = self.planner:pushPointAwayFromPlayer(item.wave, finalPos, item.spawnIndex, minSpawnDistance)
        end

        spawnDistance = self.geometry.distance(playerPos, finalPos)

        self.log(
            "Spawn position adjusted before request | wave=" ..
            tostring(item.wave.name) ..
            " | index=" ..
            tostring(item.spawnIndex) ..
            " | oldDist=" ..
            tostring(math.floor(originalDistance)) ..
            " | newDist=" ..
            tostring(math.floor(spawnDistance)) ..
            " | exactPoints=" ..
            tostring(usesExactSpawnPoints)
        )
    end

    if enforceMinSpawnDistance and spawnDistance < minSpawnDistance then
        self.log(
            "Final spawn still too close. Applying emergency push | wave=" ..
            tostring(item.wave.name) ..
            " | index=" ..
            tostring(item.spawnIndex) ..
            " | dist=" ..
            tostring(math.floor(spawnDistance))
        )

        finalPos = self.planner:pushPointAwayFromPlayer(item.wave, finalPos, item.spawnIndex, minSpawnDistance)
        spawnDistance = self.geometry.distance(playerPos, finalPos)

        self.log(
            "Emergency spawn push result | wave=" ..
            tostring(item.wave.name) ..
            " | index=" ..
            tostring(item.spawnIndex) ..
            " | newDist=" ..
            tostring(math.floor(spawnDistance))
        )
    end

    if enforceMinSpawnDistance and spawnDistance < minSpawnDistance then
        self.log(
            "ERROR: final spawn still too close after emergency push. Spawn cancelled | wave=" ..
            tostring(item.wave.name) ..
            " | index=" ..
            tostring(item.spawnIndex) ..
            " | dist=" ..
            tostring(math.floor(spawnDistance))
        )
        return
    end

    local navmeshOK, navmeshPos = self:applyHumanNavmeshCheck(item.wave, finalPos, item.spawnIndex)
    if not navmeshOK then return end

    finalPos = navmeshPos
    spawnDistance = self.geometry.distance(playerPos, finalPos)

    local npcTDBID = self.resolveTDBID(item.npc)

    if not npcTDBID then
        self.log(
            "ERROR: failed to resolve NPC TweakDBID | wave=" ..
            tostring(item.wave.name) ..
            " | index=" ..
            tostring(item.spawnIndex) ..
            " | npc=" ..
            tostring(item.npc)
        )
        return
    end

    local transform, transformSource = self:createSpawnTransform(player, finalPos)

    if not transform then
        self.log("ERROR: failed to create spawn transform. Spawn cancelled.")
        return
    end

    if not self:verifySpawnTransform(transform, finalPos, playerPos, item.wave.name, item.spawnIndex) then
        return
    end

    pcall(function()
        transform:SetOrientationEuler(EulerAngles.new(0, 0, math.random(0, 360)))
    end)

    self.log(
        "Spawn transform prepared | wave=" ..
        tostring(item.wave.name) ..
        " | index=" ..
        tostring(item.spawnIndex) ..
        " | source=" ..
        tostring(transformSource) ..
        " | x=" ..
        tostring(finalPos.x) ..
        " | y=" ..
        tostring(finalPos.y) ..
        " | z=" ..
        tostring(finalPos.z)
    )

    local ok, reqId = pcall(function()
        return Game.GetPreventionSpawnSystem():RequestUnitSpawn(npcTDBID, transform)
    end)

    local meta = {
        waveIndex = item.waveIndex,
        waveName = item.wave.name,
        club = item.wave.club,
        spawnIndex = item.spawnIndex,
        npc = item.npc,
        pos = finalPos,
        requestTime = self.state.elapsed,
        requestID = reqId,
        retryCount = item.retryCount or 0,
        fallbackRetryCount = item.fallbackRetryCount or 0,
        forcedFallback = item.forcedFallback or false,
        usesExactSpawnPoints = usesExactSpawnPoints,
        minSpawnDistance = minSpawnDistance,
        enforceMinSpawnDistance = enforceMinSpawnDistance,
        skipEmptySpawnRetries = item.wave.skipEmptySpawnRetries == true,
        disablePostSpawnCorrection = item.wave.disablePostSpawnCorrection == true
    }

    if ok and reqId then
        local reqHash = nil

        pcall(function()
            reqHash = reqId.hash
        end)

        if reqHash then
            self.state.pendingRequests[reqHash] = meta

            self.log(
                "RequestUnitSpawn OK HASH | wave=" ..
                tostring(item.wave.name) ..
                " | index=" ..
                tostring(item.spawnIndex) ..
                " | reqHash=" ..
                tostring(reqHash) ..
                " | spawnDist=" ..
                tostring(math.floor(spawnDistance))
            )
        else
            table.insert(self.state.pendingNoHashRequests, meta)

            self.log(
                "RequestUnitSpawn OK NO-HASH | wave=" ..
                tostring(item.wave.name) ..
                " | index=" ..
                tostring(item.spawnIndex) ..
                " | spawnDist=" ..
                tostring(math.floor(spawnDistance))
            )
        end

        return
    end

    self.log(
        "RequestUnitSpawn FAILED | wave=" ..
        tostring(item.wave.name) ..
        " | index=" ..
        tostring(item.spawnIndex) ..
        " | err=" ..
        tostring(reqId)
    )

    self:requeueFallbackSpawn(meta, "RequestUnitSpawn failed")
end

function Spawner:checkSpawnTimeouts()
    if self.state.spawnTimeoutTimer > 0 then return end
    self.state.spawnTimeoutTimer = 1.0

    for reqHash, meta in pairs(self.state.pendingRequests) do
        if self.state.elapsed - (meta.requestTime or self.state.elapsed) >= self.settings.SPAWN_RESULT_TIMEOUT then
            self.state.pendingRequests[reqHash] = nil

            self.log(
                "Spawn timeout HASH | wave=" ..
                tostring(meta.waveName) ..
                " | index=" ..
                tostring(meta.spawnIndex)
            )

            if meta.skipEmptySpawnRetries then
                self.log(
                    "Spawn timeout retry skipped | wave=" ..
                    tostring(meta.waveName) ..
                    " | index=" ..
                    tostring(meta.spawnIndex)
                )
            else
                self:requeueFallbackSpawn(meta, "hash spawn timeout")
            end
        end
    end

    for i = #self.state.pendingNoHashRequests, 1, -1 do
        local meta = self.state.pendingNoHashRequests[i]

        if self.state.elapsed - (meta.requestTime or self.state.elapsed) >= self.settings.SPAWN_RESULT_TIMEOUT then
            table.remove(self.state.pendingNoHashRequests, i)

            self.log(
                "Spawn timeout NO-HASH | wave=" ..
                tostring(meta.waveName) ..
                " | index=" ..
                tostring(meta.spawnIndex)
            )

            if meta.skipEmptySpawnRetries then
                self.log(
                    "Spawn timeout retry skipped | wave=" ..
                    tostring(meta.waveName) ..
                    " | index=" ..
                    tostring(meta.spawnIndex)
                )
            else
                self:requeueFallbackSpawn(meta, "no-hash spawn timeout")
            end
        end
    end
end

function Spawner:despawnAll()
    self.log("Despawning all spawned NPCs")

    for _, npc in ipairs(self.state.spawnedObjects) do
        if npc then
            self:despawnNPC(npc)
        end
    end

    self.state:clearSpawnRuntime()
end

return Spawner
