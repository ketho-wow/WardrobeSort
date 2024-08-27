local f = CreateFrame("Frame")
local Wardrobe = WardrobeCollectionFrame.ItemsCollectionFrame

local db, active
local FileData
local SortOrder

local nameVisuals, nameCache = {}, {}
local catCompleted, itemLevels = {}, {}
local unknown = {-1}

local LE_DEFAULT = 1
local LE_APPEARANCE = 2
local LE_ITEM_LEVEL = 3
local LE_ALPHABETIC = 4
local LE_ITEM_SOURCE = 5
local LE_COLOR = 6
local LE_VISUALID = 7

local L = {
	[LE_DEFAULT] = DEFAULT,
	[LE_APPEARANCE] = APPEARANCE_LABEL,
	[LE_ITEM_LEVEL] = STAT_AVERAGE_ITEM_LEVEL,
	[LE_ALPHABETIC] = COMPACT_UNIT_FRAME_PROFILE_SORTBY_ALPHABETICAL,
	[LE_ITEM_SOURCE] = SOURCE:gsub("[:：]", ""),
	[LE_COLOR] = COLOR,
	[LE_VISUALID] = ID,
}

local dropdownOrder = {LE_DEFAULT, LE_APPEARANCE, LE_COLOR, LE_ITEM_SOURCE, LE_ITEM_LEVEL, LE_ALPHABETIC, LE_VISUALID}

local defaults = {
	db_version = 2,
	sortDropdown = LE_DEFAULT,
	reverse = false,
}

local colors = {
	"red", -- 255, 0, 0
	"crimson", -- 255, 0, 63
	"maroon", -- 128, 0, 0
	"pink", -- 255, 192, 203
	"lavender", -- 230, 230, 250
	"purple", -- 128, 0, 128
	"indigo", -- 75, 0, 130

	"blue", -- 0, 0, 255
	"teal", -- 0, 128, 128
	"cyan", -- 0, 255, 255

	"green", -- 0, 255, 0
	"yellow", -- 255, 255, 0
	"gold", -- 255, 215, 0
	"orange", -- 255, 128, 0
	"brown", -- 128, 64, 0

	"black", -- 0, 0, 0
	"gray", -- 128, 128, 128
	"grey",
	"silver", -- 192, 192, 192
	"white", -- 255, 255, 255
}

local ItemCache = setmetatable({}, {__index = function(t, k)
	wipe(itemLevels)
	local sum = 0
	local v

	-- can return source ids for non-existing items
	for _, source in pairs(C_TransmogCollection.GetAllAppearanceSources(k)) do
		local link = select(6, C_TransmogCollection.GetAppearanceSourceInfo(source))
		local ilvl = select(4, C_Item.GetItemInfo(link))
		if ilvl then
			tinsert(itemLevels, ilvl)
			sum = sum + ilvl
		end
	end
	sort(itemLevels)

	-- check if (all?) item info is available
	if #itemLevels > 0 then
		v = {sum/#itemLevels, itemLevels[1], itemLevels[#itemLevels]}
		rawset(t, k, v)
	end
	return v or unknown
end})

local function GetItemLevel(visualID)
	return unpack(ItemCache[visualID])
end

local function LoadFileData(addon)
	local loaded, reason = C_AddOns.LoadAddOn(addon)
	if not loaded then
		if reason == "DISABLED" then
			C_AddOns.EnableAddOn(addon)
			C_AddOns.LoadAddOn(addon)
		else
			error(addon..": "..reason)
		end
	end
	return _G[addon]:GetFileData()
end

local function SortNormal(a, b)
	return a < b
end

local function SortReverse(a, b)
	return a > b
end

local function SortAlphabetic()
	if Wardrobe:IsVisible() then -- check if wardrobe is still open after caching is finished
		sort(Wardrobe:GetFilteredVisualsList(), function(source1, source2)
			if nameVisuals[source1.visualID] and nameVisuals[source2.visualID] then
				return SortOrder(nameVisuals[source1.visualID], nameVisuals[source2.visualID])
			else
				return SortOrder(source1.uiOrder, source2.uiOrder)
			end
		end)
		Wardrobe:UpdateItems()
	end
end

-- takes around 5 to 30 onupdates
local function CacheHeaders()
	for k in pairs(nameCache) do
		-- oh my god so much wasted tables
		local appearances = CollectionWardrobeUtil.GetSortedAppearanceSources(k)[1]
		if appearances.name then
			nameVisuals[k] = appearances.name
			nameCache[k] = nil
		end
	end

	if not next(nameCache) then
		catCompleted[Wardrobe:GetActiveCategory()] = true
		f:SetScript("OnUpdate", nil)
		SortAlphabetic()
	end
end

local sortFunc = {
	[LE_DEFAULT] = function() end,

	[LE_APPEARANCE] = function(self)
		FileData = FileData or LoadFileData("WardrobeSortData")
		sort(self:GetFilteredVisualsList(), function(source1, source2)
			if FileData[source1.visualID] and FileData[source2.visualID] then
				return SortOrder(FileData[source1.visualID], FileData[source2.visualID])
			else
				return SortOrder(source1.uiOrder, source2.uiOrder)
			end
		end)
	end,

	[LE_ITEM_LEVEL] = function(self)
		sort(self:GetFilteredVisualsList(), function(source1, source2)
			local itemLevel1 = GetItemLevel(source1.visualID)
			local itemLevel2 = GetItemLevel(source2.visualID)

			if itemLevel1 ~= itemLevel2 then
				return SortOrder(itemLevel1, itemLevel2)
			else
				return SortOrder(source1.uiOrder, source2.uiOrder)
			end
		end)
	end,

	[LE_ALPHABETIC] = function(self)
		if catCompleted[self:GetActiveCategory()] then
			SortAlphabetic()
		else
			for _, v in pairs(self:GetFilteredVisualsList()) do
				nameCache[v.visualID] = true -- queue data to be cached
			end
			f:SetScript("OnUpdate", CacheHeaders)
		end
	end,

	[LE_ITEM_SOURCE] = function(self)
		FileData = FileData or LoadFileData("WardrobeSortData")
		sort(self:GetFilteredVisualsList(), function(source1, source2)
			local item1 = CollectionWardrobeUtil.GetSortedAppearanceSources(source1.visualID)[1]
			local item2 = CollectionWardrobeUtil.GetSortedAppearanceSources(source2.visualID)[1]
			item1.sourceType = item1.sourceType or 7
			item2.sourceType = item2.sourceType or 7

			if item1.sourceType == item2.sourceType then
				if item1.sourceType == TRANSMOG_SOURCE_BOSS_DROP then
					local drops1 = C_TransmogCollection.GetAppearanceSourceDrops(item1.sourceID)
					local drops2 = C_TransmogCollection.GetAppearanceSourceDrops(item2.sourceID)

					if #drops1 > 0 and #drops2 > 0 then
						local instance1, encounter1 = drops1[1].instance, drops1[1].encounter
						local instance2, encounter2 = drops2[1].instance, drops2[1].encounter

						if instance1 == instance2 then
							return SortOrder(encounter1, encounter2)
						else
							return SortOrder(instance1, instance2)
						end
					end
				else
					if FileData[source1.visualID] and FileData[source2.visualID] then
						return SortOrder(FileData[source1.visualID], FileData[source2.visualID])
					end
				end
			else
				return SortOrder(item1.sourceType, item2.sourceType)
			end
			return SortOrder(source1.uiOrder, source2.uiOrder)
		end)
	end,

	-- sort by the color in filename
	[LE_COLOR] = function(self)
		FileData = FileData or LoadFileData("WardrobeSortData")
		sort(self:GetFilteredVisualsList(), function(source1, source2)
			local file1 = FileData[source1.visualID]
			local file2 = FileData[source2.visualID]

			if file1 and file2 then
				local index1 = #colors+1
				for k, v in pairs(colors) do
					if strfind(file1, v) then
						index1 = k
						break
					end
				end

				local index2 = #colors+1
				for k, v in pairs(colors) do
					if strfind(file2, v) then
						index2 = k
						break
					end
				end

				if index1 == index2 then
					return SortOrder(file1, file2)
				else
					return SortOrder(index1, index2)
				end
			else
				return SortOrder(source1.uiOrder, source2.uiOrder)
			end
		end)
	end,

	[LE_VISUALID] = function(self)
		sort(self:GetFilteredVisualsList(), function(source1, source2)
			return SortOrder(source1.visualID, source2.visualID)
		end)
	end,
}

local function UpdateMouseFocus()
	local focus = GetMouseFoci()[1]
	if focus and focus:GetObjectType() == "DressUpModel" and focus:GetParent() == Wardrobe then
		-- in 10.0 need to delay until next frame
		RunNextFrame(function() focus:GetScript("OnEnter")(focus) end)
	end
end

local function OnItemUpdate()
	-- sort again when we are sure all items are cached. not the most efficient way to do this
	-- this event does not seem to fire for weapons or only when mouseovering a weapon appearance (?)
	if Wardrobe:IsVisible() and (db.sortDropdown == LE_ITEM_LEVEL or db.sortDropdown == LE_ITEM_SOURCE) then
		sortFunc[db.sortDropdown](Wardrobe)
		Wardrobe:UpdateItems()
	end

	if GameTooltip:IsShown() then
		-- when mouse scrolling the tooltip waits for uncached item info and gets refreshed
		C_Timer.After(.01, UpdateMouseFocus)
	end
end

local function Model_OnEnter(self)
	if Wardrobe:GetActiveCategory() then
		local selectedValue = db.sortDropdown
		FileData = FileData or LoadFileData("WardrobeSortData")
		if self.visualInfo then -- when mousescrolling and there is no model on the next page under the cursor
			if selectedValue == LE_APPEARANCE then
				GameTooltip:AddLine(FileData[self.visualInfo.visualID] or self.visualInfo.visualID)

			elseif selectedValue == LE_COLOR then
				local name = FileData[self.visualInfo.visualID]
				if name then
					for _, v in pairs(colors) do
						if strfind(name, v) then -- highlight the color name
							name = name:gsub(v, "|cffFFFFFF"..v.."|r")
							break
						end
					end
					GameTooltip:AddLine(name)
				else
					GameTooltip:AddLine(self.visualInfo.visualID)
				end

			elseif selectedValue == LE_ITEM_LEVEL then
				local avg_ilvl, min_ilvl, max_ilvl = GetItemLevel(self.visualInfo.visualID)
				GameTooltip:AddLine(format(min_ilvl == max_ilvl and "%d" or "%d  [%d-%d]", avg_ilvl, min_ilvl, max_ilvl))

			elseif selectedValue == LE_ITEM_SOURCE then
				if self.visualInfo.isCollected then
					local item = CollectionWardrobeUtil.GetSortedAppearanceSources(self.visualInfo.visualID)[1]
					if item.sourceType == TRANSMOG_SOURCE_BOSS_DROP then
						local drops = C_TransmogCollection.GetAppearanceSourceDrops(item.sourceID)
						if #drops > 0 then
							local drop = format(WARDROBE_TOOLTIP_ENCOUNTER_SOURCE, drops[1].encounter, drops[1].instance)
							GameTooltip:AddLine(_G["TRANSMOG_SOURCE_"..item.sourceType]..": "..drop)
						end
					else
						GameTooltip:AddLine(item.sourceType and _G["TRANSMOG_SOURCE_"..item.sourceType] or UNKNOWN)
					end
				end
			elseif selectedValue == LE_VISUALID then
				GameTooltip:AddLine(FileData[self.visualInfo.visualID])
				GameTooltip:AddLine("|cffFFFFFF"..self.visualInfo.visualID.."|r")
			end
			GameTooltip:Show()
		end
	end
end

-- place differently for the transmogrifier / collections tab
local function PositionDropDown()
	if C_Transmog.IsAtTransmogNPC() then
		WardRobeSortDropdown:SetPoint("TOPLEFT", WardrobeCollectionFrame.ClassDropdown, "BOTTOMLEFT", 30, 20)
	else
		WardRobeSortDropdown:SetPoint("TOPLEFT", WardrobeCollectionFrame.ClassDropdown, "BOTTOMLEFT")
	end
end

local function CreateDropdown()
	local dropdown = CreateFrame("DropdownButton", "WardRobeSortDropdown", Wardrobe, "WowStyle2DropdownTemplate")
	local function IsSelected(value)
		return value == db.sortDropdown
	end
	local function SetSelected(value)
		db.sortDropdown = value
		db.reverse = IsModifierKeyDown()
		SortOrder = db.reverse and SortReverse or SortNormal
		Wardrobe:SortVisuals()
	end
	local t = {}
	for _, sortType in pairs(dropdownOrder) do
		table.insert(t, {L[sortType], sortType})
	end
	MenuUtil.CreateRadioMenu(dropdown,
		IsSelected,
		SetSelected,
		unpack(t)
	)
	return dropdown
end

-- only load once the wardrobe collections tab / transmogrifier is used
Wardrobe:HookScript("OnShow", function(self)
	if active then
		PositionDropDown()
		return
	else
		active = true
	end

	if not WardrobeSortDB or WardrobeSortDB.db_version < defaults.db_version then
		WardrobeSortDB = CopyTable(defaults)
	end
	db = WardrobeSortDB

	SortOrder = db.reverse and SortReverse or SortNormal

	f:RegisterEvent("TRANSMOG_COLLECTION_ITEM_UPDATE")
	f:SetScript("OnEvent", OnItemUpdate)

	local dropdown = CreateDropdown()
	PositionDropDown()

	-- sort and update
	hooksecurefunc(Wardrobe, "SortVisuals", function()
		-- exclude enchants/illusions by checking for category
		if self:GetActiveCategory() then
			sortFunc[db.sortDropdown](self)
			self:UpdateItems()
			UIDropDownMenu_EnableDropDown(dropdown)
		else
			UIDropDownMenu_DisableDropDown(dropdown)
		end
	end)

	-- show appearance information in tooltip
	for _, model in pairs(self.Models) do
		model:HookScript("OnEnter", Model_OnEnter)
	end

	-- update tooltip when scrolling
	Wardrobe:HookScript("OnMouseWheel", UpdateMouseFocus)

	-- reposition when the weapons dropdown is shown at the transmogrifier
	hooksecurefunc(Wardrobe, "UpdateWeaponDropdown", PositionDropDown)
end)
