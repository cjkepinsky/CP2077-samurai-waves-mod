local SpawnPlanner = {}
SpawnPlanner.__index = SpawnPlanner

function SpawnPlanner.new(deps)
    return setmetatable({
        settings = deps.settings,
        waves = deps.waves,
        spawnLines = deps.spawnLines,
        geometry = deps.geometry,
        log = deps.log
    }, SpawnPlanner)
end

function SpawnPlanner:getWaveMinSpawnDistance(wave)
    return (wave and wave.minSpawnDistance) or self.settings.MIN_SPAWN_DISTANCE_FROM_PLAYER
end

function SpawnPlanner:getSpawnPointCandidates(wave, playerPos)
    if not wave or not wave.spawnPoints or #wave.spawnPoints <= 0 then
        return nil
    end

    local sourcePoints = wave.spawnPoints
    local firstIndex = wave.spawnPointStartIndex or 1
    local endIndex = wave.spawnPointEndIndex or #wave.spawnPoints

    if firstIndex < 1 then firstIndex = 1 end
    if endIndex > #wave.spawnPoints then endIndex = #wave.spawnPoints end

    if firstIndex ~= 1 or endIndex ~= #wave.spawnPoints then
        sourcePoints = {}

        for i = firstIndex, endIndex do
            table.insert(sourcePoints, wave.spawnPoints[i])
        end

        if #sourcePoints <= 0 then
            sourcePoints = wave.spawnPoints
        end
    end

    if not wave.sameFloorOnly or not playerPos then
        return sourcePoints
    end

    local tolerance = wave.sameFloorZTolerance or 25.0
    local candidates = {}

    for _, point in ipairs(sourcePoints) do
        if math.abs((point.z or 0) - (playerPos.z or 0)) <= tolerance then
            table.insert(candidates, point)
        end
    end

    if #candidates > 0 then
        return candidates
    end

    return sourcePoints
end

function SpawnPlanner:getFallbackLinePoint(lineIndex, count, spawnIndex)
    local line = self.spawnLines[lineIndex] or self.spawnLines[1]
    return self.geometry.linePoint(line.edgeA, line.edgeB, count, spawnIndex)
end

function SpawnPlanner:getWaveLinePoint(wave, count, spawnIndex)
    if wave.spawnLineRows and wave.spawnLineRows > 1 then
        return self.geometry.lineGridPoint(
            wave.spawnLine.edgeA,
            wave.spawnLine.edgeB,
            count,
            spawnIndex,
            wave.spawnLineRows,
            wave.spawnLineRowSpacing
        )
    end

    return self.geometry.linePoint(wave.spawnLine.edgeA, wave.spawnLine.edgeB, count, spawnIndex)
end

function SpawnPlanner:getConfiguredSpawnPoint(wave, spawnIndex)
    if wave.spawnPoints and #wave.spawnPoints > 0 then
        local player = Game.GetPlayer()
        local playerPos = player and player:GetWorldPosition() or nil
        local candidates = self:getSpawnPointCandidates(wave, playerPos)
        local index = spawnIndex

        if index > #candidates then
            index = ((index - 1) % #candidates) + 1
        end

        return candidates[index]
    end

    if wave.spawnLine then
        if wave.extraSpawnPoint and wave.extraSpawnFromIndex and spawnIndex >= wave.extraSpawnFromIndex then
            return wave.extraSpawnPoint
        end

        return self:getWaveLinePoint(wave, wave.count, spawnIndex)
    end

    return self:getFallbackLinePoint(wave.safeLine or 1, wave.count, spawnIndex)
end

function SpawnPlanner:getWaveMarkerPos(waveIndex)
    local wave = self.waves[waveIndex]
    if not wave then return nil end

    if wave.markerPos then
        return wave.markerPos
    end

    if wave.spawnPoints and #wave.spawnPoints > 0 then
        local candidates = self:getSpawnPointCandidates(wave, nil)
        return candidates[1]
    end

    if wave.spawnLine then
        return self.geometry.linePoint(wave.spawnLine.edgeA, wave.spawnLine.edgeB, 2, 1)
    end

    return self:getConfiguredSpawnPoint(wave, 1)
end

function SpawnPlanner:pushPointAwayFromPlayer(wave, point, spawnIndex, minDistance)
    local player = Game.GetPlayer()
    return self.geometry.pushAwayFromPlayer(
        player,
        wave,
        point,
        spawnIndex,
        minDistance,
        self.settings.SPAWN_PUSH_SIDE_SPACING
    )
end

function SpawnPlanner:getWaveNPC(wave, index)
    if wave.npcs and #wave.npcs > 0 then
        local npcIndex = ((index - 1) % #wave.npcs) + 1
        return wave.npcs[npcIndex]
    end

    return wave.npc
end

function SpawnPlanner:getFarthestSpawnPointFromPlayer(wave, spawnIndex)
    local player = Game.GetPlayer()

    if not player then
        return self:getConfiguredSpawnPoint(wave, spawnIndex)
    end

    local playerPos = player:GetWorldPosition()
    local bestPoint = nil
    local bestDistance = -1

    if wave.spawnPoints and #wave.spawnPoints > 0 then
        local candidates = self:getSpawnPointCandidates(wave, playerPos)

        for _, point in ipairs(candidates) do
            local d = self.geometry.distance(playerPos, point)

            if d > bestDistance then
                bestDistance = d
                bestPoint = point
            end
        end

        return bestPoint
    end

    if wave.spawnLine then
        for i = 1, wave.count do
            local point = self:getWaveLinePoint(wave, wave.count, i)
            local d = self.geometry.distance(playerPos, point)

            if d > bestDistance then
                bestDistance = d
                bestPoint = point
            end
        end

        return bestPoint
    end

    for lineIndex = 1, #self.spawnLines do
        local point = self:getFallbackLinePoint(lineIndex, wave.count, spawnIndex)
        local d = self.geometry.distance(playerPos, point)

        if d > bestDistance then
            bestDistance = d
            bestPoint = point
        end
    end

    return bestPoint
end

function SpawnPlanner:getSafeSpawnPoint(wave, spawnIndex)
    local player = Game.GetPlayer()
    local preferredPos = self:getConfiguredSpawnPoint(wave, spawnIndex)
    local minSpawnDistance = self:getWaveMinSpawnDistance(wave)

    if wave and wave.lockSpawnPosition then
        return preferredPos
    end

    if wave.spawnPoints and #wave.spawnPoints > 0 then
        if wave.enforceMinSpawnDistance and player then
            local playerPos = player:GetWorldPosition()
            local d = self.geometry.distance(playerPos, preferredPos)

            if d < minSpawnDistance then
                local fallback = preferredPos

                if wave.pushSpawnAway then
                    fallback = self:pushPointAwayFromPlayer(wave, preferredPos, spawnIndex, minSpawnDistance)
                else
                    fallback = self:getFarthestSpawnPointFromPlayer(wave, spawnIndex)
                end

                self.log(
                    "Exact spawn point too close. Using safer point | wave=" ..
                    tostring(wave.name) ..
                    " | index=" ..
                    tostring(spawnIndex) ..
                    " | oldDist=" ..
                    tostring(math.floor(d)) ..
                    " | newDist=" ..
                    tostring(math.floor(self.geometry.distance(playerPos, fallback)))
                )

                return fallback
            end
        end

        return preferredPos
    end

    if not player then
        return preferredPos
    end

    local playerPos = player:GetWorldPosition()
    local d = self.geometry.distance(playerPos, preferredPos)

    if d >= minSpawnDistance then
        return preferredPos
    end

    local fallback = self:getFarthestSpawnPointFromPlayer(wave, spawnIndex)
    local fallbackDistance = self.geometry.distance(playerPos, fallback)

    if wave.pushSpawnAway and fallbackDistance < minSpawnDistance then
        fallback = self:pushPointAwayFromPlayer(wave, fallback, spawnIndex, minSpawnDistance)
        fallbackDistance = self.geometry.distance(playerPos, fallback)
    end

    self.log(
        "Spawn point too close. Using fallback | wave=" ..
        tostring(wave.name) ..
        " | index=" ..
        tostring(spawnIndex) ..
        " | oldDist=" ..
        tostring(math.floor(d)) ..
        " | newDist=" ..
        tostring(math.floor(fallbackDistance))
    )

    return fallback
end

return SpawnPlanner
