-- Arcania 1.0 by Zaele

--
--- Todo
--

--[[
- small delay for hiding the xp bar on quest complete
- include details in it somehow
- find the right way to implement friendly target
- review the pet wellness code
- pet bar
]]

--
--- Lua
--

--[[
/fstack : Shows a Z-ordered (I think) list of all the UI frames under the cursor
/etrace : Shows a running commentary of game events (and the parameters passed to them) as they happen
/dump : Just dumps a variable's value to chat. This works better than print for tables.
/script : Anything following this will executed immediately as Lua code.
/console scriptErrors 1
/tinspect or /tinspect sometable or /tinspect UIParent to see all toplevel frames

debugstack()
print("HELLO")
message('Arcania ready!')
RaidNotice_AddMessage(RaidBossEmoteFrame, "GOGOGO!!!", ChatTypeInfo["RAID_WARNING"])
tostring(expr)
type(expr)
ReloadUI()

lua supports inner functions

- strings are interned
- indexing starts at 1
- tables have a vector part and a hashed part the vector part
  used when you index the table with small integers
- #t returns the vector part length
- t.a is syntactic sugar for t["a"]
- specId, specName = expr for multiple values
]]

--
--- Variables
--

--[[
ArcaniaPlayerFrame = "framename"
ArcaniaTargetFrame = "framename"
ArcaniaMemberFrame = "framename"
ArcaniaCooldownBars = {
	"barname",
	...
}
ArcaniaFriendlyBars = {
	"barname",
	...
}
ArcaniaRangeButton = "buttonname"
ArcaniaShowMinimap = <boolean>
ArcaniaShowQuestTracker = <boolean>
ArcaniaShowCompass = <boolean>
]]

--
--- Version
--

local WoWClassic = false
local WoWTBC = false
local WoWRetail = false
local WoWVersion = select(4, GetBuildInfo())

if WoWVersion < 20000 then
	WoWClassic = true
elseif WoWVersion < 30000 then 
	WoWTBC = true
else
	WoWRetail = true
end

--
--- Wellness
--

local function UpdateWellness(unit, framename)
	-- some frames are created lazily
	local frame = getglobal(framename)
	if (frame) then
		if (UnitExists("target") and UnitIsPlayer("target")) then
			frame:SetAlpha(1)
			for index, name in ipairs(ArcaniaCooldownBars) do
				local bar = getglobal(name)
				if (bar) then
					bar:SetClickThrough(false)
				end
			end
			for index, name in ipairs(ArcaniaFriendlyBars) do
				local bar = getglobal(name)
				if (bar) then
					bar:SetAlpha(1)
				end
			end
			if (ArcaniaShowQuestTracker) then
				ObjectiveTrackerFrame:Show()
			end
			if (ArcaniaShowCompass) then
				Compass:Show()
			end
			BT4StatusBarTrackingManager:Show()
			if (ArcaniaShowMinimap) then
				Minimap:Show()
			end
		else
			local healthMax = UnitHealthMax(unit)
			local health = UnitHealth(unit)
			local healthAlpha = (healthMax - health) / healthMax
	
			local wellnessAlpha
			if (UnitPowerType(unit) == 0) then
				local powerMax = UnitPowerMax(unit)
				local power = UnitPower(unit)
				local powerAlpha = (powerMax - power) / powerMax
				wellnessAlpha = math.max(healthAlpha, powerAlpha)
			else
				wellnessAlpha = healthAlpha
			end

			if (unit == "player") then
				if (UnitExists("pet")) then
					local petHealthMax = UnitHealthMax("pet")
					local petHealth = UnitHealth("pet")
					local petHealthAlpha = (petHealthMax - petHealth) / petHealthMax
					wellnessAlpha = math.max(wellnessAlpha, petHealthAlpha)
				end
				frame:SetAlpha(wellnessAlpha)
				for index, name in ipairs(ArcaniaCooldownBars) do
					local bar = getglobal(name)
					if (bar) then
						bar:SetClickThrough(true)
					end
				end
				for index, name in ipairs(ArcaniaFriendlyBars) do
					local bar = getglobal(name)
					if (bar) then
						bar:SetAlpha(0)
					end
				end
				if (ArcaniaShowQuestTracker) then
					ObjectiveTrackerFrame:Hide()
				end
				if (ArcaniaShowCompass) then
					Compass:Hide()
				end
				BT4StatusBarTrackingManager:Hide()
				if (ArcaniaShowMinimap) then
					Minimap:Hide()
				end
			else
				frame:SetAlpha(.2 + wellnessAlpha * .8)
			end
		end
	end
end

local function WellnessEvent(self, event, ...)
	local unit = ...
	UpdateWellness(unit, self.framename)
end

local wellnessFrames = {}

local function RegisterWellness(unit, framename)
	local wellnessFrame = CreateFrame("frame")
	wellnessFrame:RegisterUnitEvent("UNIT_HEALTH", unit)
	wellnessFrame:RegisterUnitEvent("UNIT_MAXHEALTH", unit)
	wellnessFrame:RegisterUnitEvent("UNIT_POWER_FREQUENT", unit)
	wellnessFrame:RegisterUnitEvent("UNIT_MAXPOWER", unit)
	wellnessFrame:SetScript("OnEvent", WellnessEvent)
	wellnessFrame.framename = framename
	wellnessFrames[unit] = wellnessFrame
	UpdateWellness(unit, framename)
end

local function UpdatePartyWellness()
	local num = GetNumGroupMembers()
	if (num > 0) then
		for i = 1, num - 1 do
			local unit = "party"..i
			if (wellnessFrames[unit]) then
				UpdateWellness(unit, ArcaniaMemberFrame..i)
			end
		end
	end
end

local function RegisterPartyWellness()
	local num = GetNumGroupMembers()
	if (num > 0) then
		for i = 1, num - 1 do
			local unit = "party"..i
			if (not wellnessFrames[unit]) then
				RegisterWellness(unit, ArcaniaMemberFrame..i)
			end
		end
	end
end

--
--- Cooldown
--

local function UpdateCooldown(button, selfTarget)
	local cooldown = button.cooldown
	local start, duration = cooldown:GetCooldownTimes()
	if (selfTarget) then
		button:SetAlpha(1)
	elseif (duration < 2000 or cooldown:GetCooldownDuration() == 0) then
		button:SetAlpha(0)
	else
		button:SetAlpha(1)
	end
end

local function MonitorCooldowns()
	local selfTarget = UnitExists("target") and UnitIsPlayer("target")
	for index, name in ipairs(ArcaniaCooldownBars) do
		local bar = getglobal(name)
		if (bar) then
			for _, button in bar:GetAll() do
				if (button:HasAction()) then
					UpdateCooldown(button, selfTarget)
				end
			end
		end
	end
end

--
--- Distance
--

local function CheckDistance()
	local range = nil
	if (ArcaniaRangeButton) then
		range = getglobal(ArcaniaRangeButton)
	end
	
	if (UnitExists("target")) then
		if (not UnitIsFriend("player", "target")) then
			if (IsSpellInRange("Torment", "target") == 1) then
				local classif = UnitClassification("target")
				if (classif == "worldboss" or classif == "rareelite" or classif == "elite" or classif == "rare") then
					getglobal(ArcaniaTargetFrame):SetAlpha(1)
				else
					getglobal(ArcaniaTargetFrame):SetAlpha(0)
				end
				if (range) then
					range:SetAlpha(0)
				end
			else
				getglobal(ArcaniaTargetFrame):SetAlpha(1)
				if (range) then
					if (UnitIsDeadOrGhost("target")) then
						range:SetAlpha(0)
					else
						range:SetAlpha(1)
					end
				end
			end
		else
			getglobal(ArcaniaTargetFrame):SetAlpha(1)
			if (range) then
				if (UnitIsDeadOrGhost("target")) then
					range:SetAlpha(0)
				else
					range:SetAlpha(1)
				end
			end
		end
	else
		if (range) then
			range:SetAlpha(0)
		end
	end
end

--
--- Camera
--

function ToggleCompass()
	if IsCompassVisible() then
		HideCompass()
	else
		ShowCompass()
	end
end

function ToggleMouseLook()
	if not IsMouselooking() then
		MouselookStart()
	else
		MouselookStop()
	end
end

--
--- Quest
--

function ToggleQuestTracker()
	if ObjectiveTrackerFrame:IsVisible() then
		ObjectiveTrackerFrame:Hide()
	else
		ObjectiveTrackerFrame:Show()
	end
end

--
--- Options
--

local function SetupOptions()
	local panel = CreateFrame("Frame")
	panel.name = "Arcania"

	local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	cb:SetPoint("TOPLEFT", 20, -20)
	cb.Text:SetText("Show Minimap")
	cb:SetChecked(ArcaniaShowMinimap)
	cb:SetScript("OnClick", function()
		ArcaniaShowMinimap = cb:GetChecked()
	end)

	cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	cb:SetPoint("TOPLEFT", 20, -50)
	cb.Text:SetText("Show Quest Tracker")
	cb:SetChecked(ArcaniaShowQuestTracker)
	cb:SetScript("OnClick", function()
		ArcaniaShowQuestTracker = cb:GetChecked()
	end)

	cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	cb:SetPoint("TOPLEFT", 20, -80)
	cb.Text:SetText("Show Compass")
	cb:SetChecked(ArcaniaShowCompass)
	cb:SetScript("OnClick", function()
		ArcaniaShowCompass = cb:GetChecked()
	end)

	ArcaniaOptions = panel

	InterfaceOptions_AddCategory(panel)
end

--
--- Bindings
--

local function SetupKeyBindings()
	BINDING_HEADER_ARCANIA_CAMERA = "Camera"
	BINDING_HEADER_ARCANIA_QUEST = "Quest"
end

--
--- Event
--

local sfxVolume

local function PlayerEvent(self, event, ...)
	if (event == "ADDON_LOADED") then
		local name = ...
		if (name == "Arcania") then
			if (ArcaniaPlayerFrame == nil) then
				ArcaniaPlayerFrame = "PlayerFrame"
			end
			if (ArcaniaTargetFrame == nil) then
				ArcaniaTargetFrame = "TargetFrame"
			end
			if (ArcaniaMemberFrame == nil) then
				ArcaniaMemberFrame = "PartyMemberFrame"
			end
			if (ArcaniaCooldownBars == nil) then
				ArcaniaCooldownBars = {}
			end
			if (ArcaniaFriendlyBars == nil) then
				ArcaniaFriendlyBars = {}
			end
			if (ArcaniaShowMinimap == nil) then
				ArcaniaShowMinimap = false
			end
			if (ArcaniaShowQuestTracker == nil) then
				ArcaniaShowQuestTracker = false
			end
			if (ArcaniaShowCompass == nil) then
				ArcaniaShowCompass = false
			end

			SetupOptions()
			SetupKeyBindings()
		end
	elseif (event == "PLAYER_ENTERING_WORLD") then
		Minimap:Hide()
		Compass:Hide()
		ObjectiveTrackerFrame:Hide()
		C_Timer.After(5, function()
			BT4StatusBarTrackingManager:Hide()
		end)
		CompactRaidFrameManager:Hide()
		RegisterWellness("player", ArcaniaPlayerFrame)
		RegisterWellness("pet", ArcaniaPlayerFrame)
		RegisterPartyWellness()
	elseif (event == "PLAYER_REGEN_ENABLED") then
		if sfxVolume then
			SetCVar("Sound_SFXVolume", sfxVolume)
		end
	elseif (event == "PLAYER_REGEN_DISABLED") then
		sfxVolume = GetCVar("Sound_SFXVolume")
		SetCVar("Sound_SFXVolume", sfxVolume / 2)
	elseif (event == "PLAYER_TARGET_CHANGED") then
		UpdateWellness("player", ArcaniaPlayerFrame)
		UpdatePartyWellness()
	elseif (event == "GROUP_ROSTER_UPDATE") then
		RegisterPartyWellness()
	-- elseif (event == "QUEST_DETAIL") then
	-- 	MainMenuExpBar:Show()
	-- elseif (event == "QUEST_FINISHED") then
	-- 	MainMenuExpBar:Hide()
	-- elseif (event == "UNIT_SPELLCAST_SUCCEEDED") then
	-- 	local arg1, arg2, arg3 = ...
	-- 	local lowered = "Interface\\AddOns\\Arcania\\lowered\\"
	-- 	print(arg3)
	-- 	if arg3 == 195072 then
	-- 		PlaySoundFile(lowered .. "Spell_DH_FelRush_Cast_0" .. math.random(3) .. ".ogg")
	-- 	elseif arg3 == 162243 then
	-- 		PlaySoundFile(lowered .. "Spell_DH_DemonBite_Cast_0" .. math.random(5) .. ".ogg")
	-- 	end
	end

	MonitorCooldowns()
end

--
--- Update
--

local timer = 0
local function Update(_, elapsed)
	timer = timer + elapsed

	if (timer >= .15) then
		MonitorCooldowns()
		CheckDistance()

		timer = 0
	end
end

--
--- Frame
--

local updateFrame = CreateFrame("frame")
updateFrame:SetScript("OnUpdate", Update)

local playerFrame = CreateFrame("frame")
playerFrame:RegisterEvent("ADDON_LOADED")
playerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
playerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
playerFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
playerFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
playerFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
playerFrame:RegisterEvent("QUEST_DETAIL")
playerFrame:RegisterEvent("QUEST_FINISHED")
playerFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
playerFrame:SetScript("OnEvent", PlayerEvent)

-- felrush
-- MuteSoundFile(1361050)
-- MuteSoundFile(1361051)
-- MuteSoundFile(1361052)
-- demonbite
-- MuteSoundFile(1278546)
-- MuteSoundFile(1278547)
-- MuteSoundFile(1278548)
-- MuteSoundFile(1278549)
-- MuteSoundFile(1278550)

--
--- Debug
--

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. tostring(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

--
--- XP
--

local function xp()
--[[
	for i=1,10 do
		local unitid = "nameplate" .. tostring(i)
		local plate = C_NamePlate.GetNamePlateForUnit(unitid)
		if not plate then
			return
		end
		local isTarget = UnitIsUnit("target", unitid)
		local inCombat = UnitAffectingCombat(unitid)
		local target = isTarget and " target" or ""
		local combat = inCombat and " combat" or ""
		print(unitid .. target .. combat)
	end
]]
	local GetNumQuestLogEntries = C_QuestLog.GetNumQuestLogEntries
	local GetQuestLogTitle = C_QuestLog.GetTitleForLogIndex
	local numQuests = GetNumQuestLogEntries();
	for i = 1, numQuests do
		local info = C_QuestLog.GetInfo(i)
		local questID = info["questID"]
		print(questID)
		-- local _, x, y = QuestPOIGetIconInfo(questID);
	end
--[[
	local questID = C_SuperTrack.GetSuperTrackedQuestID()
	if questID then
		print(C_QuestLog.GetTitleForQuestID(questID))
		print(GetQuestExpansion(questID))
		print(GetQuestUiMapID(questID))
		completed, posX, posY, objective = QuestPOIGetIconInfo(questID)
		print(posX)
		print(posY)
		print(objective)
		print(C_QuestLog.GetLogIndexForQuestID(questID))
		distanceSq, onContinent = C_QuestLog.GetDistanceSqToQuest(questID)
		print(distanceSq)
	end
]]
end

-- /run PlaySoundFile(1361050)
-- /run PlaySoundFile("Interface\\AddOns\\Arcania\\sound\\spells\\spell_dh_felrush_cast_01.ogg")
-- /run PlaySoundFile("Interface\\AddOns\\Arcania\\lowered\\spell_dh_felrush_cast_01.ogg")

--
--- Slash
--

SLASH_AR1 = "/ar"
SLASH_AR2 = "/arcania"
SlashCmdList["AR"] = function(msg)
		InterfaceOptionsFrame_OpenToCategory(ArcaniaOptions)
	end

SLASH_RL1 = "/rl"
SlashCmdList["RL"] = function(msg)
		ReloadUI()
	end

SLASH_CL1 = "/cl"
SlashCmdList["CL"] = function(msg)
		ChatFrame1:Clear()
	end

SLASH_XP1 = "/xp"
SlashCmdList["XP"] = function(msg)
		xp()
	end

--
--- Welcome
--

if (WoWClassic) then
	print('Arcania Classic ready!')
elseif (WoWTBC) then
	print('Arcania TBC ready!')
else
	print('Arcania Retail ready!')
end
