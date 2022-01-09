-- Arcania 1.0 by Zaele

--
--- Todo
--

--[[
- only dim on low mana (not energy or rage or ...)
- in friendly mode i could disable the hidding the
  off cooldown icons so they can be moved around
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
]]


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
				frame:SetAlpha(wellnessAlpha)
				for index, name in ipairs(ArcaniaFriendlyFrames) do
					local frame = getglobal(name)
					if (frame) then
						frame:SetAlpha(0)
					end
				end
				MainMenuExpBar:Hide()
				Minimap:Hide()
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

local function UpdateCooldown(cooldown, spell)
	local start, duration, enabled = GetSpellCooldown(spell)
	local button = cooldown:GetParent()
	if (duration < 2.0 or cooldown:GetCooldownDuration() == 0) then
		button:SetAlpha(0)
	else
		button:SetAlpha(1)
	end
end

local function MonitorCooldowns()
	for index, cooldown in ipairs(ArcaniaCooldowns) do
		local name = cooldown[1]
		local spell = cooldown[2]
		local button = getglobal(name)
		if (button) then
			UpdateCooldown(button, spell)
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
-- Event
--

local function PlayerEvent(self, event, ...)
	if (event == "ADDON_LOADED") then
		local name = ...
		if (name == "Arcania") then
			if (not ArcaniaFriendlyFrames) then
				ArcaniaFriendlyFrames = {}
			end
			if (not ArcaniaCooldowns) then
				ArcaniaCooldowns = {}
			end
		end
	elseif (event == "PLAYER_ENTERING_WORLD") then
		Minimap:Hide()
		C_Timer.After(5, function() MainMenuExpBar:Hide() end)
		CompactRaidFrameManager:Hide()
		RegisterWellness("player", ArcaniaPlayerFrame)
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
-- Update
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
-- Frame
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
playerFrame:SetScript("OnEvent", PlayerEvent)

--
-- Slash
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

--
-- Welcome
--

print('Arcania ready!')
