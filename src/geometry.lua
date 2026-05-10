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

function Geometry.lineGridPoint(edgeA, edgeB, count, index, rows, rowSpacing)
    rows = math.max(1, math.floor(rows or 1))

    if rows <= 1 then
        return Geometry.linePoint(edgeA, edgeB, count, index)
    end

    local row = ((index - 1) % rows) + 1
    local indexInRow = math.floor((index - 1) / rows) + 1
    local countInRow = math.floor((count - row) / rows) + 1
    if countInRow < 1 then countInRow = 1 end
    local base = Geometry.linePoint(edgeA, edgeB, countInRow, indexInRow)

    local dx = edgeB.x - edgeA.x
    local dy = edgeB.y - edgeA.y
    local len = math.sqrt(dx * dx + dy * dy)

    if len < 0.01 then
        return base
    end

    local spacing = rowSpacing or 1.0
    local offset = (row - ((rows + 1) / 2)) * spacing

    return {
        x = base.x - (dy / len) * offset,
        y = base.y + (dx / len) * offset,
        z = base.z,
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
