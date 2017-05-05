-- Author: Ketho (EU-Boulderfist)
-- License: Public Domain

-- TRANSMOG_COLLECTION_ITEM_UPDATE doesnt have any meaningful return values
local f = CreateFrame("Frame")
local WardRobe = WardrobeCollectionFrame.ItemsCollectionFrame

local visuals, cache = {}, {}
local completed = {}

local function CheckVisuals()
	local category = WardRobe:GetActiveCategory()
	if category then -- does not include enchants/illusions
		if completed[category] then
			f:SortVisuals()
		else
			local filteredVisualsList = WardRobe:GetFilteredVisualsList()
			if #filteredVisualsList > 0 then -- the first time it will return an empty table
				for _, v in pairs(filteredVisualsList) do
					cache[v.visualID] = true -- queue data to be cached	
				end
				f:SetScript("OnUpdate", f.CacheNames)
			end
		end
	end
end

-- takes around 5 to 30 onupdates
function f:CacheNames()
	for k in pairs(cache) do
		-- oh my god so much garbage, uses like 2-8 MB of memory
		local appearances = WardrobeCollectionFrame_GetSortedAppearanceSources(k)
		if appearances[1].name then
			visuals[k] = appearances[1].name
			cache[k] = nil
		end
	end
	
	if not next(cache) then
		completed[WardRobe:GetActiveCategory()] = true
		self:SetScript("OnUpdate", nil)
		self:SortVisuals()
	end
end

function f:SortVisuals()
	local filteredVisualsList = WardRobe:GetFilteredVisualsList()
	
	if filteredVisualsList then -- wardrobe can be closed while caching was in progress
		sort(filteredVisualsList, function(source1, source2)
			if source1.isCollected ~= source2.isCollected then
				return source1.isCollected
			end
			if source1.isUsable ~= source2.isUsable then
				return source1.isUsable
			end
			if source1.isFavorite ~= source2.isFavorite then
				return source1.isFavorite
			end
			if source1.isHideVisual ~= source2.isHideVisual then
				return source1.isHideVisual
			end
			
			local name1 = visuals[source1.visualID]
			local name2 = visuals[source2.visualID]
			
			if name1 and name2 and name1 ~= name2 then
				return name1 < name2
			end
			
			if source1.uiOrder and source2.uiOrder then
				return source1.uiOrder > source2.uiOrder
			end
			return source1.sourceID > source2.sourceID
		end)
		
		WardRobe:UpdateItems()
	end
end

hooksecurefunc(WardRobe, "SortVisuals", CheckVisuals)
