local MOD_NAME = "PeoplesWar"

local COMBAT_MAX = 100
local CITY_POPULATION_EFFECT_LEVELS = 20
local CITY_POPULATION_EFFECT_STEP = 5

local PROPERTY_COMBAT_LEVEL = "PEOPLES_WAR_COMBAT_LEVEL"
local PROPERTY_COMBAT_CAP_WARNING = "PEOPLES_WAR_COMBAT_CAP_WARNING"
local PROPERTY_POPULATION_MODIFIER_ATTACHED = "PEOPLES_WAR_POPULATION_MODIFIER_ATTACHED"
local PROPERTY_CITY_MODIFIERS_ATTACHED = "PEOPLES_WAR_CITY_MODIFIERS_ATTACHED"

local m_updating = {}
local m_updateRequested = {}

local function Log(message)
    print(MOD_NAME .. ": " .. message)
end

local function GetNumberProperty(holder, propertyName, fallback)
    -- Unset game properties may return no value at all, so convert only after a safe read.
    local value = holder:GetProperty(propertyName)
    local number = tonumber(value)
    if number == nil then
        return fallback
    end
    return number
end

local function IsTargetPlayer(player)
    return player ~= nil and player:IsHuman() and player:IsMajor()
end

local function GetTotalPopulation(player)
    local population = 0

    for _, city in player:GetCities():Members() do
        population = population + city:GetPopulation()
    end

    return population
end

local function GetCappedLevel(player, population, divisor, maximum, warningProperty, label)
    local rawLevel = math.ceil(population / divisor)
    local level = math.min(rawLevel, maximum)

    if rawLevel > maximum and player:GetProperty(warningProperty) ~= 1 then
        player:SetProperty(warningProperty, 1)
        Log(label .. " level capped at " .. tostring(maximum) .. " for player " .. tostring(player:GetID()))
    end

    return level
end

local function IsReligiousUnit(unit)
    local unitInfo = GameInfo.Units[unit:GetType()]
    return unitInfo ~= nil and (tonumber(unitInfo.ReligiousStrength) or 0) > 0
end

local function IsCombatUnit(unit)
    local unitInfo = GameInfo.Units[unit:GetType()]
    if unitInfo == nil or IsReligiousUnit(unit) then
        return false
    end

    return (tonumber(unitInfo.Combat) or 0) > 0
        or (tonumber(unitInfo.RangedCombat) or 0) > 0
        or (tonumber(unitInfo.Bombard) or 0) > 0
        or (tonumber(unitInfo.AntiAirCombat) or 0) > 0
end

local function SetAbilityCount(unit, abilityType, desiredCount)
    if abilityType == nil or GameInfo.UnitAbilities[abilityType] == nil then
        if abilityType ~= nil then
            Log("Unit ability not found: " .. abilityType)
        end
        return
    end

    local abilities = unit:GetAbility()
    if abilities == nil then
        return
    end

    local currentCount = abilities:GetAbilityCount(abilityType)
    if currentCount ~= desiredCount then
        abilities:ChangeAbilityCount(abilityType, desiredCount - currentCount)
    end
end

local function ApplyUnitLevel(unit, oldLevel, newLevel)
    local category = nil

    if IsReligiousUnit(unit) then
        category = "RELIGIOUS"
    elseif IsCombatUnit(unit) then
        category = "COMBAT"
    else
        return
    end

    if oldLevel ~= nil and oldLevel > 0 then
        SetAbilityCount(unit, "ABILITY_PEOPLES_WAR_" .. category .. "_" .. tostring(oldLevel), 0)
    end

    if newLevel > 0 then
        SetAbilityCount(unit, "ABILITY_PEOPLES_WAR_" .. category .. "_" .. tostring(newLevel), 1)
    end
end

local function ApplyLevelToAllUnits(player, oldLevel, newLevel)
    for _, unit in player:GetUnits():Members() do
        ApplyUnitLevel(unit, oldLevel, newLevel)
    end
end

local function AttachPlayerModifiers(player)
    -- Persist attachment flags because reattaching the same modifier would stack its effects.
    if player:GetProperty(PROPERTY_POPULATION_MODIFIER_ATTACHED) ~= 1 then
        player:AttachModifierByID("PEOPLES_WAR_NO_POPULATION_LOSS_AFTER_CONQUEST")
        player:SetProperty(PROPERTY_POPULATION_MODIFIER_ATTACHED, 1)
    end

    if player:GetProperty(PROPERTY_CITY_MODIFIERS_ATTACHED) ~= 1 then
        -- Database requirements recalculate these city effects as each city's population changes.
        for level = 1, CITY_POPULATION_EFFECT_LEVELS do
            local threshold = 1 + ((level - 1) * CITY_POPULATION_EFFECT_STEP)
            local suffix = string.format("%03d", threshold)
            player:AttachModifierByID("PEOPLES_WAR_CITY_RANGED_POP_" .. suffix)
            player:AttachModifierByID("PEOPLES_WAR_CITY_DEFENSE_POP_" .. suffix)
            player:AttachModifierByID("PEOPLES_WAR_CITY_SPY_DEFENSE_POP_" .. suffix)
        end

        player:SetProperty(PROPERTY_CITY_MODIFIERS_ATTACHED, 1)
    end
end

local function UpdatePlayerNow(playerID, forceUnits)
    local player = Players[playerID]
    if not IsTargetPlayer(player) then
        return
    end

    AttachPlayerModifiers(player)

    local population = GetTotalPopulation(player)
    local combatLevel = GetCappedLevel(
        player,
        population,
        10,
        COMBAT_MAX,
        PROPERTY_COMBAT_CAP_WARNING,
        "Combat"
    )
    local oldCombatLevel = GetNumberProperty(player, PROPERTY_COMBAT_LEVEL, nil)

    if forceUnits or oldCombatLevel ~= combatLevel then
        ApplyLevelToAllUnits(player, oldCombatLevel, combatLevel)
        player:SetProperty(PROPERTY_COMBAT_LEVEL, combatLevel)
    end
end

local function RequestPlayerUpdate(playerID, forceUnits)
    -- Population and unit events can fire during an update; coalesce them instead of re-entering.
    if m_updating[playerID] then
        m_updateRequested[playerID] = true
        return
    end

    m_updating[playerID] = true
    local shouldForce = forceUnits == true

    repeat
        m_updateRequested[playerID] = false
        UpdatePlayerNow(playerID, shouldForce)
        shouldForce = false
    until not m_updateRequested[playerID]

    m_updating[playerID] = nil
end

local function OnCityConquered(capturerID)
    -- Conquest changes total empire population; refresh the population bonuses only.
    RequestPlayerUpdate(capturerID, false)
end

local function OnCityPopulationChanged(playerID)
    RequestPlayerUpdate(playerID, false)
end

local function OnCityChanged(playerID)
    RequestPlayerUpdate(playerID, false)
end

local function OnUnitCreated(playerID, unitID)
    local player = Players[playerID]
    if not IsTargetPlayer(player) then
        return
    end

    local unit = UnitManager.GetUnit(playerID, unitID)
    if unit == nil then
        return
    end

    local level = GetNumberProperty(player, PROPERTY_COMBAT_LEVEL, 0)
    ApplyUnitLevel(unit, nil, level)
end

local function OnPlayerTurnStarted(playerID)
    local player = Players[playerID]
    if not IsTargetPlayer(player) then
        return
    end

    RequestPlayerUpdate(playerID, false)
end

local function Initialize()
    for _, player in ipairs(PlayerManager.GetAliveMajors()) do
        if IsTargetPlayer(player) then
            RequestPlayerUpdate(player:GetID(), true)
        end
    end

    GameEvents.PlayerTurnStarted.Add(OnPlayerTurnStarted)
    GameEvents.CityConquered.Add(OnCityConquered)
    GameEvents.OnCityPopulationChanged.Add(OnCityPopulationChanged)
    GameEvents.UnitInitialized.Add(OnUnitCreated)
    GameEvents.UnitCreated.Add(OnUnitCreated)

    if GameEvents.CityBuilt ~= nil then
        GameEvents.CityBuilt.Add(OnCityChanged)
    end
    if Events ~= nil and Events.CityAddedToMap ~= nil then
        Events.CityAddedToMap.Add(OnCityChanged)
    end
    if Events ~= nil and Events.UnitAddedToMap ~= nil then
        Events.UnitAddedToMap.Add(OnUnitCreated)
    end
    if Events ~= nil and Events.UnitUpgraded ~= nil then
        Events.UnitUpgraded.Add(OnUnitCreated)
    end

    Log("Loaded.")
end

Initialize()
