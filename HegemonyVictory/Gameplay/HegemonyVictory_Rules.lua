include("HegemonyVictory_Military")

HegemonyVictory = {}

local VICTORY_TYPE = "VICTORY_HEGEMONY"
local HIGHEST_OPPONENT = { "score", "food", "production" }
local OPPONENT_SUM = { "science", "culture", "faith", "gold", "military" }
local MAJORITY = { "wonders", "suzerain" }

function HegemonyVictory.IsEnabled()
    if not Game.IsVictoryEnabled(VICTORY_TYPE) then
        return false
    end

    -- Use all original major participants so eliminating a teammate cannot enable the victory.
    local teams = {}
    for _, player in ipairs(PlayerManager.GetWasEverAliveMajors()) do
        local team = player:GetTeam()
        if teams[team] then
            return false
        end
        teams[team] = true
    end
    return true
end

local function CountMajor(player)
    local food, production = 0, 0
    for _, city in player:GetCities():Members() do
        food = food + city:GetYield(YieldTypes.FOOD)
        production = production + city:GetYield(YieldTypes.PRODUCTION)
    end

    local treasury = player:GetTreasury()
    return {
        score = player:GetScore(),
        food = food,
        production = production,
        science = player:GetTechs():GetScienceYield(),
        culture = player:GetCulture():GetCultureYield(),
        faith = player:GetReligion():GetFaithYield(),
        gold = treasury:GetGoldYield() - treasury:GetTotalMaintenance(),
        military = HegemonyVictory_GetMilitaryStrength(player),
        wonders = 0,
        suzerain = 0,
    }
end

local function CountWorldWonders(snapshot)
    -- Plot ownership also covers wonders in city-states and Free Cities.
    for index = 0, Map.GetPlotCount() - 1 do
        local plot = Map.GetPlotByIndex(index)
        if plot:IsWonderComplete() then
            snapshot.wonders = snapshot.wonders + 1
            local owner = snapshot.majors[plot:GetOwner()]
            if owner then
                owner.wonders = owner.wonders + 1
            end
        end
    end
end

local function CountSuzerains(snapshot)
    for _, cityState in ipairs(PlayerManager.GetAliveMinors()) do
        local suzerain = cityState:GetInfluence():GetSuzerain()
        if suzerain >= 0 then
            snapshot.suzerain = snapshot.suzerain + 1
            local owner = snapshot.majors[suzerain]
            if owner then
                owner.suzerain = owner.suzerain + 1
            end
        end
    end
end

function HegemonyVictory.Capture()
    local majors = PlayerManager.GetAliveMajors()
    if #majors < 2 then
        return nil
    end

    local snapshot = { ids = {}, majors = {}, wonders = 0, suzerain = 0 }
    for _, player in ipairs(majors) do
        local id = player:GetID()
        snapshot.ids[#snapshot.ids + 1] = id
        snapshot.majors[id] = CountMajor(player)
    end
    CountWorldWonders(snapshot)
    CountSuzerains(snapshot)
    return snapshot
end

function HegemonyVictory.Evaluate(snapshot, playerID)
    local player = snapshot.majors[playerID]
    if not player then
        return nil, false
    end

    local results = {}
    local allMet = true
    for _, key in ipairs(HIGHEST_OPPONENT) do
        local target = -math.huge
        for _, id in ipairs(snapshot.ids) do
            if id ~= playerID then
                target = math.max(target, snapshot.majors[id][key])
            end
        end
        local met = player[key] > target
        results[key] = { value = player[key], target = target, met = met }
        allMet = allMet and met
    end

    for _, key in ipairs(OPPONENT_SUM) do
        local target = 0
        for _, id in ipairs(snapshot.ids) do
            if id ~= playerID then
                local value = snapshot.majors[id][key]
                if key == "gold" then
                    value = math.max(0, value)
                end
                target = target + value
            end
        end
        local met = player[key] > target
        results[key] = { value = player[key], target = target, met = met }
        allMet = allMet and met
    end

    for _, key in ipairs(MAJORITY) do
        local total = snapshot[key]
        local automatic = total == 0
        local target = automatic and 0 or math.floor(total / 2) + 1
        local met = automatic or player[key] >= target
        results[key] = {
            value = player[key], target = target, met = met, total = total, automatic = automatic,
        }
        allMet = allMet and met
    end

    return results, allMet
end
