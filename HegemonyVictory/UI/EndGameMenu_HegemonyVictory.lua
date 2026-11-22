local VICTORY_TYPE = "VICTORY_HEGEMONY"
local scoreStyle = Styles.VICTORY_SCORE

Styles[VICTORY_TYPE] = {
    RibbonIcon = "ICON_VICTORY_HEGEMONY",
    Ribbon = scoreStyle.Ribbon,
    RibbonTile = scoreStyle.RibbonTile,
    Background = scoreStyle.Background,
    Movie = scoreStyle.Movie,
    SndStart = scoreStyle.SndStart,
    SndStop = scoreStyle.SndStop,
    Color = scoreStyle.Color
}

local BaseTeamVictoryData = TeamVictoryData

function TeamVictoryData(winningTeamID, victoryType)
    local data = BaseTeamVictoryData(winningTeamID, victoryType)
    if victoryType == VICTORY_TYPE and not data.IsWinnerLocalPlayer then
        -- Preserve the defeat ribbon while presenting the winner's blurb and cinematic.
        local defeatStyle = {}
        for key, value in pairs(data.RibbonStyle) do
            defeatStyle[key] = value
        end
        defeatStyle.Movie = scoreStyle.Movie
        defeatStyle.SndStart = scoreStyle.SndStart
        defeatStyle.SndStop = scoreStyle.SndStop
        data.RibbonStyle = defeatStyle
        data.VictoryBlurb = Locale.Lookup(GameInfo.Victories[victoryType].Blurb)
    end
    return data
end

local BaseShowEndGame = ShowEndGame

function ShowEndGame(playerID)
    local winningTeam, victoryIndex = Game.GetWinningTeam()
    local victory = victoryIndex and GameInfo.Victories[victoryIndex]
    if victory and victory.VictoryType == VICTORY_TYPE and Players[Game.GetLocalPlayer()] then
        View(TeamVictoryData(winningTeam, VICTORY_TYPE))
        return
    end
    BaseShowEndGame(playerID)
end
