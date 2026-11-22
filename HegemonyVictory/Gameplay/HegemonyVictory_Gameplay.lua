include("HegemonyVictory_Rules")

local LAST_CHECKED_TURN = "HegemonyVictory_LastCheckedTurn"
local victory = GameInfo.Victories["VICTORY_HEGEMONY"]
local pendingCapturer

local function CheckVictory(trigger)
    if not HegemonyVictory.IsEnabled() then
        return
    end

    local winningTeam = Game.GetWinningTeam()
    if winningTeam ~= nil and winningTeam >= 0 then
        return
    end

    local snapshot = HegemonyVictory.Capture()
    if not snapshot then
        return
    end

    for _, playerID in ipairs(snapshot.ids) do
        local _, allMet = HegemonyVictory.Evaluate(snapshot, playerID)
        if allMet then
            local team = Players[playerID]:GetTeam()
            Game.SetWinningTeam(team, victory.Index)
            print("Hegemony Victory awarded to player", playerID, "on turn", Game.GetCurrentGameTurn(), trigger)
            return
        end
    end
end

local function OnGameTurnStarted()
    local turn = Game.GetCurrentGameTurn()
    if Game.GetProperty(LAST_CHECKED_TURN) ~= turn then
        Game.SetProperty(LAST_CHECKED_TURN, turn)
        CheckVictory("turn start")
    end
end

local function OnCityConquered(capturerID)
    pendingCapturer = capturerID
end

local function OnCombatOccurred(attackerID)
    -- CityConquered fires during melee resolution. Combat completion sees
    -- the transfer, occupation, and effects on the capturing unit applied.
    -- The old defending district no longer exists at this point.
    local capturer = pendingCapturer
    pendingCapturer = nil
    if capturer ~= nil and capturer == attackerID then
        CheckVictory("city conquest")
    end
end

if victory and HegemonyVictory.IsEnabled() then
    GameEvents.OnGameTurnStarted.Add(OnGameTurnStarted)
    GameEvents.CityConquered.Add(OnCityConquered)
    GameEvents.OnCombatOccurred.Add(OnCombatOccurred)
end
