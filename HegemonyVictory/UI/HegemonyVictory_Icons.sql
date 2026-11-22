INSERT INTO IconDefinitions (Name, Atlas, [Index])
SELECT 'ICON_VICTORY_HEGEMONY', Atlas, [Index]
FROM IconDefinitions
WHERE Name = 'ICON_VICTORY_UNIVERSAL';
