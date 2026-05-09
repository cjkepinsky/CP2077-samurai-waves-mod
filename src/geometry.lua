local Geometry = {}

function Geometry.toV4(pos)
    return Vector4.new(pos.x, pos.y, pos.z, 1)
end

function Geometry.distance(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Geometry.lerp(a, b, t)
    return a + (b - a) * t
end

function Geometry.linePoint(edgeA, edgeB, count, index)
    local t = 0

    if count > 1 then
        t = (index - 1) / (count - 1)
    end

    return {
        x = Geometry.lerp(edgeA.x, edgeB.x, t),
        y = Geometry.lerp(edgeA.y, edgeB.y, t),
        z = Geometry.lerp(edgeA.z, edgeB.z, t),
        w = 1
    }
end

function Geometry.pushAwayFromPlayer(player, wave, point, spawnIndex, minDistance, sideSpacing)
    if not player or not point then return point end

    local playerPos = player:GetWorldPosition()
    local dx = point.x - playerPos.x
    local dy = point.y - playerPos.y
    local len = math.sqrt(dx * dx + dy * dy)

    if len < 0.01 and wave and wave.spawnLine then
        dx = wave.spawnLine.edgeB.x - wave.spawnLine.edgeA.x
        dy = wave.spawnLine.edgeB.y - wave.spawnLine.edgeA.y
        len = math.sqrt(dx * dx + dy * dy)
    end

    if len < 0.01 then
        pcall(function()
            local forward = player:GetWorldForward()
            dx = forward.x
            dy = forward.y
            len = math.sqrt(dx * dx + dy * dy)
        end)
    end

    if len < 0.01 then
        dx = 1
        dy = 0
        len = 1
    end

    dx = dx / len
    dy = dy / len

    local sideSlot = ((spawnIndex or 1) - 1) % 3
    local sideOffset = (sideSlot - 1) * (sideSpacing or 0)

    return {
        x = playerPos.x + dx * minDistance - dy * sideOffset,
        y = playerPos.y + dy * minDistance + dx * sideOffset,
        z = point.z,
        w = 1
    }
end

return Geometry
