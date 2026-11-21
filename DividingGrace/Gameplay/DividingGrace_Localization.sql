INSERT OR REPLACE INTO LocalizedText (Language, Tag, Text) VALUES
    ('zh_Hans_CN', 'LOC_DIVIDING_GRACE_PROJECT_NAME', '推恩令'),
    ('en_US',      'LOC_DIVIDING_GRACE_PROJECT_NAME', 'Dividing Grace'),
    ('zh_Hans_CN', 'LOC_DIVIDING_GRACE_PROJECT_DESCRIPTION', '完工时，若本城符合原版夷平规则且有已确定保留的接收城市，则撤销本城，将人口均分给本文明其他已保留的城市，余数优先分给人口较少的城市。若无法执行，原城在开始下一项生产时收回一半项目成本（向下取整）。'),
    ('en_US',      'LOC_DIVIDING_GRACE_PROJECT_DESCRIPTION', 'On completion, if this city is eligible for razing and has a kept city to receive its population, remove this city and divide its population among your other kept cities, with remainders going to the least populous cities first. If the project cannot take effect, this city recovers half of the project cost, rounded down, when it starts its next production.'),
    ('zh_Hans_CN', 'LOC_DIVIDING_GRACE_REFUND_TITLE', '生产力已回收'),
    ('en_US',      'LOC_DIVIDING_GRACE_REFUND_TITLE', 'Production Recovered'),
    ('zh_Hans_CN', 'LOC_DIVIDING_GRACE_REFUND_MESSAGE', '{1_CityName}的当前生产获得了推恩令返还的 {2_Amount} 点 [ICON_Production] 生产力。'),
    ('en_US',      'LOC_DIVIDING_GRACE_REFUND_MESSAGE', '{1_CityName} recovered {2_Amount} [ICON_Production] Production from Dividing Grace toward its current production.');
