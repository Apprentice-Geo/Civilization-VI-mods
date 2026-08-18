include("SelectedUnit");

print("[RockBandLens] SelectedUnit_Expansion2.lua loaded (V-2026-8-16_text_v5)");


-- ===========================================================================
-- 汇总乐队促销带来的表演等级加成
-- 返回 { Districts={[DistrictType]=amount}, Improvements={[ImprovementType]=amount},
--        NationalPark=amount, NaturalWonder=amount }
-- ===========================================================================
function GetRockBandLevelBonuses( kUnit:table )
	local bonuses:table = { Districts = {}, Improvements = {}, NationalPark = 0, NaturalWonder = 0 };
	local unitExperience:table = kUnit:GetExperience();
	if unitExperience == nil then return bonuses; end
	local promotionList:table = unitExperience:GetPromotions();
	if promotionList == nil then return bonuses; end

	for _, promotionHash:number in ipairs(promotionList) do
		local promotionDef:table = GameInfo.UnitPromotions[promotionHash];
		if promotionDef ~= nil then
			for promoModifier:table in GameInfo.UnitPromotionModifiers() do
				if promoModifier.UnitPromotionType == promotionDef.UnitPromotionType then
					local modifierDef:table = GameInfo.Modifiers[promoModifier.ModifierId];
					if modifierDef ~= nil then
						-- 收集该 modifier 的参数
						local districtType = nil;
						local improvementType = nil;
						local amount:number = 0;
						for arg:table in GameInfo.ModifierArguments() do
							if arg.ModifierId == promoModifier.ModifierId then
								if arg.Name == "DistrictType" then districtType = arg.Value; end
								if arg.Name == "ImprovementType" then improvementType = arg.Value; end
								if arg.Name == "Amount" then amount = tonumber(arg.Value) or 0; end
							end
						end
						if modifierDef.ModifierType == "MODIFIER_PLAYER_UNIT_ADJUST_ROCK_BAND_LEVEL_DISTRICT" then
							if districtType ~= nil then
								bonuses.Districts[districtType] = (bonuses.Districts[districtType] or 0) + amount;
							end
						elseif modifierDef.ModifierType == "MODIFIER_PLAYER_UNIT_ADJUST_ROCK_BAND_LEVEL_IMPROVEMENT" then
							if improvementType ~= nil then
								bonuses.Improvements[improvementType] = (bonuses.Improvements[improvementType] or 0) + amount;
							end
						elseif modifierDef.ModifierType == "MODIFIER_PLAYER_UNIT_ADJUST_ROCK_BAND_LEVEL_NATIONAL_PARK" then
							bonuses.NationalPark = bonuses.NationalPark + amount;
						elseif modifierDef.ModifierType == "MODIFIER_PLAYER_UNIT_ADJUST_ROCK_BAND_LEVEL_NATURAL_WONDER" then
							bonuses.NaturalWonder = bonuses.NaturalWonder + amount;
						end
					end
				end
			end
		end
	end
	return bonuses;
end

-- ===========================================================================
-- 计算某地块命中的"最大促销加成"（0=无加成、1=+1、2+=+2及以上）
-- 摇滚乐队在"区域地块"上表演：按地块自身区域类型/国家公园/自然奇观/改良匹配促销
-- ===========================================================================
function GetRockBandPromoBonusForPlot( plot:table, bonuses:table )
	local maxBonus:number = 0;
	if plot ~= nil then
		-- 地块自身区域类型匹配（如娱乐区地块 → 竞技场摇滚 +2）
		local districtType:number = plot:GetDistrictType();
		if districtType ~= nil and districtType ~= -1 then
			local districtDef:table = GameInfo.Districts[districtType];
			if districtDef ~= nil and bonuses.Districts[districtDef.DistrictType] ~= nil then
				maxBonus = math.max(maxBonus, bonuses.Districts[districtDef.DistrictType]);
			end
		end
		-- 国家公园加成（改良，非区域）
		if plot:IsNationalPark() then
			maxBonus = math.max(maxBonus, bonuses.NationalPark);
		end
		-- 自然奇观加成
		local featureType:number = plot:GetFeatureType();
		if featureType ~= nil and featureType ~= -1 then
			local featureDef:table = GameInfo.Features[featureType];
			if featureDef ~= nil and featureDef.NaturalWonder then
				maxBonus = math.max(maxBonus, bonuses.NaturalWonder);
			end
		end
		-- 改良加成（如"冲浪摇滚"在海滩度假村 +等级）
		local improvementType:number = plot:GetImprovementType();
		if improvementType ~= nil and improvementType ~= -1 then
			local improvementDef:table = GameInfo.Improvements[improvementType];
			if improvementDef ~= nil and bonuses.Improvements[improvementDef.ImprovementType] ~= nil then
				maxBonus = math.max(maxBonus, bonuses.Improvements[improvementDef.ImprovementType]);
			end
		end
	end
	return maxBonus;
end

-- ===========================================================================
-- OVERRIDE BASE FUNCTIONS
-- ===========================================================================
function RealizeGreatPersonLens(kUnit:table )
	UILens.ClearLayerHexes(m_HexColoringGreatPeople);

	-- 每次刷新单位 Lens 时先清空自定义 WorldAnchor 数字。
	-- 因此切换单位、取消选择、重新计算摇滚乐队加成都不会残留旧数字。
	LuaEvents.RockBandBonusOverlay_Clear();
	if UILens.IsLayerOn( m_HexColoringGreatPeople ) then
		UILens.ToggleLayerOff(m_HexColoringGreatPeople);
	end
	if kUnit ~= nil and ( not UI.IsGameCoreBusy() ) then
		local playerID:number = kUnit:GetOwner();
		if playerID == Game.GetLocalPlayer() then
			local kUnitArchaeology:table = kUnit:GetArchaeology();
			local kUnitGreatPerson:table = kUnit:GetGreatPerson();
			local kUnitRockBand:table = kUnit:GetRockBand();
			local bCanCauseDisasters:boolean = false;
			local sUnitType = GameInfo.Units[kUnit:GetUnitType()].UnitType;
			if (sUnitType ~= nil and GameInfo.Units_XP2[sUnitType] ~= nil and GameInfo.Units_XP2[sUnitType].CanCauseDisasters ~= nil) then
				bCanCauseDisasters = GameInfo.Units_XP2[sUnitType].CanCauseDisasters;
			end
			if kUnitGreatPerson ~= nil and kUnitGreatPerson:IsGreatPerson() then
				local greatPersonInfo:table = GameInfo.GreatPersonIndividuals[kUnitGreatPerson:GetIndividual()];
				-- Highlight an area around the Great Person (if they have an area of effect trait)
				local areaHighlightPlots:table = {};
				if (greatPersonInfo ~= nil and greatPersonInfo.AreaHighlightRadius ~= nil) then
					areaHighlightPlots = kUnitGreatPerson:GetAreaHighlightPlots();
				end
				-- Highlight the plots the Great Person could use its action on
				local activationPlots:table = {};
				if (greatPersonInfo ~= nil and greatPersonInfo.ActionEffectTileHighlighting ~= nil and greatPersonInfo.ActionEffectTileHighlighting) then
					local rawActivationPlots:table = kUnitGreatPerson:GetActivationHighlightPlots();
					for _,plotIndex:number in ipairs(rawActivationPlots) do
						table.insert(activationPlots, {"Great_People", plotIndex});
					end
				end
				UILens.SetLayerHexesArea(m_HexColoringGreatPeople, playerID, areaHighlightPlots, activationPlots);
				UILens.ToggleLayerOn(m_HexColoringGreatPeople);
			elseif( kUnitArchaeology ~= nil and GameInfo.Units[kUnit:GetUnitType()].ExtractsArtifacts == true) then 
				-- Highlight plots that can activated by Archaeologists
				local activationPlots:table = {};
				local rawActivationPlots:table = kUnitArchaeology:GetActivationHighlightPlots();
				for _,plotIndex:number in ipairs(rawActivationPlots) do
					table.insert(activationPlots, {"Great_People", plotIndex});
				end
					
				UILens.SetLayerHexesArea(m_HexColoringGreatPeople, playerID, {}, activationPlots);
				UILens.ToggleLayerOn(m_HexColoringGreatPeople);
			elseif GameInfo.Units[kUnit:GetUnitType()].ParkCharges > 0 and kUnit:GetParkCharges() > 0 then -- Highlight plots that can activated by Naturalists
				local parkPlots:table = {};
				local rawParkPlots:table = Game.GetNationalParks():GetPossibleParkTiles(playerID);
				for _,plotIndex:number in ipairs(rawParkPlots) do
					table.insert(parkPlots, {"Great_People", plotIndex});
				end
				UILens.SetLayerHexesArea(m_HexColoringGreatPeople, playerID, {}, parkPlots);
				UILens.ToggleLayerOn(m_HexColoringGreatPeople);
			elseif kUnitRockBand ~= nil and GameInfo.Units[kUnit:GetUnitType()].UnitType == "UNIT_ROCK_BAND" then -- Highlight plots that can activated by RockBands
				local rawActivationPlots:table = kUnitRockBand:GetActivationHighlightPlots();

				-- 1) 白框完全沿用原版 Great_People Layer。
				local activationPlots:table = {};
				for _,plotIndex:number in ipairs(rawActivationPlots) do
					table.insert(activationPlots, {"Great_People", plotIndex});
				end
				UILens.SetLayerHexesArea(m_HexColoringGreatPeople, playerID, {}, activationPlots);
				UILens.ToggleLayerOn(m_HexColoringGreatPeople);

				-- 2) 计算促销加成；不再调用 UI.AddNumberToPath。
				--    每个数字通过 LuaEvents 交给独立的 WorldAnchor Context 绘制。
				local bonuses:table = GetRockBandLevelBonuses(kUnit);
				local shownCount:number = 0;
				for _,plotIndex:number in ipairs(rawActivationPlots) do
					local plot:table = Map.GetPlotByIndex(plotIndex);
					local bonus:number = GetRockBandPromoBonusForPlot(plot, bonuses);
					if bonus > 0 then
						LuaEvents.RockBandBonusOverlay_Add(plotIndex, bonus);
						shownCount = shownCount + 1;
					end
				end

				print("[RockBandLens] worldanchor-v4 shown=" .. tostring(shownCount));
			elseif bCanCauseDisasters then -- Highlight plots that this unit can trigger disasters on
				local activationPlots:table = {};
				local rawActivationPlots:table = GameClimate.GetLocationsForPossibleTriggerableEvents(playerID);
				for _,plotIndex:number in ipairs(rawActivationPlots) do
					table.insert(activationPlots, {"Great_People", plotIndex});
				end
					
				UILens.SetLayerHexesArea(m_HexColoringGreatPeople, playerID, {}, activationPlots);
				UILens.ToggleLayerOn(m_HexColoringGreatPeople);
			end
		end
	end
end
