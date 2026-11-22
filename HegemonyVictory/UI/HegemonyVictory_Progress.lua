include("HegemonyVictory_Rules")
include("InstanceManager")

local MET_COLOR = UI.GetColorValueFromHexLiteral(0xFFB1E5AA)
local UNMET_COLOR = UI.GetColorValueFromHexLiteral(0xFFD4C2B6)
local ALTERNATE_ROW_COLOR = UI.GetColorValueFromHexLiteral(0xDC584235)

local METRICS = {
    { key = "score", label = "LOC_HEGEMONY_PROGRESS_SCORE", help = "MAXIMUM" },
    { key = "food", label = "LOC_YIELD_FOOD_NAME", help = "MAXIMUM" },
    { key = "production", label = "LOC_YIELD_PRODUCTION_NAME", help = "MAXIMUM" },
    { key = "science", label = "LOC_YIELD_SCIENCE_NAME", help = "SUM" },
    { key = "culture", label = "LOC_YIELD_CULTURE_NAME", help = "SUM" },
    { key = "faith", label = "LOC_YIELD_FAITH_NAME", help = "SUM" },
    { key = "gold", label = "LOC_HEGEMONY_PROGRESS_NET_GOLD", help = "GOLD" },
    { key = "military", label = "LOC_HEGEMONY_PROGRESS_MILITARY", help = "SUM" },
    { key = "wonders", label = "LOC_HEGEMONY_PROGRESS_WONDERS", help = "WONDERS" },
    { key = "suzerain", label = "LOC_HEGEMONY_PROGRESS_SUZERAIN", help = "SUZERAIN" }
}

local rowManager = InstanceManager:new("HegemonyMetricRow", "Row", Controls.MetricRows)
local rows = {}

local function Close()
    ContextPtr:SetHide(true)
end

local function FormatNumber(value)
    return Locale.ToNumber(value, "#,##0.######")
end

local function DisplayMetric(row, metric)
    local value = FormatNumber(metric.value)
    local target = "> " .. FormatNumber(metric.target)
    if metric.total ~= nil then
        value = Locale.Lookup("LOC_HEGEMONY_PROGRESS_COUNT", value, FormatNumber(metric.total))
        target = "≥ " .. FormatNumber(metric.target)
    end

    local status = "LOC_HEGEMONY_PROGRESS_NOT_MET"
    if metric.automatic then
        status = "LOC_HEGEMONY_PROGRESS_AUTOMATIC"
    elseif metric.met then
        status = "LOC_HEGEMONY_PROGRESS_MET"
    end

    row.Value:SetText(value)
    row.Target:SetText(target)
    row.Status:SetText(Locale.Lookup(status))
    row.Status:SetColor(metric.met and MET_COLOR or UNMET_COLOR)
end

local function Refresh()
    local playerID = Game.GetLocalPlayer()
    local player = Players[playerID]
    if not player or not player:IsMajor() or not player:IsAlive() then
        Close()
        return false
    end

    local snapshot = HegemonyVictory.Capture()
    local result = snapshot and HegemonyVictory.Evaluate(snapshot, playerID)
    if not result then
        Close()
        return false
    end

    Controls.CivilizationName:SetText(Locale.Lookup(PlayerConfigurations[playerID]:GetCivilizationDescription()))
    for index, metric in ipairs(METRICS) do
        DisplayMetric(rows[index], result[metric.key])
    end
    return true
end

local function Toggle()
    if not ContextPtr:IsHidden() then
        Close()
    elseif HegemonyVictory.IsEnabled() and Refresh() then
        LuaEvents.PartialScreenHooks_CloseAllExcept(ContextPtr:GetID())
        ContextPtr:SetHide(false)
    end
end

local function OnCloseAllExcept(contextID)
    if contextID ~= ContextPtr:GetID() then
        Close()
    end
end

local function OnGameCoreEventPublishComplete()
    if not ContextPtr:IsHidden() then
        Refresh()
    end
end

local function OnInput(input)
    if not ContextPtr:IsHidden() and input:GetMessageType() == KeyEvents.KeyUp and input:GetKey() == Keys.VK_ESCAPE then
        Close()
        return true
    end
    return false
end

local function Initialize()
    Close()
    Controls.VictoryIcon:SetIcon("ICON_VICTORY_HEGEMONY")
    for index, metric in ipairs(METRICS) do
        local row = rowManager:GetInstance()
        row.Metric:SetText(Locale.Lookup(metric.label))
        row.Row:SetToolTipString(Locale.Lookup("LOC_HEGEMONY_PROGRESS_HELP_" .. metric.help))
        if index % 2 == 0 then
            row.Row:SetColor(ALTERNATE_ROW_COLOR)
        end
        rows[index] = row
    end
    Controls.MetricRows:CalculateSize()
    Controls.MetricRows:ReprocessAnchoring()
    Controls.CloseButton:RegisterCallback(Mouse.eLClick, Close)
end

ContextPtr:SetInitHandler(Initialize)
ContextPtr:SetInputHandler(OnInput, true)
LuaEvents.HegemonyVictory_ToggleProgress.Add(Toggle)
LuaEvents.PartialScreenHooks_CloseAllExcept.Add(OnCloseAllExcept)
LuaEvents.EndGameMenu_Shown.Add(Close)
Events.LocalPlayerChanged.Add(Close)
Events.GameCoreEventPublishComplete.Add(OnGameCoreEventPublishComplete)

ContextPtr:SetShutdown(function()
    LuaEvents.HegemonyVictory_ToggleProgress.Remove(Toggle)
    LuaEvents.PartialScreenHooks_CloseAllExcept.Remove(OnCloseAllExcept)
    LuaEvents.EndGameMenu_Shown.Remove(Close)
    Events.LocalPlayerChanged.Remove(Close)
    Events.GameCoreEventPublishComplete.Remove(OnGameCoreEventPublishComplete)
end)
