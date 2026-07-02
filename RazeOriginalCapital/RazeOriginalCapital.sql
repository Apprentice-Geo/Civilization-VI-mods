-- RazeOriginalCapital
-- Author: ApprenTice
-- DateCreated: 1/28/2026 7:59:19 PM
--------------------------------------------------------------
-- Allow razing any city, including original capitals

UPDATE GlobalParameters
SET Value = 'true'
WHERE Name = 'COMBAT_RAZE_ANY_CITY'
  AND Value <> 'true';