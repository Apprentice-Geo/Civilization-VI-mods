include("InstanceManager")

local rowManager = InstanceManager:new("HegemonyMetric", "Row", Controls.MetricRows)
local metColor = UI.GetColorValueFromHexLiteral(0xFFB1E5AA)
local unmetColor = UI.GetColorValueFromHexLiteral(0xFFD4C2B6)
local alternateRowColor = UI.GetColorValueFromHexLiteral(0xDC30404B)

local function Render(metrics)
    rowManager:ResetInstances()
    for index, metric in ipairs(metrics) do
        local row = rowManager:GetInstance()
        row.Metric:SetText(metric.label)
        row.Value:SetText(metric.value)
        row.Target:SetText(metric.target)
        row.Status:SetText(metric.status)
        row.Status:SetColor(metric.met and metColor or unmetColor)
        row.Row:SetToolTipString(metric.help)
        if index % 2 == 0 then
            row.Row:SetColor(alternateRowColor)
        end
    end
    Controls.MetricRows:CalculateSize()
    Controls.MetricRows:ReprocessAnchoring()
    ContextPtr:SetSizeX(Controls.MetricHeader:GetSizeX())
    ContextPtr:SetSizeY(Controls.MetricRows:GetOffsetY() + Controls.MetricRows:GetSizeY())
end

LuaEvents.HegemonyVictory_RenderMetricTable.Add(Render)
ContextPtr:SetShutdown(function()
    LuaEvents.HegemonyVictory_RenderMetricTable.Remove(Render)
end)
