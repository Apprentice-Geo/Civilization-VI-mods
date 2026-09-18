-- Dividing Grace（推恩令）草稿：阶段 A 从 PeoplesWar_Localization.sql 原样摘出的 4 条文案。
-- 标识符仍是 LOC_PEOPLES_WAR_DISSOLVE_*，阶段 B 统一改为 LOC_DIVIDING_GRACE_*。
-- 按钮文案已按新术语写为“推恩令”/“Dividing Grace”。

INSERT OR REPLACE INTO LocalizedText (Language, Tag, Text) VALUES
  ('zh_Hans_CN', 'LOC_PEOPLES_WAR_DISSOLVE_BUTTON', '推恩令'),
  ('en_US', 'LOC_PEOPLES_WAR_DISSOLVE_BUTTON', 'Dividing Grace'),
  ('zh_Hans_CN', 'LOC_PEOPLES_WAR_DISSOLVE_DESCRIPTION', '撤销该城市的城市建制，并将全部人口重新分配至帝国其他已确定保留的城市。无法均分的余数依次分配给其中人口最少的城市，每座城市一个人口。'),
  ('en_US', 'LOC_PEOPLES_WAR_DISSOLVE_DESCRIPTION', 'Dissolve this city and redistribute its entire population among your other retained cities. Any remainder is assigned one population each to the least-populous eligible cities.'),
  ('zh_Hans_CN', 'LOC_PEOPLES_WAR_DISSOLVE_NO_RECIPIENTS', '没有其他已确定保留的城市可以接收人口。'),
  ('en_US', 'LOC_PEOPLES_WAR_DISSOLVE_NO_RECIPIENTS', 'No other retained city can receive this population.'),
  ('zh_Hans_CN', 'LOC_PEOPLES_WAR_DISSOLVE_COMMAND_BLOCKED', '当前游戏状态不允许对该城市施行推恩令。'),
  ('en_US', 'LOC_PEOPLES_WAR_DISSOLVE_COMMAND_BLOCKED', 'The current game state does not allow Dividing Grace in this city.');
