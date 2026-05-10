local State = {}
State.__index = State

function State.new()
    local self = setmetatable({}, State)
    self:resetMission()
    self:resetRuntime()
    self.lastHUDText = ""
    return self
end

function State:resetMission()
    self.missionActive = false
    self.markerActive = false
    self.activeMappin = nil
    self.activeTreasureMappin = nil
    self.activeTreasure = nil
    self.claimedTreasures = {}
    self.waveAliveSeen = {}
    self.waveDefeatedObjects = {}
    self.currentWaveIndex = 0
    self.highestWaveStarted = 0
    self.currentMarkerWaveIndex = nil
    self.waveCompletionHandled = false
    self.lastWaveStartTime = nil
    self.lastCompletionWaitLogTime = nil
    self.lastCompletionBlockedLogTime = nil
end

function State:resetRuntime()
    self.pendingRequests = {}
    self.pendingNoHashRequests = {}
    self.pendingSpawnTracks = {}
    self.pendingHUDMessages = {}
    self.delayedCombatActions = {}
    self.pendingTeleportCorrections = {}
    self.spawnedObjects = {}
    self.spawnedObjectHashes = {}
    self.spawnedObjectMetas = {}
    self.spawnQueue = {}
end

function State:resetTimers()
    self.elapsed = 0
    self.spawnQueueTimer = 0
    self.globalAggroTimer = 0
    self.chasePlayerTimer = 0
    self.countdownLogTimer = 0
    self.hudCountdownTimer = 0
    self.spawnTimeoutTimer = 0
    self.waveCompletionTimer = 0
end

function State:clearSpawnRuntime()
    self.pendingRequests = {}
    self.pendingNoHashRequests = {}
    self.pendingSpawnTracks = {}
    self.pendingHUDMessages = {}
    self.delayedCombatActions = {}
    self.pendingTeleportCorrections = {}
    self.spawnQueue = {}
    self.spawnedObjects = {}
    self.spawnedObjectHashes = {}
    self.spawnedObjectMetas = {}
end

return State
