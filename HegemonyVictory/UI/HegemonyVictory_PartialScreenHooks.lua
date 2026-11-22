include("PartialScreenHooks_Expansion2")
include("HegemonyVictory_Rules")

local AddExpansionScreenHooks = AddScreenHooks

function AddScreenHooks()
    AddExpansionScreenHooks()
    if HegemonyVictory.IsEnabled() then
        AddScreenHook("HegemonyVictory_Progress", "HegemonyVictory26.dds", "LOC_VICTORY_HEGEMONY_NAME", function()
            LuaEvents.HegemonyVictory_ToggleProgress()
        end)
    end
end
