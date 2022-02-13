-- Arcania 1.0 by Zaele

--
--- Todo
--

--[[
- small delay for hiding the xp bar on quest complete
- include details in it somehow
- find the right way to show bar 2 and 10 in friendly
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
ArcaniaFriendlyFrames = {
	"framename",
	...
}
ArcaniaRangeButton = "buttonname"
ArcaniaCooldowns = {
	{
		"btcooldown",
		"spellname"
	},
	...
}
ArcaniaShowMinimap = true
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
		if (UnitExists("target") and UnitIsFriend("player","target")) then
			frame:SetAlpha(1)
			if (unit == "player") then
				for index, name in ipairs(ArcaniaFriendlyFrames) do
					local frame = getglobal(name)
					if (frame) then
						frame:SetAlpha(1)
					end
				end
				MainMenuExpBar:Show()
				if (ArcaniaShowMinimap) then
					Minimap:Show()
				end
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
				for index, name in ipairs(ArcaniaFriendlyFrames) do
					local frame = getglobal(name)
					if (frame) then
						frame:SetAlpha(0)
					end
				end
				MainMenuExpBar:Hide()
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

local function UpdateCooldown(cooldown, spell, friendlyTarget)
	local start, duration, enabled = GetSpellCooldown(spell)
	local button = cooldown:GetParent()
	if (friendlyTarget) then
		button:SetAlpha(1)
	elseif (duration < 2.0 or cooldown:GetCooldownDuration() == 0) then
		button:SetAlpha(0)
	else
		button:SetAlpha(1)
	end
end

local function MonitorCooldowns()
	local friendlyTarget = UnitExists("target") and UnitIsFriend("player","target")
	for index, cooldown in ipairs(ArcaniaCooldowns) do
		local name = cooldown[1]
		local spell = cooldown[2]
		local button = getglobal(name)
		if (button) then
			UpdateCooldown(button, spell, friendlyTarget)
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
		if (not UnitIsFriend("player","target")) then
			if (IsSpellInRange("Fire Blast", "target") == 1) then
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
			if (range or UnitIsDeadOrGhost("target")) then
				range:SetAlpha(0)
			end
		end
	else
		if (range) then
			range:SetAlpha(0)
		end
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

	ArcaniaOptions = panel

	InterfaceOptions_AddCategory(panel)
end

--
--- Event
--

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
			if (ArcaniaFriendlyFrames == nil) then
				ArcaniaFriendlyFrames = {}
			end
			if (ArcaniaCooldowns == nil) then
				ArcaniaCooldowns = {}
			end
			if (ArcaniaShowMinimap == nil) then
				ArcaniaShowMinimap = false
			end

			SetupOptions()
		end
	elseif (event == "PLAYER_ENTERING_WORLD") then
		Minimap:Hide()
		C_Timer.After(5, function() MainMenuExpBar:Hide() end)
		CompactRaidFrameManager:Hide()
		RegisterWellness("player", ArcaniaPlayerFrame)
		RegisterWellness("pet", ArcaniaPlayerFrame)
		RegisterPartyWellness()
	elseif (event == "PLAYER_TARGET_CHANGED") then
		UpdateWellness("player", ArcaniaPlayerFrame)
		UpdatePartyWellness()
	elseif (event == "GROUP_ROSTER_UPDATE") then
		RegisterPartyWellness()
	elseif (event == "QUEST_DETAIL") then
		MainMenuExpBar:Show()
	elseif (event == "QUEST_FINISHED") then
		MainMenuExpBar:Hide()
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

if (not WoWRetail) then
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
	playerFrame:SetScript("OnEvent", PlayerEvent)
end

--
--- XP
--

local function xp()
end

--
--- Slash
--

SLASH_AR1 = "/ar"
SLASH_AR2 = "/arcania"
SlashCmdList["AR"] = function(msg)
	print("len " .. string.len(msg))
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
	print("Arcania not yet supported in Retail")
end
