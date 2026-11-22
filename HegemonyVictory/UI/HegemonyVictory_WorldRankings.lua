include("WorldRankings_Expansion2")
include("HegemonyVictory_Rules")

local VICTORY_TYPE = "VICTORY_HEGEMONY"
local METRICS = {
    { key = "score", label = "LOC_HEGEMONY_PROGRESS_SCORE", help = "MAXIMUM" },
    { key = "food", label = "LOC_YIELD_FOOD_NAME", help = "SUM" },
    { key = "production", label = "LOC_YIELD_PRODUCTION_NAME", help = "SUM" },
    { key = "science", label = "LOC_YIELD_SCIENCE_NAME", help = "SUM" },
    { key = "culture", label = "LOC_YIELD_CULTURE_NAME", help = "SUM" },
    { key = "faith", label = "LOC_YIELD_FAITH_NAME", help = "SUM" },
    { key = "gold", label = "LOC_HEGEMONY_PROGRESS_NET_GOLD", help = "GOLD" },
    { key = "military", label = "LOC_HEGEMONY_PROGRESS_MILITARY", help = "SUM" },
    { key = "wonders", label = "LOC_HEGEMONY_PROGRESS_WONDERS", help = "WONDERS" },
    { key = "suzerain", label = "LOC_HEGEMONY_PROGRESS_SUZERAIN", help = "SUZERAIN" },
}

local detailRows = InstanceManager:new("GenericInstance", "ButtonBG", Controls.GenericViewStack)
local METRIC_TABLE_TOP = 52
local metricTable
local detailsActive = false

local function GetRankings()
    local rankings = {}
    local snapshot = HegemonyVictory.Capture()
    if not snapshot then
        return rankings
    end

    for _, playerID in ipairs(snapshot.ids) do
        local results = HegemonyVictory.Evaluate(snapshot, playerID)
        local metCount = 0
        for _, metric in ipairs(METRICS) do
            if results[metric.key].met then
                metCount = metCount + 1
            end
        end
        rankings[#rankings + 1] = { playerID = playerID, metCount = metCount, results = results }
    end

    table.sort(rankings, function(a, b)
        if a.metCount == b.metCount then
            return a.playerID < b.playerID
        end
        return a.metCount > b.metCount
    end)
    return rankings
end

local function FormatMetCount(metCount)
    return Locale.Lookup("LOC_HEGEMONY_PROGRESS_MET_COUNT", metCount, #METRICS)
end

local function FormatMetricNumber(value)
    local pattern = value % 1 == 0 and "#,##0" or "#,##0.0"
    return Locale.ToNumber(value, pattern)
end

local function FormatMetric(metric, result)
    local value = FormatMetricNumber(result.value)
    local target = FormatMetricNumber(result.target)
    if result.total ~= nil then
        value = Locale.Lookup("LOC_HEGEMONY_PROGRESS_COUNT", value, FormatMetricNumber(result.total))
        target = "≥ " .. target
    else
        target = "> " .. target
    end

    local status = result.met and "LOC_HEGEMONY_PROGRESS_MET" or "LOC_HEGEMONY_PROGRESS_NOT_MET"

    return {
        label = Locale.Lookup(metric.label),
        value = value,
        target = target,
        status = Locale.Lookup(status),
        met = result.met,
        help = Locale.Lookup("LOC_HEGEMONY_PROGRESS_HELP_" .. metric.help),
    }
end

local function AttachMetricTable(parent, results)
    if metricTable then
        metricTable:ChangeParent(parent)
    else
        metricTable = ContextPtr:LoadNewContext("HegemonyVictory_MetricTable", parent)
        if not metricTable then
            return 54
        end
        metricTable:SetOffsetVal(15, METRIC_TABLE_TOP)
    end

    local metrics = {}
    for index, metric in ipairs(METRICS) do
        metrics[index] = FormatMetric(metric, results[metric.key])
    end
    LuaEvents.HegemonyVictory_RenderMetricTable(metrics)
    metricTable:SetHide(false)
    return METRIC_TABLE_TOP + metricTable:GetSizeY() + 12
end

local function PopulateHegemonyDetails()
    local localPlayerID = Game.GetLocalPlayer()
    if metricTable then
        metricTable:SetHide(true)
    end
    detailRows:ResetInstances()
    for _, entry in ipairs(GetRankings()) do
        local instance = detailRows:GetInstance()
        PopulatePlayerInstanceShared(instance, entry.playerID)
        instance.CivilizationIcon.CivName:SetSizeX(240)

        instance.Details:SetText(FormatMetCount(entry.metCount))
        local rowHeight = 54
        if entry.playerID == localPlayerID then
            rowHeight = AttachMetricTable(instance.ButtonBG, entry.results)
        end
        instance.ButtonBG:SetSizeY(rowHeight)
    end
end

local function ViewHegemony()
    ResetState(ViewHegemony)
    Controls.GenericView:SetHide(false)
    g_GenericIM:ResetInstances()
    g_GenericTeamIM:ResetInstances()

    local victory = GameInfo.Victories[VICTORY_TYPE]
    ChangeActiveHeader("GENERIC", m_GenericHeaderIM, Controls.GenericViewHeader)
    PopulateGenericHeader(RealizeGenericStackSize, victory.Name, nil, victory.Description, victory.Icon)
    PopulateHegemonyDetails()
    RealizeGenericStackSize()
end

local function PopulateHegemonyOverviewPlayer(instance, entry, iconSize)
    local summary = FormatMetCount(entry.metCount)
    PopulateOverallPlayerIconInstance(instance, VICTORY_TYPE, {
        TeamID = Players[entry.playerID]:GetTeam(),
        TeamScore = entry.metCount / #METRICS,
        PlayerData = { [entry.playerID] = { FirstTiebreakSummary = summary, SecondTiebreakSummary = summary } },
    }, iconSize)
end

local IsExpansionCustomVictoryType = IsCustomVictoryType

function IsCustomVictoryType(victoryType)
    if victoryType == VICTORY_TYPE then
        return HegemonyVictory.IsEnabled()
    end
    return IsExpansionCustomVictoryType(victoryType)
end

local PopulateExpansionTabs = PopulateTabs
local AddExpansionTab = AddTab

function AddTab(label, onClickCallback)
    -- The stock tab builder passes the localized victory name for custom victories.
    local victory = GameInfo.Victories[VICTORY_TYPE]
    if victory and label == Locale.Lookup(victory.Name) then
        label = Locale.Lookup("LOC_WORLD_RANKINGS_HEGEMONY_TAB")
    end
    return AddExpansionTab(label, onClickCallback)
end

function PopulateTabs()
    PopulateExpansionTabs()
    if HegemonyVictory.IsEnabled() and #m_ExtraTabs > 0 then
        -- Gathering Storm builds the overflow menu but hides its button.
        CloseExtraTabs()
        Controls.ExpandExtraTabs:SetHide(false)
    end
end

local PopulateExpansionOverallInstance = PopulateOverallInstance

function PopulateOverallInstance(instance, victoryType, typeText)
    if victoryType ~= VICTORY_TYPE then
        PopulateExpansionOverallInstance(instance, victoryType, typeText)
        return
    end

    local victory = GameInfo.Victories[victoryType]
    instance.VictoryLabel:SetText(Locale.ToUpper(Locale.Lookup(victory.Name)))
    instance.VictoryLabelUnderline:SetSizeX(instance.VictoryLabel:GetSizeX() + 90)
    instance.VictoryIcon:SetIcon(victory.Icon, 64)
    instance.VictoryIcon:SetHide(false)
    local color = UI.GetColorValue("White")
    instance.VictoryBanner:SetColor(color)
    instance.VictoryLabelGradient:SetColor(color)

    -- Use the same pool the base overview uses for the smaller civilization icons.
    if not instance.OverallPlayersIM then
        instance.OverallPlayersIM = InstanceManager:new("OverallPlayerInstance", "CivIconBackingFaded", instance.PlayerStack)
    end
    instance.OverallPlayersIM:ResetInstances()

    local rankings = GetRankings()
    local leader = rankings[1]
    instance.TopPlayer:SetHide(leader == nil)
    instance.VictoryPlayer:SetText("")
    if leader then
        local localPlayerID = Game.GetLocalPlayer()
        instance.VictoryLeading:SetText(Locale.Lookup("LOC_HEGEMONY_PROGRESS_HIGHEST", leader.metCount, #METRICS))
        PopulateHegemonyOverviewPlayer(instance, leader, 48)
        for index, entry in ipairs(rankings) do
            if index > 1 then
                PopulateHegemonyOverviewPlayer(instance.OverallPlayersIM:GetInstance(), entry, 36)
            end
            if entry.playerID == localPlayerID then
                instance.VictoryPlayer:SetText(Locale.Lookup("LOC_HEGEMONY_PROGRESS_LOCAL", entry.metCount, #METRICS))
            end
        end
    else
        instance.VictoryLeading:SetText(Locale.Lookup("LOC_WORLD_RANKINGS_VICTORY_DISABLED"))
    end
    instance.PlayerStack:CalculateSize()
    instance.PlayerStack:ReprocessAnchoring()
    instance.ButtonBG:SetSizeY(math.max(130, 101 + instance.PlayerStack:GetSizeY()))
end

local ViewExpansionGeneric = ViewGeneric

function ViewGeneric(victoryType)
    if victoryType == VICTORY_TYPE then
        ViewHegemony()
    else
        ViewExpansionGeneric(victoryType)
    end
end

local ResetExpansionState = ResetState

function ResetState(view)
    if detailsActive and view ~= ViewHegemony then
        detailRows:ResetInstances()
    end
    detailsActive = view == ViewHegemony
    ResetExpansionState(view)
end

local function OnGameCoreEventPublishComplete()
    if detailsActive and not ContextPtr:IsHidden() then
        local scroll = Controls.GenericViewScrollbar:GetScrollValue()
        PopulateHegemonyDetails()
        RealizeGenericStackSize()
        Controls.GenericViewScrollbar:SetScrollValue(scroll)
    end
end

local OnExpansionShutdown = OnShutdown

function OnShutdown()
    Events.GameCoreEventPublishComplete.Remove(OnGameCoreEventPublishComplete)
    OnExpansionShutdown()
end

Events.GameCoreEventPublishComplete.Add(OnGameCoreEventPublishComplete)
