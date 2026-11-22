INSERT INTO Types (Type, Kind)
VALUES ('VICTORY_HEGEMONY', 'KIND_VICTORY');

-- An empty TEST_ANY never passes. Gameplay Lua decides when to award the victory.
INSERT INTO RequirementSets (RequirementSetId, RequirementSetType)
VALUES ('HEGEMONY_VICTORY_LUA_REQUIREMENTS', 'REQUIREMENTSET_TEST_ANY');

INSERT INTO Victories (VictoryType, Name, Blurb, RequirementSetId, Description,
                      Icon, CriticalPercentage, RequiresMultipleTeams)
VALUES ('VICTORY_HEGEMONY', 'LOC_VICTORY_HEGEMONY_NAME', 'LOC_VICTORY_HEGEMONY_BLURB',
        'HEGEMONY_VICTORY_LUA_REQUIREMENTS', 'LOC_VICTORY_HEGEMONY_DESCRIPTION',
        'ICON_VICTORY_HEGEMONY', 110, 1);
