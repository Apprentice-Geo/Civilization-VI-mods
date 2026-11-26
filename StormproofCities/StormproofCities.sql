-- Gathering Storm spells PREVENET this way in Liang's original modifier ID.
INSERT OR IGNORE INTO GovernorPromotionModifiers (GovernorPromotionType, ModifierId)
SELECT GovernorPromotionType, 'REINFORCED_INFRASTRUCTURE_PREVENET_STRUCTURAL_DAMAGE'
FROM GovernorPromotions
WHERE BaseAbility = 1;
