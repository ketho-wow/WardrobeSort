-- Author: Ketho (EU-Boulderfist)
-- License: Public Domain

local function LoadFileData(addon)
	local loaded, reason = LoadAddOn(addon)
	if not loaded then
		if reason == "DISABLED" then
			EnableAddOn(addon, true)
			LoadAddOn(addon)
		else
			error(addon.." is "..reason)
		end
	end
	return _G[addon]:GetFileData()
end

local active

-- only load when the wardrobe collections tab is used
WardrobeCollectionFrame:HookScript("OnShow", function()
	if active then
		return
	else
		active = true
	end
	
	local visual = LoadFileData("WardrobeSortData")
	local WardRobe = WardrobeCollectionFrame.ItemsCollectionFrame
	
	-- Sort
	hooksecurefunc(WardRobe, "SortVisuals", function(self)
		sort(self:GetFilteredVisualsList(), function(source1, source2)
			if visual[source1.visualID] and visual[source2.visualID] then
				return visual[source1.visualID] < visual[source2.visualID]
			else
				return source1.visualID < source2.visualID
			end
		end)
	end)
	
	-- Show appearance information
	for _, v in pairs(WardRobe.Models) do
		v:HookScript("OnEnter", function()
			if WardRobe:GetActiveCategory() then
				if visual[v.visualInfo.visualID] then
					GameTooltip:AddLine(visual[v.visualInfo.visualID])
					GameTooltip:Show()
				end
			end
		end)
	end
	
	-- Update GameTooltip when scrollling
	WardRobe:HookScript("OnMouseWheel", function()
		local focus = GetMouseFocus()
		if focus and focus:GetObjectType() == "DressUpModel" then
			focus:GetScript("OnEnter")(focus)
		end
	end)
end)
