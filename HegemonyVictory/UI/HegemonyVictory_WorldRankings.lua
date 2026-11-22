include("WorldRankings_Expansion2")

local IsExpansionCustomVictoryType = IsCustomVictoryType

function IsCustomVictoryType(victoryType)
    -- Hegemony has its own screen hook and progress panel.
    return victoryType ~= "VICTORY_HEGEMONY" and IsExpansionCustomVictoryType(victoryType)
end
