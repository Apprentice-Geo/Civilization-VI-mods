-- Gameplay has no PlayerStats:GetMilitaryStrengthWithoutTreasury().
-- Use the same unit calculation as GameCore's CalculateMilitaryStrength: the
-- higher of melee and ranged strength, scaled by remaining health in 8-bit
-- fixed point. Omitting gold before rounding keeps the result independent of
-- the treasury, including the fractional carry that can occur in the UI.
-- https://cru121.github.io/civ6-gamecore-reference/devce/PlayerStats.html#calculatemilitarystrength
function HegemonyVictory_GetMilitaryStrength(player)
    local fixedPointScale = 256
    local total = 0
    for _, unit in player:GetUnits():Members() do
        local maxDamage = unit:GetMaxDamage()
        local health = maxDamage - unit:GetDamage()
        local strength = math.max(unit:GetCombat(false), unit:GetRangedCombat())
        local contribution = math.modf(strength * health * fixedPointScale / maxDamage)
        total = total + contribution
    end
    return math.floor(total / fixedPointScale)
end
