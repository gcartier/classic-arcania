-- Arcania 1.0 by Zaele

--
--- Todo
--

--[[
fix flicker when drinking after oom

maybe show the frostbolt icon when an ennemy
target that is out-of-distance is selected!?
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
--- Wellness
--

local function UpdateWellness(unit, framename)
	local healthMax = UnitHealthMax(unit)
	local health = UnitHealth(unit)
	local healthAlpha = (healthMax - health) / healthMax
	
	local powerMax = UnitPowerMax(unit)
	local power = UnitPower(unit)
	local powerAlpha = (powerMax - power) / powerMax
	
	local wellnessAlpha = math.max(healthAlpha, powerAlpha)

	frame = getglobal(framename)
	-- quicky to fix
	if (frame) then
	  	frame:SetAlpha(wellnessAlpha)
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

local function RegisterPartyWellness()
	local num = GetNumGroupMembers()
	if (num > 0) then
		for i = 1, num - 1 do
			local unit = "party"..i
			if (not wellnessFrames[unit]) then
				RegisterWellness(unit, "LUFHeaderpartyUnitButton"..i)
			end
		end
	end
end

--
--- Cooldown
--

local FireBlast = 2137
local FrostNova = 122

local function WatchCooldown(cooldown, spell)
	local start, duration, enabled = GetSpellCooldown(spell)
	local button = cooldown:GetParent()
	if (duration < 2.0 or cooldown:GetCooldownDuration() == 0) then
		button:SetAlpha(0)
	else
		button:SetAlpha(1)
	end
end

local function MonitorCooldowns()
	if (BT4Button24Cooldown) then
		WatchCooldown(BT4Button24Cooldown, FireBlast)
	end
	if (BT4Button109Cooldown) then
		WatchCooldown(BT4Button109Cooldown, FrostNova)
	end
end

--
--- Distance
--

local function CheckDistance()
	if (UnitExists("target")) then
		if (not UnitIsFriend("player","target")) then
			if (IsSpellInRange("Fire Blast", "target") == 1) then
				LUFUnittarget:SetAlpha(0)
			else
				LUFUnittarget:SetAlpha(1)
			end
		else
			LUFUnitplayer:SetAlpha(1)
			LUFUnittarget:SetAlpha(1)
		end
	else
		UpdateWellness("player", "LUFUnitplayer")
	end
end

--
-- Event
--

local function PlayerEvent(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		Minimap:Hide()
		RegisterWellness("player", "LUFUnitplayer")
		RegisterPartyWellness()
	elseif (event == "GROUP_ROSTER_UPDATE") then
		RegisterPartyWellness()
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
playerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
playerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
playerFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
playerFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
playerFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
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
