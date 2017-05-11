-- Author: Ketho (EU-Boulderfist)
-- License: Public Domain

local f = CreateFrame("Frame")
local Wardrobe = WardrobeCollectionFrame.ItemsCollectionFrame

local db, active
local FileData

local nameVisuals, nameCache = {}, {}
local catCompleted, itemLevels = {}, {}
local unknown = {-1}

local LE_DEFAULT = 1
local LE_APPEARANCE = 2
local LE_ITEM_LEVEL = 3
local LE_ALPHABETIC = 4

local L = {
	[LE_DEFAULT] = DEFAULT,
	[LE_APPEARANCE] = APPEARANCE_LABEL,
	[LE_ITEM_LEVEL] = STAT_AVERAGE_ITEM_LEVEL,
	[LE_ALPHABETIC] = COMPACT_UNIT_FRAME_PROFILE_SORTBY_ALPHABETICAL,
}

local defaults = {
	db_version = 1,
	sortDropdown = LE_DEFAULT,
}

local function LoadFileData(addon)
	local loaded, reason = LoadAddOn(addon)
	if not loaded then
		if reason == "DISABLED" then
			EnableAddOn(addon, true)
			LoadAddOn(addon)
		else
			error(addon..": "..reason)
		end
	end
	return _G[addon]:GetFileData()
end

local ItemCache = setmetatable({}, {__index = function(t, k)
	wipe(itemLevels)
	local sum, v = 0
	
	-- can return source ids for non-existing items
	for _, source in pairs(C_TransmogCollection.GetAllAppearanceSources(k)) do
		local link = select(6, C_TransmogCollection.GetAppearanceSourceInfo(source))
		local ilvl = select(4, GetItemInfo(link))
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

local function SortAlphabetic()
	if Wardrobe:IsVisible() then
		sort(Wardrobe:GetFilteredVisualsList(), function(source1, source2)
			if nameVisuals[source1.visualID] and nameVisuals[source2.visualID] then
				return nameVisuals[source1.visualID] < nameVisuals[source2.visualID]
			else
				return source1.visualID < source2.visualID
			end
		end)
		Wardrobe:UpdateItems()
	end
end

-- takes around 5 to 30 onupdates
local function CacheHeaders()
	for k in pairs(nameCache) do
		-- oh my god so much wasted tables
		local appearances = WardrobeCollectionFrame_GetSortedAppearanceSources(k)
		if appearances[1].name then
			nameVisuals[k] = appearances[1].name
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
				return FileData[source1.visualID]:lower() < FileData[source2.visualID]:lower()
			else
				return source1.visualID < source2.visualID
			end
		end)
	end,
	
	[LE_ITEM_LEVEL] = function(self)
		-- wardrobe can be closed while caching was in progress
		if self:IsVisible() then
			sort(self:GetFilteredVisualsList(), function(source1, source2)
				local itemLevel1 = GetItemLevel(source1.visualID)
				local itemLevel2 = GetItemLevel(source2.visualID)
				
				if itemLevel1 ~= itemLevel2 then
					return itemLevel1 < itemLevel2
				else
					return source1.visualID < source2.visualID
				end
			end)
		end
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
}

-- sort again when we are sure all items are cached
-- not the most efficient way to do this
local function SortItemLevelEvent()
	if Wardrobe:IsVisible() then
		if Lib_UIDropDownMenu_GetSelectedValue(WardRobeSortDropDown) == LE_ITEM_LEVEL then
			sortFunc[db.sortDropdown](Wardrobe)
			Wardrobe:UpdateItems()
		end
	end
end

local function Model_OnEnter(self)
	if Wardrobe:GetActiveCategory() then
		local selectedValue = Lib_UIDropDownMenu_GetSelectedValue(WardRobeSortDropDown)
		if selectedValue == LE_APPEARANCE then
			if FileData[self.visualInfo.visualID] then
				GameTooltip:AddLine(FileData[self.visualInfo.visualID])
			end
		elseif selectedValue == LE_ITEM_LEVEL then
			local avg_ilvl, min_ilvl, max_ilvl = GetItemLevel(self.visualInfo.visualID)
			GameTooltip:AddLine(format(min_ilvl == max_ilvl and "%d" or "%d  [%d-%d]", avg_ilvl, min_ilvl, max_ilvl))
		end
		GameTooltip:Show()
	end
end

-- place differently for the transmogrifier / collections tab
local function PositionDropDown()
	if WardrobeFrame_IsAtTransmogrifier() then
		local _, isWeapon = C_TransmogCollection.GetCategoryInfo(Wardrobe:GetActiveCategory() or -1)
		WardRobeSortDropDown:SetPoint("TOPLEFT", Wardrobe.WeaponDropDown, "BOTTOMLEFT", 0, isWeapon and 55 or 32)
	else
		WardRobeSortDropDown:SetPoint("TOPLEFT", Wardrobe.WeaponDropDown, "BOTTOMLEFT", 0, 5)
	end
end

local function CreateDropdown()
	local dropdown = CreateFrame("Frame", "WardRobeSortDropDown", Wardrobe, "Lib_UIDropDownMenuTemplate")
	Lib_UIDropDownMenu_SetWidth(dropdown, 140)
	
	Lib_UIDropDownMenu_Initialize(dropdown, function(self)
		local selectedValue = Lib_UIDropDownMenu_GetSelectedValue(self)
		local info = Lib_UIDropDownMenu_CreateInfo()
		
		info.func = function(self)
			db.sortDropdown = self.value
			Lib_UIDropDownMenu_SetSelectedValue(dropdown, self.value)
			Lib_UIDropDownMenu_SetText(dropdown, COMPACT_UNIT_FRAME_PROFILE_SORTBY.." "..L[self.value])
			Wardrobe:SortVisuals()
		end
		
		for index, name in ipairs(L) do
			info.value, info.text = index, name
			info.checked = (index == selectedValue)
			Lib_UIDropDownMenu_AddButton(info)
		end
	end)
	
	-- apply db
	Lib_UIDropDownMenu_SetSelectedValue(dropdown, db.sortDropdown)
	Lib_UIDropDownMenu_SetText(dropdown, COMPACT_UNIT_FRAME_PROFILE_SORTBY.." "..L[db.sortDropdown])
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
	
	f:RegisterEvent("TRANSMOG_COLLECTION_ITEM_UPDATE")
	f:SetScript("OnEvent", SortItemLevelEvent)
	
	local dropdown = CreateDropdown()
	PositionDropDown()
	
	-- sort and update
	hooksecurefunc(Wardrobe, "SortVisuals", function()
		-- exclude enchants/illusions by checking for category
		if self:GetActiveCategory() then
			sortFunc[db.sortDropdown](self)
			self:UpdateItems()
			Lib_UIDropDownMenu_EnableDropDown(dropdown)
		else
			Lib_UIDropDownMenu_DisableDropDown(dropdown)
		end
	end)
	
	-- show appearance information in tooltip
	for _, model in pairs(self.Models) do
		model:HookScript("OnEnter", Model_OnEnter)
	end
	
	-- update tooltip when scrolling
	Wardrobe:HookScript("OnMouseWheel", function()
		local focus = GetMouseFocus()
		if focus and focus:GetObjectType() == "DressUpModel" then
			focus:GetScript("OnEnter")(focus)
		end
	end)
	
	-- reposition when the weapons dropdown is shown at the transmogrifier
	hooksecurefunc(Wardrobe, "UpdateWeaponDropDown", PositionDropDown)
end)
