-- Great Synthesizer
-- Share non-internal leader traits within the same major civilization.

CREATE TABLE IF NOT EXISTS GSYN_SourceLeaderTraits
(
  LeaderType TEXT NOT NULL,
  TraitType TEXT NOT NULL,
  PRIMARY KEY (LeaderType, TraitType)
);

CREATE TABLE IF NOT EXISTS GSYN_InheritedLeaderTraits
(
  LeaderType TEXT NOT NULL,
  TraitType TEXT NOT NULL,
  PRIMARY KEY (LeaderType, TraitType)
);

-- Record only native traits from leaders of major civilizations.
INSERT INTO GSYN_SourceLeaderTraits (LeaderType, TraitType)
SELECT DISTINCT lt.LeaderType, lt.TraitType
FROM LeaderTraits lt
JOIN Traits t ON t.TraitType = lt.TraitType
JOIN CivilizationLeaders cl ON cl.LeaderType = lt.LeaderType
JOIN Civilizations c ON c.CivilizationType = cl.CivilizationType
WHERE c.StartingCivilizationLevelType = 'CIVILIZATION_LEVEL_FULL_CIV'
  AND t.InternalOnly = 0
  AND NOT EXISTS
  (
    SELECT 1
    FROM GSYN_SourceLeaderTraits source
    WHERE source.LeaderType = lt.LeaderType
      AND source.TraitType = lt.TraitType
  );

-- Add every source trait to the other leaders of the same major civilization.
INSERT INTO GSYN_InheritedLeaderTraits (LeaderType, TraitType)
SELECT DISTINCT target.LeaderType, source.TraitType
FROM GSYN_SourceLeaderTraits source
JOIN CivilizationLeaders source_link ON source_link.LeaderType = source.LeaderType
JOIN Civilizations source_civ ON source_civ.CivilizationType = source_link.CivilizationType
JOIN CivilizationLeaders target ON target.CivilizationType = source_link.CivilizationType
JOIN Civilizations target_civ ON target_civ.CivilizationType = target.CivilizationType
WHERE source_civ.StartingCivilizationLevelType = 'CIVILIZATION_LEVEL_FULL_CIV'
  AND target_civ.StartingCivilizationLevelType = 'CIVILIZATION_LEVEL_FULL_CIV'
  AND target.LeaderType <> source.LeaderType
  AND NOT EXISTS
  (
    SELECT 1
    FROM GSYN_InheritedLeaderTraits inherited
    WHERE inherited.LeaderType = target.LeaderType
      AND inherited.TraitType = source.TraitType
  )
  AND NOT EXISTS
  (
    SELECT 1
    FROM LeaderTraits existing
    WHERE existing.LeaderType = target.LeaderType
      AND existing.TraitType = source.TraitType
  );

INSERT INTO LeaderTraits (LeaderType, TraitType)
SELECT inherited.LeaderType, inherited.TraitType
FROM GSYN_InheritedLeaderTraits inherited
WHERE NOT EXISTS
(
  SELECT 1
  FROM LeaderTraits existing
  WHERE existing.LeaderType = inherited.LeaderType
    AND existing.TraitType = inherited.TraitType
);

CREATE TRIGGER IF NOT EXISTS GSYN_LeaderTraits_AfterInsert
AFTER INSERT ON LeaderTraits
WHEN EXISTS
(
  SELECT 1
  FROM Traits t
  WHERE t.TraitType = NEW.TraitType
    AND t.InternalOnly = 0
)
AND NOT EXISTS
(
  SELECT 1
  FROM GSYN_InheritedLeaderTraits inherited
  WHERE inherited.LeaderType = NEW.LeaderType
    AND inherited.TraitType = NEW.TraitType
)
BEGIN
  INSERT INTO GSYN_SourceLeaderTraits (LeaderType, TraitType)
  SELECT NEW.LeaderType, NEW.TraitType
  FROM CivilizationLeaders cl
  JOIN Civilizations c ON c.CivilizationType = cl.CivilizationType
  WHERE cl.LeaderType = NEW.LeaderType
    AND c.StartingCivilizationLevelType = 'CIVILIZATION_LEVEL_FULL_CIV'
    AND NOT EXISTS
    (
      SELECT 1
      FROM GSYN_SourceLeaderTraits source
      WHERE source.LeaderType = NEW.LeaderType
        AND source.TraitType = NEW.TraitType
    );

  INSERT INTO GSYN_InheritedLeaderTraits (LeaderType, TraitType)
  SELECT DISTINCT target.LeaderType, NEW.TraitType
  FROM CivilizationLeaders source_link
  JOIN Civilizations source_civ ON source_civ.CivilizationType = source_link.CivilizationType
  JOIN CivilizationLeaders target ON target.CivilizationType = source_link.CivilizationType
  JOIN Civilizations target_civ ON target_civ.CivilizationType = target.CivilizationType
  WHERE source_link.LeaderType = NEW.LeaderType
    AND source_civ.StartingCivilizationLevelType = 'CIVILIZATION_LEVEL_FULL_CIV'
    AND target_civ.StartingCivilizationLevelType = 'CIVILIZATION_LEVEL_FULL_CIV'
    AND target.LeaderType <> NEW.LeaderType
    AND NOT EXISTS
    (
      SELECT 1
      FROM GSYN_InheritedLeaderTraits inherited
      WHERE inherited.LeaderType = target.LeaderType
        AND inherited.TraitType = NEW.TraitType
    )
    AND NOT EXISTS
    (
      SELECT 1
      FROM LeaderTraits existing
      WHERE existing.LeaderType = target.LeaderType
        AND existing.TraitType = NEW.TraitType
    );

  INSERT INTO LeaderTraits (LeaderType, TraitType)
  SELECT inherited.LeaderType, inherited.TraitType
  FROM GSYN_InheritedLeaderTraits inherited
  WHERE inherited.TraitType = NEW.TraitType
    AND NOT EXISTS
    (
      SELECT 1
      FROM LeaderTraits existing
      WHERE existing.LeaderType = inherited.LeaderType
        AND existing.TraitType = inherited.TraitType
    );
END;

CREATE TRIGGER IF NOT EXISTS GSYN_CivilizationLeaders_AfterInsert
AFTER INSERT ON CivilizationLeaders
WHEN EXISTS
(
  SELECT 1
  FROM Civilizations c
  WHERE c.CivilizationType = NEW.CivilizationType
    AND c.StartingCivilizationLevelType = 'CIVILIZATION_LEVEL_FULL_CIV'
)
BEGIN
  INSERT INTO GSYN_SourceLeaderTraits (LeaderType, TraitType)
  SELECT DISTINCT lt.LeaderType, lt.TraitType
  FROM LeaderTraits lt
  JOIN Traits t ON t.TraitType = lt.TraitType
  WHERE lt.LeaderType = NEW.LeaderType
    AND t.InternalOnly = 0
    AND NOT EXISTS
    (
      SELECT 1
      FROM GSYN_InheritedLeaderTraits inherited
      WHERE inherited.LeaderType = lt.LeaderType
        AND inherited.TraitType = lt.TraitType
    )
    AND NOT EXISTS
    (
      SELECT 1
      FROM GSYN_SourceLeaderTraits source
      WHERE source.LeaderType = lt.LeaderType
        AND source.TraitType = lt.TraitType
    );

  INSERT INTO GSYN_InheritedLeaderTraits (LeaderType, TraitType)
  SELECT DISTINCT NEW.LeaderType, source.TraitType
  FROM GSYN_SourceLeaderTraits source
  JOIN CivilizationLeaders source_link ON source_link.LeaderType = source.LeaderType
  WHERE source_link.CivilizationType = NEW.CivilizationType
    AND source.LeaderType <> NEW.LeaderType
    AND NOT EXISTS
    (
      SELECT 1
      FROM GSYN_InheritedLeaderTraits inherited
      WHERE inherited.LeaderType = NEW.LeaderType
        AND inherited.TraitType = source.TraitType
    )
    AND NOT EXISTS
    (
      SELECT 1
      FROM LeaderTraits existing
      WHERE existing.LeaderType = NEW.LeaderType
        AND existing.TraitType = source.TraitType
    );

  INSERT INTO LeaderTraits (LeaderType, TraitType)
  SELECT inherited.LeaderType, inherited.TraitType
  FROM GSYN_InheritedLeaderTraits inherited
  WHERE inherited.LeaderType = NEW.LeaderType
    AND NOT EXISTS
    (
      SELECT 1
      FROM LeaderTraits existing
      WHERE existing.LeaderType = inherited.LeaderType
        AND existing.TraitType = inherited.TraitType
    );

  INSERT INTO GSYN_InheritedLeaderTraits (LeaderType, TraitType)
  SELECT DISTINCT target.LeaderType, source.TraitType
  FROM GSYN_SourceLeaderTraits source
  JOIN CivilizationLeaders target ON target.CivilizationType = NEW.CivilizationType
  WHERE source.LeaderType = NEW.LeaderType
    AND target.LeaderType <> NEW.LeaderType
    AND NOT EXISTS
    (
      SELECT 1
      FROM GSYN_InheritedLeaderTraits inherited
      WHERE inherited.LeaderType = target.LeaderType
        AND inherited.TraitType = source.TraitType
    )
    AND NOT EXISTS
    (
      SELECT 1
      FROM LeaderTraits existing
      WHERE existing.LeaderType = target.LeaderType
        AND existing.TraitType = source.TraitType
    );

  INSERT INTO LeaderTraits (LeaderType, TraitType)
  SELECT inherited.LeaderType, inherited.TraitType
  FROM GSYN_InheritedLeaderTraits inherited
  JOIN GSYN_SourceLeaderTraits source
    ON source.LeaderType = NEW.LeaderType
   AND source.TraitType = inherited.TraitType
  WHERE inherited.LeaderType <> NEW.LeaderType
    AND NOT EXISTS
    (
      SELECT 1
      FROM LeaderTraits existing
      WHERE existing.LeaderType = inherited.LeaderType
        AND existing.TraitType = inherited.TraitType
    );
END;

-- A final pass catches traits added by other mods before their action order was known.
INSERT INTO GSYN_SourceLeaderTraits (LeaderType, TraitType)
SELECT DISTINCT lt.LeaderType, lt.TraitType
FROM LeaderTraits lt
JOIN Traits t ON t.TraitType = lt.TraitType
JOIN CivilizationLeaders cl ON cl.LeaderType = lt.LeaderType
JOIN Civilizations c ON c.CivilizationType = cl.CivilizationType
WHERE c.StartingCivilizationLevelType = 'CIVILIZATION_LEVEL_FULL_CIV'
  AND t.InternalOnly = 0
  AND NOT EXISTS
  (
    SELECT 1
    FROM GSYN_InheritedLeaderTraits inherited
    WHERE inherited.LeaderType = lt.LeaderType
      AND inherited.TraitType = lt.TraitType
  )
  AND NOT EXISTS
  (
    SELECT 1
    FROM GSYN_SourceLeaderTraits source
    WHERE source.LeaderType = lt.LeaderType
      AND source.TraitType = lt.TraitType
  );

INSERT INTO GSYN_InheritedLeaderTraits (LeaderType, TraitType)
SELECT DISTINCT target.LeaderType, source.TraitType
FROM GSYN_SourceLeaderTraits source
JOIN CivilizationLeaders source_link ON source_link.LeaderType = source.LeaderType
JOIN Civilizations source_civ ON source_civ.CivilizationType = source_link.CivilizationType
JOIN CivilizationLeaders target ON target.CivilizationType = source_link.CivilizationType
JOIN Civilizations target_civ ON target_civ.CivilizationType = target.CivilizationType
WHERE source_civ.StartingCivilizationLevelType = 'CIVILIZATION_LEVEL_FULL_CIV'
  AND target_civ.StartingCivilizationLevelType = 'CIVILIZATION_LEVEL_FULL_CIV'
  AND target.LeaderType <> source.LeaderType
  AND NOT EXISTS
  (
    SELECT 1
    FROM GSYN_InheritedLeaderTraits inherited
    WHERE inherited.LeaderType = target.LeaderType
      AND inherited.TraitType = source.TraitType
  )
  AND NOT EXISTS
  (
    SELECT 1
    FROM LeaderTraits existing
    WHERE existing.LeaderType = target.LeaderType
      AND existing.TraitType = source.TraitType
  );

INSERT INTO LeaderTraits (LeaderType, TraitType)
SELECT inherited.LeaderType, inherited.TraitType
FROM GSYN_InheritedLeaderTraits inherited
WHERE NOT EXISTS
(
  SELECT 1
  FROM LeaderTraits existing
  WHERE existing.LeaderType = inherited.LeaderType
    AND existing.TraitType = inherited.TraitType
);
