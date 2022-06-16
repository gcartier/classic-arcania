local Addon = CreateFrame("FRAME")

local compass
local compassEnabled = false
local compassVisible = false

local questPointsTable = {}

local pi = math.pi
local halfPi = pi/2
local quarterPi = pi/4
local threeHalfPi = 3*pi/2
local twoPi = 2*pi

local fiveQuarterPi = 5*pi/4
local threeQuarterPi = 3*pi/4
local sevenQuarterPi = 7*pi/4

local floor = math.floor
local sqrt = math.sqrt
local arccos = math.acos
local arctan2 = math.atan2

local pairs = pairs
local select = select

local GetPlayerFacing = GetPlayerFacing
local GetPlayerMapPosition = GetPlayerMapPosition

local playerX, playerY
local playerAngle = 0


-- Compatibility

local GetNumQuestLogEntries = C_QuestLog.GetNumQuestLogEntries
local GetQuestLogInfo = C_QuestLog.GetInfo
local GetDistanceSqToQuest = C_QuestLog.GetDistanceSqToQuest
local GetQuestLogIndexByID = C_QuestLog.GetLogIndexForQuestID
local GetSuperTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID


-- TODO
-- far away icons are smaller

-- Attention
-- Use coordinates to get angle, not to get distance
-- For distance use GetDistanceSqToQuest - a lot more precise


--
--- Useful functions
--

local function round(num, idp)
	local mult = 10^(idp or 0)
	return floor(num * mult + 0.5) / mult
end

local function createCardinalDirection(direction)
	local fontFrame = CreateFrame("FRAME", "Compass"..direction, compass)

	fontFrame:SetSize(680, 30)
	fontFrame:SetPoint("CENTER")

	fontFrame.font = compass:CreateFontString("Compass"..direction.."Font", "ARTWORK", "GameFontNormal")
	fontFrame.font:SetFont("Interface\\AddOns\\Arcania\\media\\Baron Neue.otf", 21)
	fontFrame.font:SetTextColor(1, 1, 1, 1)
	fontFrame.font:SetText(direction)
	fontFrame.font:SetPoint("CENTER", fontFrame, "CENTER", 0, -21)

	return fontFrame
end

local function getPlayerXY()
    local Id = C_Map.GetBestMapForUnit("player")
    local pos = C_Map.GetPlayerMapPosition(Id, "player")
    for k,v in pairs (pos) do
        if k == "x"  then
            x = v
        else if k == "y" then
                y = v
                return x, y
            end
        end
    end
end

local function createQuestIcon(questID)
	local questFrame = CreateFrame("FRAME", "CompassQuestFrame"..questID, compass)
	local index = GetQuestLogIndexByID(questID)
	 
	questFrame.questID = questID
	questFrame:SetSize(50, 50)
	questFrame:SetPoint("CENTER")
	questFrame.texture = questFrame:CreateTexture("CompassQuestFrame"..questID.."Texture")
		
	questFrame.texture:SetAllPoints(questFrame)
	questFrame.texture:SetTexture("Interface\\AddOns\\Arcania\\media\\questIcon.blp")
	questFrame.texture:SetBlendMode("BLEND")
	questFrame.texture:SetVertexColor(1, 1, 1, 1)
	questFrame.texture:SetDrawLayer("OVERLAY", 5)

	questFrame:SetFrameStrata("HIGH")

	questFrame:Hide()
	
	questFrame:SetScript("OnEvent", function(self, event)
		if not select(2,QuestPOIGetIconInfo(self.questID)) then
			questPointsTable[self.questID] = nil
			questFrame:Hide()
		end
	end)

	questFrame:RegisterEvent("QUEST_LOG_UPDATE")
	
	return questFrame
end

local function createCompass()
	compass = CreateFrame("FRAME", "Compass", UIParent)

	compass:SetSize(1024, 128)
	compass:SetPoint("TOP", 0, 36)

	compass.texture = compass:CreateTexture("CompassBg")
	compass.texture:SetAllPoints(compass)
	compass.texture:SetTexture("Interface\\AddOns\\Arcania\\media\\compass.blp")
	compass.texture:SetBlendMode("BLEND")
	compass.texture:SetVertexColor(0.8, 0.8, 0.8, 1)

	compass.north = createCardinalDirection("N")
	compass.south = createCardinalDirection("S")
	compass.west = createCardinalDirection("W")
	compass.east = createCardinalDirection("E")
end

local function getPlayerPosition()
	local x, y = getPlayerXY()
	return round(x*100,3), round(y*100,3) -- , GetZoneText()
end

-- you can also get the distance in yards with GetDistanceSqToQuest(questID)
-- used to measure angles
local function getDistanceTo(x, y)
	return sqrt((x-playerX)^2+(y-playerY)^2)
end

local function getPlayerFacing()
	local angle = threeHalfPi-GetPlayerFacing()
	if angle < 0 then
		return angle + twoPi
	end
	return angle
end

-- angle to a certain point
local function getPlayerFacingAngle(x, y)
	local angle = arctan2(x-playerX, y-playerY)

	if angle > halfPi then
		angle = angle-halfPi
	else
		angle = halfPi-angle
	end
	
	-- 3rd quarter
	-- if playerX > x and playerY > y then
	-- 4th quarter
	if playerX < x and playerY > y then
		angle = twoPi-angle
		if angle > threeHalfPi and playerAngle < halfPi then
			angle = angle - twoPi
		end
		-- 2nd quarter
	-- elseif playerX > x and playerY < y then
		-- 1st quarter
	elseif playerX < x and playerY < y then
		if playerAngle > threeHalfPi then
			playerAngle = playerAngle - twoPi
		end
	end

	return angle-playerAngle
end	

local function hideOtherCardinals(cardinal)
	compass.north.font:Hide()
	compass.south.font:Hide()
	compass.west.font:Hide()
	compass.east.font:Hide()
	cardinal.font:Show()
end

local function setCardinalDirections()
	if playerAngle < quarterPi then
		compass.east:SetPoint("CENTER", compass, "CENTER", (-playerAngle)*210*2, 0)
		hideOtherCardinals(compass.east)
	elseif playerAngle > sevenQuarterPi then
		compass.east:SetPoint("CENTER", compass, "CENTER", (twoPi-playerAngle)*210*2, 0)
		hideOtherCardinals(compass.east)
	elseif playerAngle < threeQuarterPi and playerAngle > quarterPi then
		compass.south:SetPoint("CENTER", compass, "CENTER", (halfPi-playerAngle)*210*2, 0)
		hideOtherCardinals(compass.south)
	elseif playerAngle < fiveQuarterPi and playerAngle > threeQuarterPi then
		compass.west:SetPoint("CENTER", compass, "CENTER", (pi-playerAngle)*210*2, 0)
		hideOtherCardinals(compass.west)
	else
		compass.north:SetPoint("CENTER", compass, "CENTER", (threeHalfPi-playerAngle)*210*2, 0)
		hideOtherCardinals(compass.north)
	end
end

local function setQuestsIcons()
	for questID, table in pairs(questPointsTable) do
		if questID == GetSuperTrackedQuestID() then
			if table.frame then
				local angle = getPlayerFacingAngle(table.x, table.y)
				if angle < quarterPi and angle > -quarterPi then
					table.frame:SetPoint("CENTER", compass, "CENTER", angle*210*2, 0)
					
					local factor = 100 -- table.dist
					if(factor > 100) then
						factor = 100
					end
					table.frame:SetSize(50-factor/5, 50-factor/5)
					table.frame:Show()
				else
					table.frame:Hide()
				end
			end
		else
			if table.frame then
				local angle = getPlayerFacingAngle(table.x, table.y)
				if angle < quarterPi and angle > -quarterPi then
					table.frame:SetPoint("CENTER", compass, "CENTER", angle*210*2, 0)
					
					local factor = 100 -- table.dist
					if(factor > 100) then
						factor = 100
					end
					table.frame:SetSize(50-factor/5, 50-factor/5)
					table.frame:Hide()
				else
					table.frame:Hide()
				end
			end
		end
	end
end

local function updateQuestDistances()
	local numLines, numQuests = GetNumQuestLogEntries()
	for i = 1, numLines do
		local questID = GetQuestLogInfo(i)["questID"]
		local _, x, y = QuestPOIGetIconInfo(questID)
		if x then
			if questPointsTable[questID] then
    			questPointsTable[questID].dist = sqrt(GetDistanceSqToQuest(questID))
    		end
		end
	end
end

local function UpdateCompassEnabled()
	if GetPlayerFacing() then
		if not compassEnabled then
			compassEnabled = true
			if compassVisible then
				compass:Show()
			end
		end
	else
		if compassEnabled then
			compassEnabled = false
			if compassVisible then
				compass:Hide()
			end
		end
	end
end

function IsCompassVisible()
	return compass:IsVisible()
end

function ShowCompass()
	if compassEnabled then
		compass:Show()
	end
	compassVisible = true
end

function HideCompass()
	if compassEnabled then
		compass:Hide()
	end
	compassVisible = false
end

local total = 0
Addon:SetScript("OnUpdate", function(self, elapsed)
	UpdateCompassEnabled()
	if compassEnabled and compassVisible then
		total = total + elapsed
		if total > 0.02 then
			total = 0
			playerAngle = getPlayerFacing()
			playerX, playerY = getPlayerPosition()
			updateQuestDistances()
			setCardinalDirections()
			setQuestsIcons()
		end
	end
end)

Addon:SetScript("OnEvent", function(self, event, ...)
	if event == "QUEST_LOG_UPDATE" or event == "QUEST_ACCEPTED" or event == "QUEST_POI_UPDATE" or event == "ZONE_CHANGED" then
		local numLines, numQuests = GetNumQuestLogEntries()
		for i = 1, numLines do
			local questID = GetQuestLogInfo(i)["questID"]
			local _, x, y = QuestPOIGetIconInfo(questID)
			if x then
				local distanceSq = GetDistanceSqToQuest(questID)
				if distanceSq then
					if type(questPointsTable[questID]) ~= "table" then
						questPointsTable[questID] = {}
					end
					
   				questPointsTable[questID].x = x*100
   				questPointsTable[questID].y = y*100
   				questPointsTable[questID].dist = sqrt(distanceSq)

   				if not questPointsTable[questID].frame then
   					questPointsTable[questID].frame = createQuestIcon(questID)
   				end
   			end
			end
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		if GetPlayerFacing() then
			playerX, playerY = getPlayerPosition()
			playerAngle = getPlayerFacing()
		end
	elseif event == "PLAYER_LOGIN" then
		createCompass()
	end
	-- if GetPlayerFacing() then
	-- 	setQuestsIcons()
	-- 	setCardinalDirections()
	-- end
end)

Addon:RegisterEvent("PLAYER_LOGIN")
Addon:RegisterEvent("PLAYER_ENTERING_WORLD")
Addon:RegisterEvent("ZONE_CHANGED")
Addon:RegisterEvent("QUEST_ACCEPTED")
Addon:RegisterEvent("QUEST_LOG_UPDATE")
Addon:RegisterEvent("QUEST_POI_UPDATE")
