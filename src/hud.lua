local HUD = {}
HUD.__index = HUD

function HUD.new(deps)
    return setmetatable({
        state = deps.state,
        settings = deps.settings,
        log = deps.log
    }, HUD)
end

function HUD:show(text)
    local message = tostring(text or "")
    local ok, err = pcall(function()
        local screenMessage = SimpleScreenMessage.new()
        screenMessage.message = message
        screenMessage.isShown = true

        local blackboardDefs = Game.GetAllBlackboardDefs()
        local blackboardUI = Game.GetBlackboardSystem():Get(blackboardDefs.UI_Notifications)

        blackboardUI:SetVariant(
            blackboardDefs.UI_Notifications.OnscreenMessage,
            ToVariant(screenMessage),
            true
        )
    end)

    if not ok then
        self.log("HUD message failed: " .. tostring(err))
    end

    self.state.lastHUDText = message
    self.log("HUD: " .. message)
end

function HUD:schedule(text, delay)
    table.insert(self.state.pendingHUDMessages, {
        text = text,
        fireAt = self.state.elapsed + delay
    })
end

function HUD:updatePending()
    for i = #self.state.pendingHUDMessages, 1, -1 do
        local item = self.state.pendingHUDMessages[i]

        if self.state.elapsed >= item.fireAt then
            self:show(item.text)
            table.remove(self.state.pendingHUDMessages, i)
        end
    end
end

function HUD:showWaveStart(waveIndex, wave)
    self:show(wave.startMessage or ("Wave " .. tostring(waveIndex) .. " started."))

    if wave.startMessage then
        self:schedule(wave.startMessage, self.settings.HUD_WAVE_START_REPEAT_DELAY or 2.0)
    end
end

function HUD:getCountdownText()
    return ""
end

function HUD:updateCountdown(_force)
    return
end

return HUD
