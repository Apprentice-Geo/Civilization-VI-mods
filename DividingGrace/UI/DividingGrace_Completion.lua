local PROJECT = GameInfo.Projects["PROJECT_DIVIDING_GRACE"]
local COMPLETED_PROPERTY = "DIVIDING_GRACE_COMPLETED"
local SETTLED_PROPERTY = "DIVIDING_GRACE_SETTLED"
local COMPLETION_OWNER_PROPERTY = "DIVIDING_GRACE_COMPLETION_OWNER"

local function GetNumberProperty(city, key)
    local value = city:GetProperty(key)
    return tonumber(value) or 0
end

local function ResolveCompletion(playerID, city, completion)
    if completion <= GetNumberProperty(city, SETTLED_PROPERTY) then
        return
    end

    local cities = Players[playerID]:GetCities()
    local rebelledCity = cities:GetNextRebelledCity()
    local rebelledID = rebelledCity and rebelledCity:GetID()
    local recipientIDs = {}
    for _, candidate in cities:Members() do
        local candidateID = candidate:GetID()
        if candidateID ~= city:GetID() and candidateID ~= rebelledID and candidate:GetJustConqueredFrom() < 0 then
            recipientIDs[#recipientIDs + 1] = candidateID
        end
    end

    local cost = city:GetBuildQueue():GetProjectCost(PROJECT.Index)
    UI.RequestPlayerOperation(playerID, PlayerOperations.EXECUTE_SCRIPT, {
        OnStart = "DividingGrace_Resolve",
        CityID = city:GetID(),
        Completion = completion,
        CanRaze = city:CanRaze() and 1 or 0,
        Cost = cost,
        RecipientIDs = table.concat(recipientIDs, ",")
    })
end

local function OnProjectCompleted(data)
    if data.PlayerID ~= Game.GetLocalPlayer() then
        return
    end
    local city = CityManager.GetCity(data.PlayerID, data.CityID)
    if city ~= nil then
        ResolveCompletion(data.PlayerID, city, data.Completion)
    end
end

local function ResolvePendingCompletions()
    local playerID = Game.GetLocalPlayer()
    local player = Players[playerID]
    if player == nil or not player:IsHuman() or not player:IsMajor() then
        return
    end

    for _, city in player:GetCities():Members() do
        local completionOwner = city:GetProperty(COMPLETION_OWNER_PROPERTY)
        if tonumber(completionOwner) == playerID then
            local settled = GetNumberProperty(city, SETTLED_PROPERTY)
            local completed = GetNumberProperty(city, COMPLETED_PROPERTY)
            for completion = settled + 1, completed do
                ResolveCompletion(playerID, city, completion)
            end
        end
    end
end

if PROJECT ~= nil then
    LuaEvents.DividingGrace_ProjectCompleted.Add(OnProjectCompleted)
    Events.LoadGameViewStateDone.Add(ResolvePendingCompletions)
    Events.LocalPlayerTurnBegin.Add(ResolvePendingCompletions)
end
