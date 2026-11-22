include("PartialScreenHooks_Expansion2")
include("HegemonyVictory_Rules")

local AddExpansionScreenHooks = AddScreenHooks

function AddScreenHooks()
    AddExpansionScreenHooks()
    if HegemonyVictory.IsEnabled() then
        local _, _, texture = IconManager:FindIconAtlas("ICON_VICTORY_HEGEMONY", 26)
        AddScreenHook("HegemonyVictory_Progress", texture or "LaunchBar_Hook_WorldRankings", "LOC_VICTORY_HEGEMONY_NAME", function()
            LuaEvents.HegemonyVictory_ToggleProgress()
        end)
    end
end
