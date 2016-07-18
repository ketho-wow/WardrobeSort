-- Author: Ketho (EU-Boulderfist)
-- License: Public Domain

-- TRANSMOG_COLLECTION_ITEM_UPDATE doesnt have any return values for the respective in order to precache... 
-- then what is the best way to just grab all visuals for the visual ids?

-- could use savedvariables as cache to speed up sorting, but it's better left to a library
-- this addon is a complete and utter mess and uses like 2-8 MB of memory

local f = CreateFrame("Frame")

local visualAppearance, visualIllusion = {}, {}
local cacheAppearance, cacheIllusion = {}, {}
local completed = {}

local function IsAppearance()
	return (WardrobeCollectionFrame.transmogType == LE_TRANSMOG_TYPE_APPEARANCE)
end

-- appearances/transmogs get the name via visualID
-- illusions/enchants get the name via sourceID
local function CheckVisuals()
	-- grab all our data first
	if not completed[WardrobeCollectionFrame.activeSlot] then
		local isApp = IsAppearance()
		local cache = isApp and cacheAppearance or cacheIllusion
		local idType = isApp and "visualID" or "sourceID"

		for k, v in pairs(WardrobeCollectionFrame.filteredVisualsList) do
			cache[v[idType]] = true -- queue data to be cached	
		end
		
		f:SetScript("OnUpdate", f.GetVisuals)
	else -- go ahead and sort
		f:SortVisuals()
	end
end

-- takes around 30 onupdates
function f:GetVisuals()
	local isApp = IsAppearance()
	if isApp then
		-- need to use WardrobeCollectionFrame_GetSortedAppearanceSources
		-- otherwise cant get the used header name consistently
		for k in pairs(cacheAppearance) do
			local t = WardrobeCollectionFrame_GetSortedAppearanceSources(k)
			if t[1].name then
				visualAppearance[k] = t[1].name
				cacheAppearance[k] = nil -- remove
			end
		end
	else
		for k in pairs(cacheIllusion) do
			local _, name = C_TransmogCollection.GetIllusionSourceInfo(k)
			visualIllusion[k] = name
			cacheIllusion[k] = nil
		end
	end
	-- got all visuals for the wardrobe slot
	if not next(isApp and cacheAppearance or cacheIllusion) then
		completed[WardrobeCollectionFrame.activeSlot] = true -- remember
		self:SetScript("OnUpdate", nil)
		self:SortVisuals()
	end
end

function f:SortVisuals() -- finally we can sort
	local isApp = IsAppearance()
	local visual = isApp and visualAppearance or visualIllusion
	local idType = isApp and "visualID" or "sourceID"
	
	sort(WardrobeCollectionFrame.filteredVisualsList, function(source1, source2)
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
		
		local name1 = visual[source1[idType]]
		local name2 = visual[source2[idType]]
		
		if name1 ~= name2 then
			return name1 < name2 -- alphabetic
		end
		
		if source1.uiOrder and source2.uiOrder then
			return source1.uiOrder > source2.uiOrder
		end
		return source1.sourceID > source2.sourceID
	end)
	
	WardrobeCollectionFrame_Update() -- update
end

hooksecurefunc("WardrobeCollectionFrame_SortVisuals", CheckVisuals)
