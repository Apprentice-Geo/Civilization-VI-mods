-- Gathering Storm replacement UI for loyalty-based city transfers.

local PROPERTY_PENDING_PLOTS = "PEOPLES_WAR_PENDING_CITY_PLOTS"
local DISSOLVE_READY_PLOT_PROPERTY = "PEOPLES_WAR_DISSOLVE_READY"
local DISSOLVE_COMMITTED_PLOT_PROPERTY = "PEOPLES_WAR_DISSOLVE_COMMITTED"
local SCRIPT_EVENT = "PeoplesWar_CityOperation"
local m_transactionCounter = 0
local m_pendingDissolveTransaction = nil
local m_selectedCity = nil

local function Log(message)
    print("PeoplesWar DisloyalCity UI: " .. message)
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

local function GetDissolveDisabledReason()
    local playerID = Game.GetLocalPlayer()
    local player = Players[playerID]
    if player == nil or m_selectedCity == nil or m_selectedCity:GetOwner() ~= playerID then
        return "LOC_PEOPLES_WAR_DISSOLVE_COMMAND_BLOCKED"
    end

    local pending = DecodePlotSet(player:GetProperty(PROPERTY_PENDING_PLOTS))
    local targetPlot = GetCityPlotIndex(m_selectedCity)
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

    if not m_selectedCity:CanRaze() then
        return "LOC_PEOPLES_WAR_DISSOLVE_COMMAND_BLOCKED"
    end

    return nil
end

local function OnKeepButton()
    local parameters = {}
    parameters[UnitOperationTypes.PARAM_FLAGS] = CityDestroyDirectives.KEEP
    if CityManager.CanStartCommand(m_selectedCity, CityCommandTypes.DESTROY, parameters) then
        CityManager.RequestCommand(m_selectedCity, CityCommandTypes.DESTROY, parameters)
    end
    ContextPtr:SetHide(true)
end

local function OnRejectButton()
    local parameters = {}
    parameters[UnitOperationTypes.PARAM_FLAGS] = CityDestroyDirectives.REJECT
    if CityManager.CanStartCommand(m_selectedCity, CityCommandTypes.DESTROY, parameters) then
        UI.DeselectAllCities()
        CityManager.RequestCommand(m_selectedCity, CityCommandTypes.DESTROY, parameters)
    end
    ContextPtr:SetHide(true)
end

local function OnDissolveButton()
    if GetDissolveDisabledReason() ~= nil then
        return
    end

    local playerID = Game.GetLocalPlayer()
    local plotIndex = GetCityPlotIndex(m_selectedCity)
    m_transactionCounter = m_transactionCounter + 1
    local transactionID = table.concat(
        { tostring(playerID), tostring(Game.GetCurrentGameTurn()), tostring(plotIndex), tostring(m_transactionCounter) },
        ":"
    )

    -- Gameplay validates and snapshots the transaction before UI requests destruction.
    m_pendingDissolveTransaction = { ID = transactionID, PlotIndex = plotIndex }
    RequestGameplayOperation(
        "PREPARE_DISSOLVE",
        plotIndex,
        { TransactionID = transactionID }
    )
    Log("Requested dissolve preparation " .. transactionID)
    ContextPtr:SetHide(true)
end

local function OnOpen()
    local player = Players[Game.GetLocalPlayer()]
    if player == nil then
        return
    end

    m_selectedCity = player:GetCities():GetNextRebelledCity()
    if m_selectedCity == nil then
        return
    end

    Controls.PanelHeader:LocalizeAndSetText("LOC_DISLOYAL_CITY_HEADER")
    Controls.CityHeader:LocalizeAndSetText("LOC_DISLOYAL_CITY_NAME_LABEL")
    Controls.CityName:LocalizeAndSetText(m_selectedCity:GetName())
    Controls.CityPopulation:LocalizeAndSetText("LOC_DISLOYAL_CITY_POPULATION_LABEL")
    Controls.NumPeople:SetText(tostring(m_selectedCity:GetPopulation()))
    Controls.CityDistricts:LocalizeAndSetText("LOC_DISLOYAL_CITY_DISTRICTS_LABEL")
    Controls.NumDistricts:SetText(tostring(m_selectedCity:GetDistricts():GetNumZonedDistrictsRequiringPopulation()))

    Controls.DissolveButton:LocalizeAndSetText("LOC_PEOPLES_WAR_DISSOLVE_BUTTON")
    local disabledReason = GetDissolveDisabledReason()
    if disabledReason == nil then
        Controls.DissolveButton:LocalizeAndSetToolTip("LOC_PEOPLES_WAR_DISSOLVE_DESCRIPTION")
        Controls.DissolveButton:SetDisabled(false)
    else
        Controls.DissolveButton:LocalizeAndSetToolTip(disabledReason)
        Controls.DissolveButton:SetDisabled(true)
    end

    Controls.KeepButton:LocalizeAndSetText("LOC_DISLOYAL_CITY_CHOOSER_KEEP_BUTTON_LABEL")
    Controls.KeepButton:LocalizeAndSetToolTip("LOC_DISLOYAL_CITY_CHOOSER_KEEP_EXPLANATION")
    Controls.RejectButton:LocalizeAndSetText("LOC_DISLOYAL_CITY_CHOOSER_REFUSE_BUTTON_LABEL")
    Controls.RejectButton:LocalizeAndSetToolTip("LOC_DISLOYAL_CITY_CHOOSER_REFUSE_EXPLANATION")

    Controls.PopupStack:CalculateSize()
    Controls.PopupStack:ReprocessAnchoring()
    Controls.DisloyalCityPanel:ReprocessAnchoring()
    ContextPtr:SetHide(false)
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

    local city = CityManager.GetCityAt(plot:GetX(), plot:GetY())
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

local function OnInputHandler(uiMsg, wParam)
    if uiMsg == KeyEvents.KeyUp and wParam == Keys.VK_ESCAPE then
        ContextPtr:SetHide(true)
    end
    return true
end

local function Initialize()
    ContextPtr:SetHide(true)
    ContextPtr:SetInputHandler(OnInputHandler, true)
    Controls.DissolveButton:RegisterCallback(Mouse.eLClick, OnDissolveButton)
    Controls.KeepButton:RegisterCallback(Mouse.eLClick, OnKeepButton)
    Controls.RejectButton:RegisterCallback(Mouse.eLClick, OnRejectButton)
    Controls.ModalScreenClose:RegisterCallback(Mouse.eLClick, function()
        ContextPtr:SetHide(true)
    end)
    LuaEvents.NotificationPanel_OpenDisloyalCityChooser.Add(OnOpen)
    Events.PlotPropertyChanged.Add(OnPlotPropertyChanged)
    Events.CityRemovedFromMap.Add(OnCityRemovedFromMap)
end

Initialize()
