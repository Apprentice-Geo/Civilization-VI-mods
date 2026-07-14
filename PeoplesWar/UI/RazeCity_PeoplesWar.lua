-- Gathering Storm capture chooser with a separate People's War dissolve action.
include("RazeCity")

local PROPERTY_PENDING_PLOTS = "PEOPLES_WAR_PENDING_CITY_PLOTS"
local DISSOLVE_READY_PLOT_PROPERTY = "PEOPLES_WAR_DISSOLVE_READY"
local DISSOLVE_COMMITTED_PLOT_PROPERTY = "PEOPLES_WAR_DISSOLVE_COMMITTED"
local SCRIPT_EVENT = "PeoplesWar_CityOperation"
local m_transactionCounter = 0
local m_pendingDissolveTransaction = nil

local BaseLateInitialize = LateInitialize

local function Log(message)
    print("PeoplesWar UI: " .. message)
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

local function GetCityPlotIndex(city)
    return Map.GetPlotIndex(city:GetX(), city:GetY())
end

local function GetPlotPropertyString(plot, propertyName)
    -- Avoid tostring on an unset game property; the API may return no value at all.
    local value = plot:GetProperty(propertyName)
    return value ~= nil and tostring(value) or ""
end

local function RequestGameplayOperation(operation, plotIndex, extra)
    local parameters = extra or {}
    parameters.OnStart = SCRIPT_EVENT
    parameters.Operation = operation
    parameters.PlotIndex = plotIndex
    UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.EXECUTE_SCRIPT, parameters)
end

local function RequestResolveCapture(action, plotIndex)
    RequestGameplayOperation("RESOLVE_CAPTURE", plotIndex, { CaptureAction = action })
end

local function GetDissolveDisabledReason()
    local playerID = Game.GetLocalPlayer()
    local player = Players[playerID]
    if player == nil or g_pSelectedCity == nil or g_pSelectedCity:GetOwner() ~= playerID then
        return "LOC_PEOPLES_WAR_DISSOLVE_COMMAND_BLOCKED"
    end

    -- The capture popup can open before the current pending plot reaches the UI context.
    -- Gameplay validates the target authoritatively when PREPARE_DISSOLVE runs.
    local pending = DecodePlotSet(player:GetProperty(PROPERTY_PENDING_PLOTS))
    local targetPlot = GetCityPlotIndex(g_pSelectedCity)

    local recipientCount = 0
    for _, city in player:GetCities():Members() do
        local plotIndex = GetCityPlotIndex(city)
        if plotIndex ~= targetPlot and not pending[plotIndex] then
            recipientCount = recipientCount + 1
        end
    end

    if recipientCount == 0 then
        return "LOC_PEOPLES_WAR_DISSOLVE_NO_RECIPIENTS"
    end

    if not g_pSelectedCity:CanRaze() then
        return "LOC_PEOPLES_WAR_DISSOLVE_COMMAND_BLOCKED"
    end

    return nil
end

function OnButton1()
    local parameters = {}
    parameters[UnitOperationTypes.PARAM_FLAGS] = CityDestroyDirectives.LIBERATE_FOUNDER
    if CityManager.CanStartCommand(g_pSelectedCity, CityCommandTypes.DESTROY, parameters) then
        local plotIndex = GetCityPlotIndex(g_pSelectedCity)
        UI.DeselectAllCities()
        CityManager.RequestCommand(g_pSelectedCity, CityCommandTypes.DESTROY, parameters)
        RequestResolveCapture("LIBERATE_FOUNDER", plotIndex)
    end
    Close()
end

function OnButton2()
    local parameters = {}
    parameters[UnitOperationTypes.PARAM_FLAGS] = CityDestroyDirectives.LIBERATE_PREVIOUS_OWNER
    if CityManager.CanStartCommand(g_pSelectedCity, CityCommandTypes.DESTROY, parameters) then
        local plotIndex = GetCityPlotIndex(g_pSelectedCity)
        UI.DeselectAllCities()
        CityManager.RequestCommand(g_pSelectedCity, CityCommandTypes.DESTROY, parameters)
        RequestResolveCapture("LIBERATE_PREVIOUS_OWNER", plotIndex)
    end
    Close()
end

function OnButton3()
    local parameters = {}
    parameters[UnitOperationTypes.PARAM_FLAGS] = CityDestroyDirectives.KEEP
    if CityManager.CanStartCommand(g_pSelectedCity, CityCommandTypes.DESTROY, parameters) then
        local plotIndex = GetCityPlotIndex(g_pSelectedCity)
        CityManager.RequestCommand(g_pSelectedCity, CityCommandTypes.DESTROY, parameters)
        RequestResolveCapture("KEEP", plotIndex)
    end
    Close()
end

-- Keep the original RazeCity action separate from the People's War transaction.
function OnButton4()
    local parameters = {}
    parameters[UnitOperationTypes.PARAM_FLAGS] = CityDestroyDirectives.RAZE
    if CityManager.CanStartCommand(g_pSelectedCity, CityCommandTypes.DESTROY, parameters) then
        UI.DeselectAllCities()
        CityManager.RequestCommand(g_pSelectedCity, CityCommandTypes.DESTROY, parameters)
        UI.PlaySound("RAZE_CITY")
    end
    Close()
end

local function OnDissolveButton()
    if GetDissolveDisabledReason() ~= nil then
        return
    end

    local playerID = Game.GetLocalPlayer()
    local plotIndex = GetCityPlotIndex(g_pSelectedCity)
    m_transactionCounter = m_transactionCounter + 1
    local transactionID = table.concat(
        { tostring(playerID), tostring(Game.GetCurrentGameTurn()), tostring(plotIndex), tostring(m_transactionCounter) },
        ":"
    )

    -- Gameplay first validates and snapshots the transaction; its plot property then
    -- returns control to UI for the final CanStartCommand check and destruction request.
    m_pendingDissolveTransaction = { ID = transactionID, PlotIndex = plotIndex }
    RequestGameplayOperation(
        "PREPARE_DISSOLVE",
        plotIndex,
        { TransactionID = transactionID }
    )
    Log("Requested dissolve preparation " .. transactionID)
    Close()
end

-- This keeps the current Expansion 2 choices and adds a separate dissolve button.
function OnOpen()
    local localPlayerID = Game.GetLocalPlayer()
    local localPlayer = Players[localPlayerID]
    if localPlayer == nil then
        return
    end

    g_pSelectedCity = localPlayer:GetCities():GetNextCapturedCity()
    if g_pSelectedCity == nil then
        return
    end

    Controls.PanelHeader:LocalizeAndSetText("LOC_RAZE_CITY_HEADER")
    Controls.CityHeader:LocalizeAndSetText("LOC_RAZE_CITY_NAME_LABEL")
    Controls.CityName:LocalizeAndSetText(g_pSelectedCity:GetName())
    Controls.CityPopulation:LocalizeAndSetText("LOC_RAZE_CITY_POPULATION_LABEL")
    Controls.NumPeople:SetText(tostring(g_pSelectedCity:GetPopulation()))
    Controls.CityDistricts:LocalizeAndSetText("LOC_RAZE_CITY_DISTRICTS_LABEL")
    local iNumDistricts = g_pSelectedCity:GetDistricts():GetNumZonedDistrictsRequiringPopulation()
    Controls.NumDistricts:SetText(tostring(iNumDistricts))

    local szWarmongerString
    local eOriginalOwner = g_pSelectedCity:GetOriginalOwner()
    local originalOwnerPlayer = Players[eOriginalOwner]
    local eOwnerBeforeOccupation = g_pSelectedCity:GetOwnerBeforeOccupation()
    local eConqueredFrom = g_pSelectedCity:GetJustConqueredFrom()
    local bWipedOut = (originalOwnerPlayer:GetCities():GetCount() < 1)
    local eLastTransferType = g_pSelectedCity:GetLastTransferType()
    local iFavorForLiberation = GlobalParameters.FAVOR_FOR_LIBERATE_PLAYER_CITY
    local pPlayerConfig = PlayerConfigurations[eOriginalOwner]
    local isMinorCiv = pPlayerConfig:GetCivilizationLevelTypeID() ~= CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV
    if isMinorCiv then
        iFavorForLiberation = GlobalParameters.FAVOR_FOR_LIBERATE_CITY_STATE
    end
    local cities = originalOwnerPlayer:GetCities()
    if not isMinorCiv and cities:GetCount() == 0 and not localPlayer:GetStats():GetHasRevivedPlayer(eOriginalOwner) then
        iFavorForLiberation = iFavorForLiberation + GlobalParameters.FAVOR_FOR_REVIVE_PLAYER
    end

    if eOriginalOwner ~= eOwnerBeforeOccupation
        and localPlayer:GetDiplomacy():CanLiberateCityTo(eOriginalOwner)
        and eOriginalOwner ~= eConqueredFrom then
        Controls.Button1:LocalizeAndSetText(
            "LOC_RAZE_CITY_LIBERATE_FOUNDER_BUTTON_LABEL",
            PlayerConfigurations[eOriginalOwner]:GetCivilizationShortDescription()
        )
        szWarmongerString = Locale.Lookup("LOC_XP2_RAZE_CITY_LIBERATE_WARMONGER_EXPLANATION", iFavorForLiberation)
        Controls.Button1:LocalizeAndSetToolTip("LOC_RAZE_CITY_LIBERATE_EXPLANATION", szWarmongerString)
        Controls.Button1:SetHide(false)
    else
        Controls.Button1:SetHide(true)
    end

    if localPlayer:GetDiplomacy():CanLiberateCityTo(eOwnerBeforeOccupation)
        and eOwnerBeforeOccupation ~= eConqueredFrom then
        Controls.Button2:LocalizeAndSetText(
            "LOC_RAZE_CITY_LIBERATE_PREWAR_OWNER_BUTTON_LABEL",
            PlayerConfigurations[eOwnerBeforeOccupation]:GetCivilizationShortDescription()
        )
        szWarmongerString = Locale.Lookup("LOC_XP2_RAZE_CITY_LIBERATE_WARMONGER_EXPLANATION", iFavorForLiberation)
        Controls.Button2:LocalizeAndSetToolTip("LOC_RAZE_CITY_LIBERATE_EXPLANATION", szWarmongerString)
        Controls.Button2:SetHide(false)
    else
        Controls.Button2:SetHide(true)
    end

    Controls.Button3:LocalizeAndSetText("LOC_RAZE_CITY_KEEP_BUTTON_LABEL")
    if eLastTransferType == CityTransferTypes.BY_GIFT then
        szWarmongerString = Locale.Lookup("LOC_RAZE_CITY_KEEP_EXPLANATION_TRADED")
        Controls.Button3:LocalizeAndSetToolTip(szWarmongerString)
    elseif Players[eConqueredFrom]:IsFreeCities() then
        Controls.Button3:LocalizeAndSetToolTip("LOC_XP2_RAZE_CITY_KEEP_FREE_CITY_EXPLANATION")
    elseif bWipedOut ~= true then
        local iWarmongerPoints = localPlayer:GetDiplomacy():ComputeCityWarmongerPoints(g_pSelectedCity, eConqueredFrom, false)
        szWarmongerString = Locale.Lookup("LOC_XP2_RAZE_CITY_KEEP_WARMONGER_EXPLANATION", iWarmongerPoints)
        Controls.Button3:LocalizeAndSetToolTip("LOC_RAZE_CITY_KEEP_EXPLANATION", szWarmongerString)
    else
        local iWarmongerPoints = localPlayer:GetDiplomacy():ComputeCityWarmongerPoints(g_pSelectedCity, eConqueredFrom, false)
        iWarmongerPoints = (iWarmongerPoints * GlobalParameters.WARMONGER_FINAL_MAJOR_CITY_MULTIPLIER) / 100
        szWarmongerString = Locale.Lookup("LOC_XP2_RAZE_CITY_KEEP_LAST_CITY_EXPLANATION", iWarmongerPoints)
        Controls.Button3:LocalizeAndSetToolTip(szWarmongerString)
    end

    Controls.DissolveButton:LocalizeAndSetText("LOC_PEOPLES_WAR_DISSOLVE_BUTTON")
    local disabledReason = GetDissolveDisabledReason()
    if disabledReason == nil then
        Controls.DissolveButton:LocalizeAndSetToolTip("LOC_PEOPLES_WAR_DISSOLVE_DESCRIPTION")
        Controls.DissolveButton:SetDisabled(false)
    else
        Controls.DissolveButton:LocalizeAndSetToolTip(disabledReason)
        Controls.DissolveButton:SetDisabled(true)
    end

    Controls.Button4:LocalizeAndSetText("LOC_RAZE_CITY_RAZE_BUTTON_LABEL")
    if g_pSelectedCity:CanRaze() then
        if Players[eConqueredFrom]:IsFreeCities() then
            Controls.Button4:LocalizeAndSetToolTip("LOC_XP2_RAZE_CITY_RAZE_FREE_CITY_EXPLANATION")
        elseif bWipedOut ~= true then
            local iWarmongerPoints = localPlayer:GetDiplomacy():ComputeCityWarmongerPoints(
                g_pSelectedCity,
                eConqueredFrom,
                true
            )
            szWarmongerString = Locale.Lookup("LOC_XP2_RAZE_CITY_RAZE_WARMONGER_EXPLANATION", iWarmongerPoints)
            Controls.Button4:LocalizeAndSetToolTip("LOC_RAZE_CITY_RAZE_EXPLANATION", szWarmongerString)
        else
            local iWarmongerPoints = localPlayer:GetDiplomacy():ComputeCityWarmongerPoints(
                g_pSelectedCity,
                eConqueredFrom,
                true
            )
            szWarmongerString = Locale.Lookup("LOC_XP2_RAZE_CITY_RAZE_LAST_CITY_EXPLANATION", iWarmongerPoints)
            Controls.Button4:LocalizeAndSetToolTip(szWarmongerString)
        end
        Controls.Button4:SetDisabled(false)
    else
        Controls.Button4:LocalizeAndSetToolTip("LOC_RAZE_CITY_RAZE_DISABLED_EXPLANATION")
        Controls.Button4:SetDisabled(true)
    end

    Controls.PopupStack:CalculateSize()

    UIManager:QueuePopup(ContextPtr, PopupPriority.Medium)

    Controls.PopupAlphaIn:SetToBeginning()
    Controls.PopupAlphaIn:Play()
    Controls.PopupSlideIn:SetToBeginning()
    Controls.PopupSlideIn:Play()
end

local function TryStartPreparedDissolve(plot)
    if m_pendingDissolveTransaction == nil
        or plot == nil
        or plot:GetIndex() ~= m_pendingDissolveTransaction.PlotIndex
        or GetPlotPropertyString(plot, DISSOLVE_READY_PLOT_PROPERTY) ~= m_pendingDissolveTransaction.ID then
        return
    end

    local city = plot ~= nil and CityManager.GetCityAt(plot:GetX(), plot:GetY()) or nil
    if city == nil or city:GetOwner() ~= Game.GetLocalPlayer() then
        Log("Rejected prepared dissolve because the target city is unavailable")
        return
    end

    local parameters = {}
    parameters[UnitOperationTypes.PARAM_FLAGS] = CityDestroyDirectives.RAZE
    if CityManager.CanStartCommand(city, CityCommandTypes.DESTROY, parameters) then
        m_pendingDissolveTransaction.CityID = city:GetID()
        UI.DeselectAllCities()
        CityManager.RequestCommand(city, CityCommandTypes.DESTROY, parameters)
        Log("Requested city destruction for " .. m_pendingDissolveTransaction.ID)
    else
        Log("City destruction command is unavailable for " .. m_pendingDissolveTransaction.ID)
    end
end

local function OnPlotPropertyChanged(plotX, plotY)
    local plot = Map.GetPlot(plotX, plotY)
    if plot == nil or m_pendingDissolveTransaction == nil then
        return
    end

    if GetPlotPropertyString(plot, DISSOLVE_COMMITTED_PLOT_PROPERTY) == m_pendingDissolveTransaction.ID then
        Log("Dissolve transaction committed " .. m_pendingDissolveTransaction.ID)
        m_pendingDissolveTransaction = nil
        UI.PlaySound("Pride_Moment")
        return
    end

    TryStartPreparedDissolve(plot)
end

local function OnCityRemovedFromMap(playerID, cityID)
    -- The matching removal event is authoritative even if the map still exposes the old city.
    if playerID == Game.GetLocalPlayer()
        and m_pendingDissolveTransaction ~= nil
        and tonumber(cityID) == m_pendingDissolveTransaction.CityID then
        RequestGameplayOperation(
            "COMMIT_DISSOLVE",
            m_pendingDissolveTransaction.PlotIndex,
            {
                CityID = cityID,
                TransactionID = m_pendingDissolveTransaction.ID,
                RemovalConfirmed = 1,
            }
        )
        Log("Requested dissolve commit " .. m_pendingDissolveTransaction.ID)
    end
end

function LateInitialize()
    -- Base initialization binds the overridden OnButton4; do not clear or register it again.
    BaseLateInitialize()
    Controls.DissolveButton:RegisterCallback(Mouse.eLClick, OnDissolveButton)
    Events.PlotPropertyChanged.Add(OnPlotPropertyChanged)
    Events.CityRemovedFromMap.Add(OnCityRemovedFromMap)
end
