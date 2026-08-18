include("InstanceManager");

print("[RockBandLens] RockBandBonusOverlay.lua loaded (V-2026-8-16_text_v5)");

local m_BonusIM:table = nil;
local m_ActiveInstances:table = {};
local m_WaitingForWorldView:boolean = false;
local m_CallbacksRegistered:boolean = false;

-- UI.GetColorValueFromHexLiteral uses Civ VI's packed color literal format.
-- +1: light green
-- +2: medium green
-- +3 and above: dark green
local BONUS_COLOR_LIGHT:number  = UI.GetColorValueFromHexLiteral(0xFF8FE29B);
local BONUS_COLOR_MEDIUM:number = UI.GetColorValueFromHexLiteral(0xFF4AB955);
local BONUS_COLOR_DARK:number   = UI.GetColorValueFromHexLiteral(0xFF2F7A23);

-- ===========================================================================
local function GetBonusTextColor(bonus:number)
    if bonus <= 1 then
        return BONUS_COLOR_LIGHT;
    elseif bonus == 2 then
        return BONUS_COLOR_MEDIUM;
    else
        return BONUS_COLOR_DARK;
    end
end

-- ===========================================================================
local function ClearRockBandBonusOverlay()
    if m_BonusIM == nil then
        return;
    end

    for _, instance in ipairs(m_ActiveInstances) do
        instance.Anchor:SetHide(true);
        m_BonusIM:ReleaseInstance(instance);
    end
    m_ActiveInstances = {};
end

-- ===========================================================================
local function AddRockBandBonusOverlay(plotIndex:number, bonus:number)
    if m_BonusIM == nil or plotIndex == nil or bonus == nil or bonus <= 0 then
        return;
    end

    local plot:table = Map.GetPlotByIndex(plotIndex);
    if plot == nil then
        return;
    end

    local instance:table = m_BonusIM:GetInstance();

    local plotX:number, plotY:number = Map.GetPlotLocation(plotIndex);
    local worldX:number, worldY:number, worldZ:number = UI.GridToWorld(plotX, plotY);

    instance.BonusLabel:SetText("+" .. tostring(bonus));
    instance.BonusLabel:SetColor(GetBonusTextColor(bonus));

    -- Slightly above the plot center; keep the text screen-readable while
    -- the anchor follows the plot in world space.
    instance.Anchor:SetWorldPositionVal(worldX, worldY + 15, worldZ);
    instance.Anchor:SetHide(false);

    table.insert(m_ActiveInstances, instance);
end

-- ===========================================================================
local function RegisterCallbacks()
    if m_CallbacksRegistered then
        return;
    end

    LuaEvents.RockBandBonusOverlay_Clear.Add(ClearRockBandBonusOverlay);
    LuaEvents.RockBandBonusOverlay_Add.Add(AddRockBandBonusOverlay);
    m_CallbacksRegistered = true;
end

-- ===========================================================================
local function OnInit(bIsReload:boolean)
    local worldView:table = ContextPtr:LookUpControl("/InGame/WorldViewControls");
    if worldView == nil then
        if not m_WaitingForWorldView then
            Events.LoadScreenClose.Add(OnInit);
            m_WaitingForWorldView = true;
        end
        return;
    end

    if m_WaitingForWorldView then
        Events.LoadScreenClose.Remove(OnInit);
        m_WaitingForWorldView = false;
    end

    m_BonusIM =
        InstanceManager:new("RockBandBonusInstance", "Anchor", Controls.RockBandBonusContainer);

    ContextPtr:ChangeParent(worldView);
    ContextPtr:SetHide(false);

    RegisterCallbacks();

    print("[RockBandLens] text-v5 READY");
end

-- ===========================================================================
local function OnShutdown()
    if m_WaitingForWorldView then
        Events.LoadScreenClose.Remove(OnInit);
        m_WaitingForWorldView = false;
    end

    if m_CallbacksRegistered then
        LuaEvents.RockBandBonusOverlay_Clear.Remove(ClearRockBandBonusOverlay);
        LuaEvents.RockBandBonusOverlay_Add.Remove(AddRockBandBonusOverlay);
        m_CallbacksRegistered = false;
    end
end

-- ===========================================================================
local function Initialize()
    ContextPtr:SetInitHandler(OnInit);
    ContextPtr:SetShutdown(OnShutdown);
    ContextPtr:SetHide(false);
end

Initialize();
