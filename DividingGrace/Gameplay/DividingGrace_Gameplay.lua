local PROJECT = GameInfo.Projects["PROJECT_DIVIDING_GRACE"]
local COMPLETED_PROPERTY = "DIVIDING_GRACE_COMPLETED"
local SETTLED_PROPERTY = "DIVIDING_GRACE_SETTLED"
local COMPLETION_OWNER_PROPERTY = "DIVIDING_GRACE_COMPLETION_OWNER"
local REFUND_PROPERTY = "DIVIDING_GRACE_REFUND"

local function Log(message)
    print("DividingGrace: " .. message)
end

local function IsEligiblePlayer(player)
    return player ~= nil and player:IsHuman() and player:IsMajor()
end

local function GetNumberProperty(city, key)
    local value = city:GetProperty(key)
    return tonumber(value) or 0
end

local function ApplyRefund(city)
    local amount = GetNumberProperty(city, REFUND_PROPERTY)
    if amount <= 0 then
        return
    end

    local queue = city:GetBuildQueue()
    local production = queue:CurrentlyBuilding()
    if production == nil or production == "NONE" then
        return
    end

    local playerID = city:GetOwner()
    local cityName = city:GetName()
    local x, y = city:GetX(), city:GetY()
    -- AddProgress can complete the active production and run other callbacks.
    city:SetProperty(REFUND_PROPERTY, nil)
    queue:AddProgress(amount)
    NotificationManager.SendNotification(playerID, NotificationTypes.USER_DEFINED_1,
        Locale.Lookup("LOC_DIVIDING_GRACE_REFUND_MESSAGE", Locale.Lookup(cityName), amount),
        Locale.Lookup("LOC_DIVIDING_GRACE_REFUND_TITLE"), x, y)
    Log("Applied " .. amount .. " recovered Production at (" .. x .. ", " .. y .. ")")
end

local function Refund(city, cost, reason)
    local amount = math.floor(cost / 2)
    city:SetProperty(REFUND_PROPERTY, GetNumberProperty(city, REFUND_PROPERTY) + amount)
    Log("Project failed in city " .. city:GetID() .. " (" .. reason .. "), refund " .. amount)
    -- A queued item may already be active when the completion is settled.
    ApplyRefund(city)
end

local function GetRecipients(player, sourceCity, recipientIDs)
    local recipients = {}
    for _, city in player:GetCities():Members() do
        if city:GetID() ~= sourceCity:GetID() and recipientIDs[city:GetID()] then
            recipients[#recipients + 1] = {
                City = city,
                Population = city:GetPopulation(),
                Plot = Map.GetPlotIndex(city:GetX(), city:GetY())
            }
        end
    end

    table.sort(recipients, function(left, right)
        if left.Population ~= right.Population then
            return left.Population < right.Population
        end
        return left.Plot < right.Plot
    end)
    return recipients
end

local function DistributePopulation(population, recipients)
    local share = math.floor(population / #recipients)
    local remainder = population % #recipients
    for index, recipient in ipairs(recipients) do
        local amount = share
        if index <= remainder then
            amount = amount + 1
        end
        if amount > 0 then
            recipient.City:ChangePopulation(amount)
        end
    end
end

local function OnResolve(playerID, parameters)
    local player = Players[playerID]
    if not IsEligiblePlayer(player) or type(parameters) ~= "table" then
        return
    end

    local cityID = tonumber(parameters.CityID)
    local completion = tonumber(parameters.Completion)
    local cost = tonumber(parameters.Cost)
    local canRaze = tonumber(parameters.CanRaze)
    if cityID == nil or completion == nil or cost == nil or cost < 1 or (canRaze ~= 0 and canRaze ~= 1) then
        return
    end

    local city = CityManager.GetCity(playerID, cityID)
    if city == nil or city:GetOwner() ~= playerID then
        return
    end
    local completionOwner = city:GetProperty(COMPLETION_OWNER_PROPERTY)
    if tonumber(completionOwner) ~= playerID then
        return
    end
    if completion ~= GetNumberProperty(city, SETTLED_PROPERTY) + 1
        or completion > GetNumberProperty(city, COMPLETED_PROPERTY) then
        return
    end
    city:SetProperty(SETTLED_PROPERTY, completion)

    if canRaze == 0 then
        Refund(city, cost, "city is ineligible for razing")
        return
    end

    local recipientIDs = {}
    for id in string.gmatch(parameters.RecipientIDs or "", "%d+") do
        recipientIDs[tonumber(id)] = true
    end

    local recipients = GetRecipients(player, city, recipientIDs)
    if #recipients == 0 then
        Refund(city, cost, "no kept city to receive population")
        return
    end

    local population = city:GetPopulation()
    local x, y = city:GetX(), city:GetY()
    CityManager.DestroyCity(city)
    local remainingCity = CityManager.GetCityAt(x, y)
    if remainingCity ~= nil then
        Refund(remainingCity, cost, "city removal failed")
        return
    end

    DistributePopulation(population, recipients)
    Log("Removed city " .. cityID .. " and moved " .. population .. " population to " .. #recipients .. " cities")
end

local function OnProjectCompleted(playerID, cityID, projectID, buildingID, x, y, cancelled)
    if cancelled or projectID ~= PROJECT.Index or not IsEligiblePlayer(Players[playerID]) then
        return
    end

    local city = CityManager.GetCity(playerID, cityID)
    if city == nil then
        return
    end

    -- The UI reads CanRaze and GetProjectCost. Only a recorded gameplay completion can be settled.
    local completed = GetNumberProperty(city, COMPLETED_PROPERTY)
    local completionOwner = city:GetProperty(COMPLETION_OWNER_PROPERTY)
    if tonumber(completionOwner) ~= playerID then
        city:SetProperty(SETTLED_PROPERTY, completed)
        city:SetProperty(COMPLETION_OWNER_PROPERTY, playerID)
    end
    local completion = completed + 1
    city:SetProperty(COMPLETED_PROPERTY, completion)
    ReportingEvents.SendLuaEvent("DividingGrace_ProjectCompleted", {
        PlayerID = playerID,
        CityID = cityID,
        Completion = completion
    })
end

local function OnProductionChanged(playerID, cityID)
    local city = CityManager.GetCity(playerID, cityID)
    if city ~= nil then
        ApplyRefund(city)
    end
end

if PROJECT ~= nil then
    Events.CityProjectCompleted.Add(OnProjectCompleted)
    Events.CityProductionChanged.Add(OnProductionChanged)
    GameEvents.DividingGrace_Resolve.Add(OnResolve)
    Log("Loaded.")
end
