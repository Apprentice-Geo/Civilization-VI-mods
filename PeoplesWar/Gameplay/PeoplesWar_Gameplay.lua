local MOD_NAME = "PeoplesWar"

local COMBAT_MAX = 100
local CITY_POPULATION_EFFECT_LEVELS = 10
local DISSOLVE_READY_PLOT_PROPERTY = "PEOPLES_WAR_DISSOLVE_READY"
local DISSOLVE_COMMITTED_PLOT_PROPERTY = "PEOPLES_WAR_DISSOLVE_COMMITTED"
local PLOT_SET_ENCODING_PREFIX = "plots:"

local PROPERTY_COMBAT_LEVEL = "PEOPLES_WAR_COMBAT_LEVEL"
local PROPERTY_COMBAT_CAP_WARNING = "PEOPLES_WAR_COMBAT_CAP_WARNING"
local PROPERTY_POPULATION_MODIFIER_ATTACHED = "PEOPLES_WAR_POPULATION_MODIFIER_ATTACHED"
local PROPERTY_CITY_MODIFIERS_ATTACHED = "PEOPLES_WAR_V2_CITY_MODIFIERS_ATTACHED"
local PROPERTY_PENDING_PLOTS = "PEOPLES_WAR_PENDING_CITY_PLOTS"

local PROPERTY_TX_ID = "PEOPLES_WAR_DISSOLVE_TX_ID"
local PROPERTY_TX_CITY_ID = "PEOPLES_WAR_DISSOLVE_TX_CITY_ID"
local PROPERTY_TX_TARGET_PLOT = "PEOPLES_WAR_DISSOLVE_TX_TARGET_PLOT"
local PROPERTY_TX_POPULATION = "PEOPLES_WAR_DISSOLVE_TX_POPULATION"
local PROPERTY_TX_RECIPIENTS = "PEOPLES_WAR_DISSOLVE_TX_RECIPIENTS"
local PROPERTY_TX_TURN = "PEOPLES_WAR_DISSOLVE_TX_TURN"

local m_updating = {}
local m_updateRequested = {}
local m_batching = {}
local CommitDissolve

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

local function DecodePlotSet(value)
    local result = {}

    if type(value) ~= "string" and type(value) ~= "number" then
        return result
    end

    -- Legacy one-item sets can round-trip through game properties as numbers.
    for token in string.gmatch(tostring(value), "%d+") do
        result[tonumber(token)] = true
    end

    return result
end

local function EncodePlotSet(set)
    local values = {}

    for plotIndex, included in pairs(set) do
        if included then
            table.insert(values, plotIndex)
        end
    end

    table.sort(values)

    local encoded = {}
    for _, plotIndex in ipairs(values) do
        table.insert(encoded, tostring(plotIndex))
    end

    -- Keep one-item sets unambiguously string-typed across property persistence.
    return PLOT_SET_ENCODING_PREFIX .. table.concat(encoded, ",")
end

local function GetCityAtPlotIndex(plotIndex)
    if type(plotIndex) ~= "number" then
        return nil
    end

    local plot = Map.GetPlotByIndex(plotIndex)
    if plot == nil then
        return nil
    end

    return CityManager.GetCityAt(plot:GetX(), plot:GetY())
end

local function GetCityPlotIndex(city)
    return Map.GetPlotIndex(city:GetX(), city:GetY())
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
            local threshold = 1 + ((level - 1) * 10)
            local suffix = string.format("%03d", threshold)
            player:AttachModifierByID("PEOPLES_WAR_CITY_RANGED_POP_" .. suffix)
            player:AttachModifierByID("PEOPLES_WAR_CITY_DEFENSE_POP_" .. suffix)
            player:AttachModifierByID("PEOPLES_WAR_CITY_SPY_DEFENSE_POP_" .. suffix)
        end

        for _, yieldType in ipairs({ "GOLD", "PRODUCTION", "FAITH", "SCIENCE", "CULTURE" }) do
            player:AttachModifierByID("PEOPLES_WAR_CITY_POPULATION_" .. yieldType)
        end

        player:SetProperty(PROPERTY_CITY_MODIFIERS_ATTACHED, 1)
    end
end

local function CleanPendingPlots(player)
    local pending = DecodePlotSet(player:GetProperty(PROPERTY_PENDING_PLOTS))
    local changed = false

    for plotIndex in pairs(pending) do
        local city = GetCityAtPlotIndex(plotIndex)
        if city == nil or city:GetOwner() ~= player:GetID() then
            pending[plotIndex] = nil
            changed = true
        end
    end

    if changed then
        player:SetProperty(PROPERTY_PENDING_PLOTS, EncodePlotSet(pending))
    end

    return pending
end

local function UpdatePlayerNow(playerID, forceUnits)
    local player = Players[playerID]
    if not IsTargetPlayer(player) then
        return
    end

    AttachPlayerModifiers(player)
    CleanPendingPlots(player)

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
    if m_batching[playerID] then
        m_updateRequested[playerID] = true
        return
    end

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

local function AddPendingCity(player, plotIndex)
    local pending = DecodePlotSet(player:GetProperty(PROPERTY_PENDING_PLOTS))
    if not pending[plotIndex] then
        pending[plotIndex] = true
        player:SetProperty(PROPERTY_PENDING_PLOTS, EncodePlotSet(pending))
    end
end

local function RemovePendingCity(player, plotIndex)
    local pending = DecodePlotSet(player:GetProperty(PROPERTY_PENDING_PLOTS))
    if pending[plotIndex] then
        pending[plotIndex] = nil
        player:SetProperty(PROPERTY_PENDING_PLOTS, EncodePlotSet(pending))
    end
end

local function ClearTransaction(player)
    local targetPlot = GetNumberProperty(player, PROPERTY_TX_TARGET_PLOT, nil)
    if targetPlot ~= nil then
        local plot = Map.GetPlotByIndex(targetPlot)
        if plot ~= nil then
            plot:SetProperty(DISSOLVE_READY_PLOT_PROPERTY, nil)
        end
    end

    player:SetProperty(PROPERTY_TX_ID, nil)
    player:SetProperty(PROPERTY_TX_CITY_ID, nil)
    player:SetProperty(PROPERTY_TX_TARGET_PLOT, nil)
    player:SetProperty(PROPERTY_TX_POPULATION, nil)
    player:SetProperty(PROPERTY_TX_RECIPIENTS, nil)
    player:SetProperty(PROPERTY_TX_TURN, nil)
end

local function PrepareDissolve(playerID, parameters)
    local player = Players[playerID]
    if not IsTargetPlayer(player) then
        return
    end

    local plotIndex = tonumber(parameters.PlotIndex)
    local transactionID = tostring(parameters.TransactionID or "")
    local city = GetCityAtPlotIndex(plotIndex)
    local pending = CleanPendingPlots(player)

    if transactionID == "" then
        Log("Rejected PREPARE_DISSOLVE without a transaction ID for player " .. tostring(playerID))
        return
    end
    if city == nil or city:GetOwner() ~= playerID then
        Log("Rejected PREPARE_DISSOLVE for an invalid target city for player " .. tostring(playerID))
        return
    end
    if not pending[plotIndex] then
        -- Gameplay cannot use UI-only captured-city iterators; ownership and this request
        -- recover state lost to event ordering, while later transaction checks remain authoritative.
        AddPendingCity(player, plotIndex)
        pending[plotIndex] = true
        Log("Recovered missing pending city state from dissolve request for player " .. tostring(playerID))
    end

    -- Freeze the eligible recipient set now so the commit can reject any intervening state change.
    local recipients = {}
    for _, candidate in player:GetCities():Members() do
        local candidatePlot = GetCityPlotIndex(candidate)
        if candidatePlot ~= plotIndex and not pending[candidatePlot] then
            recipients[candidatePlot] = true
        end
    end

    if next(recipients) == nil then
        Log("Rejected PREPARE_DISSOLVE without eligible recipients for player " .. tostring(playerID))
        return
    end

    ClearTransaction(player)
    player:SetProperty(PROPERTY_TX_ID, transactionID)
    player:SetProperty(PROPERTY_TX_CITY_ID, city:GetID())
    player:SetProperty(PROPERTY_TX_TARGET_PLOT, plotIndex)
    player:SetProperty(PROPERTY_TX_POPULATION, city:GetPopulation())
    player:SetProperty(PROPERTY_TX_RECIPIENTS, EncodePlotSet(recipients))
    player:SetProperty(PROPERTY_TX_TURN, Game.GetCurrentGameTurn())
    local targetPlot = Map.GetPlotByIndex(plotIndex)
    if targetPlot ~= nil then
        targetPlot:SetProperty(DISSOLVE_READY_PLOT_PROPERTY, transactionID)
        Log("Prepared dissolve transaction " .. transactionID .. " for player " .. tostring(playerID))
    else
        Log("Rejected PREPARE_DISSOLVE because the target plot is unavailable for player " .. tostring(playerID))
        ClearTransaction(player)
    end
end

local function ResolveCapture(playerID, parameters)
    local player = Players[playerID]
    if not IsTargetPlayer(player) then
        return
    end

    local plotIndex = tonumber(parameters.PlotIndex)
    local action = tostring(parameters.CaptureAction or "")
    local pending = CleanPendingPlots(player)
    if not pending[plotIndex] then
        return
    end

    local city = GetCityAtPlotIndex(plotIndex)
    local resolved = action == "KEEP" and city ~= nil and city:GetOwner() == playerID

    if action == "LIBERATE_FOUNDER" or action == "LIBERATE_PREVIOUS_OWNER" then
        resolved = city == nil or city:GetOwner() ~= playerID
    end

    if resolved then
        RemovePendingCity(player, plotIndex)
        RequestPlayerUpdate(playerID, false)
    else
        Log("RESOLVE_CAPTURE did not match final city state for player " .. tostring(playerID))
    end
end

local function OnCityOperation(playerID, parameters)
    if type(parameters) ~= "table" then
        return
    end

    local operation = tostring(parameters.Operation or "")
    if operation == "PREPARE_DISSOLVE" then
        PrepareDissolve(playerID, parameters)
    elseif operation == "RESOLVE_CAPTURE" then
        ResolveCapture(playerID, parameters)
    elseif operation == "COMMIT_DISSOLVE" then
        CommitDissolve(
            playerID,
            tonumber(parameters.CityID),
            tostring(parameters.TransactionID or ""),
            tonumber(parameters.RemovalConfirmed) == 1
        )
    else
        Log("Rejected unknown city operation: " .. operation)
    end
end

local function OnCityConquered(capturerID, ownerID, cityID, cityX, cityY)
    local player = Players[capturerID]
    if not IsTargetPlayer(player) then
        return
    end

    -- Update first: cleanup inside the update must not discard the newly captured pending city.
    RequestPlayerUpdate(capturerID, false)
    AddPendingCity(player, Map.GetPlotIndex(cityX, cityY))
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

local function ValidateRecipientCities(player, recipientSet)
    local recipients = {}
    local pending = CleanPendingPlots(player)

    for plotIndex in pairs(recipientSet) do
        local city = GetCityAtPlotIndex(plotIndex)
        if city == nil or city:GetOwner() ~= player:GetID() or pending[plotIndex] then
            return nil
        end
        table.insert(recipients, city)
    end

    -- This order determines remainder recipients: least populous first, then plot index.
    table.sort(recipients, function(left, right)
        local leftPopulation = left:GetPopulation()
        local rightPopulation = right:GetPopulation()
        if leftPopulation ~= rightPopulation then
            return leftPopulation < rightPopulation
        end
        return GetCityPlotIndex(left) < GetCityPlotIndex(right)
    end)
    return recipients
end

CommitDissolve = function(playerID, cityID, requestedTransactionID, removalConfirmed)
    local player = Players[playerID]
    if not IsTargetPlayer(player) then
        return false
    end

    local transactionID = player:GetProperty(PROPERTY_TX_ID)
    local transactionCityID = GetNumberProperty(player, PROPERTY_TX_CITY_ID, nil)
    if transactionID == nil or transactionCityID ~= cityID then
        return false
    end
    if requestedTransactionID ~= nil
        and requestedTransactionID ~= ""
        and tostring(transactionID) ~= requestedTransactionID then
        return false
    end

    local targetPlot = GetNumberProperty(player, PROPERTY_TX_TARGET_PLOT, nil)
    local population = GetNumberProperty(player, PROPERTY_TX_POPULATION, 0)
    local recipientSet = DecodePlotSet(player:GetProperty(PROPERTY_TX_RECIPIENTS))
    local recipients = ValidateRecipientCities(player, recipientSet)
    -- CityRemovedFromMap is authoritative even when the city lookup has not cleared yet.
    local targetStillExists = removalConfirmed ~= true and GetCityAtPlotIndex(targetPlot) ~= nil

    if targetStillExists or recipients == nil or #recipients == 0 then
        local reason = "target city still exists"
        if recipients == nil then
            reason = "recipient city state changed"
        elseif #recipients == 0 then
            reason = "no eligible recipients remain"
        end
        Log("Cancelled invalid dissolve transaction for player " .. tostring(playerID) .. ": " .. reason)
        ClearTransaction(player)
        RequestPlayerUpdate(playerID, false)
        return false
    end

    -- Clear transaction state before population events fire so the commit cannot repeat.
    ClearTransaction(player)
    RemovePendingCity(player, targetPlot)

    local share = math.floor(population / #recipients)
    local remainder = population - share * #recipients
    -- Batch population callbacks and perform one ability refresh after all shares are applied.
    m_batching[playerID] = true
    for _, city in ipairs(recipients) do
        if share > 0 then
            city:ChangePopulation(share)
        end
    end
    for index = 1, remainder do
        recipients[index]:ChangePopulation(1)
    end
    m_batching[playerID] = nil
    m_updateRequested[playerID] = nil
    RequestPlayerUpdate(playerID, false)

    Log("Committed dissolve transaction " .. tostring(transactionID) .. " for player " .. tostring(playerID))
    local dissolvedPlot = Map.GetPlotByIndex(targetPlot)
    if dissolvedPlot ~= nil then
        dissolvedPlot:SetProperty(DISSOLVE_COMMITTED_PLOT_PROPERTY, tostring(transactionID))
    end
    return true
end


local function OnCityRemovedFromMap(playerID, cityID)
    if CommitDissolve(playerID, cityID, nil, true) then
        return
    end

    RequestPlayerUpdate(playerID, false)
end

local function OnPlayerTurnStarted(playerID)
    local player = Players[playerID]
    if not IsTargetPlayer(player) then
        return
    end

    if player:GetProperty(PROPERTY_TX_ID) ~= nil then
        -- A dissolve must finish in its originating turn; stale transactions cannot commit later.
        Log("Cleared expired dissolve transaction for player " .. tostring(playerID))
        ClearTransaction(player)
    end

    RequestPlayerUpdate(playerID, false)
end

local function Initialize()
    for _, player in ipairs(PlayerManager.GetAliveMajors()) do
        if IsTargetPlayer(player) then
            RequestPlayerUpdate(player:GetID(), true)
        end
    end

    GameEvents.PeoplesWar_CityOperation.Add(OnCityOperation)
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
    if Events ~= nil and Events.CityRemovedFromMap ~= nil then
        Events.CityRemovedFromMap.Add(OnCityRemovedFromMap)
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
