-- OpeningTechsAndCivicCompletion.lua

local MOD_NAME = "OpeningTechsAndCivicCompletion"
local PROPERTY_DONE = "OPENING_TECHS_AND_CIVIC_COMPLETION_DONE"

local TECHS_TO_COMPLETE = {
    "TECH_POTTERY",
    "TECH_ANIMAL_HUSBANDRY",
    "TECH_MINING",
    "TECH_SAILING",
    "TECH_ASTROLOGY",
}

local CIVICS_TO_COMPLETE = {
    "CIVIC_CODE_OF_LAWS",
}

local function Log(message)
    print(MOD_NAME .. ": " .. message)
end

local function IsAncientEraStart()
    local ancientEra = GameInfo.Eras["ERA_ANCIENT"]
    if ancientEra == nil then
        Log("ERA_ANCIENT not found.")
        return false
    end

    if GameConfiguration.GetStartEra ~= nil then
        return GameConfiguration.GetStartEra() == ancientEra.Hash
    end

    -- Fallback: normally not needed, but kept for compatibility if GetStartEra is unavailable.
    if GameConfiguration.GetValue ~= nil then
        local startEra = GameConfiguration.GetValue("START_ERA")

        if startEra == "ERA_ANCIENT" then
            return true
        end

        if type(startEra) == "number" then
            return startEra == ancientEra.Hash
        end
    end

    Log("Unable to determine start era.")
    return false
end

local function CompleteTechs(player)
    local playerTechs = player:GetTechs()

    if playerTechs == nil then
        Log("player:GetTechs() returned nil.")
        return
    end

    for _, techType in ipairs(TECHS_TO_COMPLETE) do
        local techInfo = GameInfo.Technologies[techType]

        if techInfo ~= nil then
            playerTechs:SetTech(techInfo.Index, true)
            Log("Completed technology: " .. techType)
        else
            Log("Technology not found: " .. techType)
        end
    end
end

local function CompleteCivics(player)
    local playerCulture = player:GetCulture()

    if playerCulture == nil then
        Log("player:GetCulture() returned nil.")
        return
    end

    for _, civicType in ipairs(CIVICS_TO_COMPLETE) do
        local civicInfo = GameInfo.Civics[civicType]

        if civicInfo ~= nil then
            playerCulture:SetCivic(civicInfo.Index, true)
            Log("Completed civic: " .. civicType)
        else
            Log("Civic not found: " .. civicType)
        end
    end
end

local function OnCityBuilt(playerID, cityID, x, y)
    if not IsAncientEraStart() then
        return
    end

    local player = Players[playerID]

    if player == nil then
        return
    end

    if not player:IsMajor() then
        return
    end

    if not player:IsHuman() then
        return
    end

    if player:GetProperty(PROPERTY_DONE) == 1 then
        return
    end

    -- CityBuilt fires after the city exists, so the first founded city should make the count 1.
    if player:GetCities():GetCount() ~= 1 then
        return
    end

    CompleteTechs(player)
    CompleteCivics(player)

    player:SetProperty(PROPERTY_DONE, 1)

    Log("Completed opening techs and civic for player " .. tostring(playerID))
end

GameEvents.CityBuilt.Add(OnCityBuilt)

Log("Loaded.")