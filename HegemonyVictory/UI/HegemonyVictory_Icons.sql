INSERT INTO IconTextureAtlases (Name, IconSize, IconsPerRow, IconsPerColumn, Filename) VALUES
    ('ICON_ATLAS_HEGEMONY_VICTORY', 26, 1, 1, 'HegemonyVictory26.dds'),
    ('ICON_ATLAS_HEGEMONY_VICTORY', 64, 1, 1, 'HegemonyVictory64.dds'),
    ('ICON_ATLAS_HEGEMONY_VICTORY', 80, 1, 1, 'HegemonyVictory80.dds');

INSERT INTO IconDefinitions (Name, Atlas, [Index])
VALUES ('ICON_VICTORY_HEGEMONY', 'ICON_ATLAS_HEGEMONY_VICTORY', 0);
