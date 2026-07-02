-- BarbarianWard
-- Author: ApprenTice
-- DateCreated: 2/27/2026 9:36:47 PM
--------------------------------------------------------------
INSERT INTO TraitModifiers (TraitType, ModifierId) VALUES 
('TRAIT_LEADER_MAJOR_CIV', 'HUMAN_PLAYER_BARBARIAN_COMBAT_ENHANCE');

INSERT INTO Modifiers (ModifierId, ModifierType, RunOnce, Permanent, NewOnly, OwnerRequirementSetId, SubjectRequirementSetId) VALUES 
('HUMAN_PLAYER_BARBARIAN_COMBAT_ENHANCE', 'MODIFIER_PLAYER_UNITS_ADJUST_BARBARIAN_COMBAT', 0, 0, 0, 'HUMAN_PLAYER_BARBARIAN_COMBAT_ENHANCE_REQUIREMENT', NULL);

INSERT INTO ModifierArguments (ModifierId, Name, Value) VALUES 
('HUMAN_PLAYER_BARBARIAN_COMBAT_ENHANCE', 'Amount', '99');

INSERT INTO RequirementSets (RequirementSetId, RequirementSetType) VALUES 
('HUMAN_PLAYER_BARBARIAN_COMBAT_ENHANCE_REQUIREMENT', 'REQUIREMENTSET_TEST_ALL');

INSERT INTO RequirementSetRequirements (RequirementSetId, RequirementId) VALUES 
('HUMAN_PLAYER_BARBARIAN_COMBAT_ENHANCE_REQUIREMENT', 'PLAYER_IS_HUMAN');

INSERT INTO Requirements (RequirementId, RequirementType) VALUES 
('PLAYER_IS_HUMAN', 'REQUIREMENT_PLAYER_IS_HUMAN');