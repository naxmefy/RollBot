
local RB = RollBot
local log = FH3095Debug.log

function RB:isMasterLooterActive()
	local lootMethod = GetLootMethod()
	if IsInRaid() and lootMethod == "master" then
		return true
	end
	return false
end

function RB:isMyselfMasterLooter()
	local lootMethod, masterLooterPartyId = GetLootMethod()
	if IsInRaid() and lootMethod == "master" and masterLooterPartyId == 0 then
		return true
	end
	return false
end

function RB:getMasterLooter()
	if not self:isMasterLooterActive() then
		return nil
	end
	local _, _, masterLooterRaidId = GetLootMethod()
	local ret = GetRaidRosterInfo(masterLooterRaidId)
	return ret
end

function RB:scheduleTimer(func, delay)
	local timerFunc = function()
		func(RB)
	end
	self.timers:ScheduleTimer(timerFunc, delay)
end

function RB:getOwnRaidInfo()
	local ownRaidId = UnitInRaid("player")
	if ownRaidId == nil then
		return nil
	end
	return GetRaidRosterInfo(ownRaidId)
end

function RB:isUserMasterLooter(user)
	local userRaidId = UnitInRaid(user)
	if userRaidId == nil then
		return false
	end
	local _,_,_,_,_,_,_,_,_,_, isMasterLooter = GetRaidRosterInfo(userRaidId)
	if isMasterLooter == true then
		return true
	end
	return false
end

function RB:sendMasterLooterSettings()
	log("SendMasterLooterSettings")
	local data = self.serializer:Serialize(self.vars.rolls)
	self.com:SendCommMessage(self.consts.ADDON_MSGS.lootOptionsResp, data, "RAID")
end

function RB:convertOwnSettingsToRaidSettings()
	local ret = {}
	for i = 1,self.db.profile.numRollOptions do
		ret[i] = self.db.profile.rolls[i]
	end
	ret["rollTime"] = self.db.profile.rollTime
	return ret
end

function RB:doRoll(max)
	RandomRoll(1, max)
end

function RB:sendChatMessage(msg)
	local _, ownRank = self:getOwnRaidInfo()

	local chatMsgType = self.db.profile.rollChatMsgType
	if ownRank <= 0 and chatMsgType == "RAID_WARNING" then
		chatMsgType = "RAID"
	end
	SendChatMessage(msg, chatMsgType)
end

function RB:startRoll(itemLink)
	if itemLink == nil then
		self:consolePrintError("To start a roll we need an item")
		return
	end
	local itemName = GetItemInfo(itemLink)
	if nil == itemName then
		self:consolePrintError("Invalid item link: %s", itemLink)
		return
	end
	local success, ownRank = self:getOwnRaidInfo()
	if success == nil then
		self:consolePrintError("Not in raid")
		return
	end
	if not self:isMyselfMasterLooter() then
		self:consolePrintError("You are not the master looter")
		return
	end

	self:openResultWindow()
	self:resultClearRolls()
	self.com:SendCommMessage(self.consts.ADDON_MSGS.startRoll, itemLink, "RAID")
	self:sendChatMessage(self.db.profile.rollText:format(itemLink, self.db.profile.rollTime))
	self:openRollTimerWindowAndStart()
end

function RB:isTableEmpty(tbl)
	for _,_ in pairs(tbl) do
		return false
	end
	return true
end

function RB:getWindowPos(frame, includeSize)
	local result = {}

	for i=1,frame:GetNumPoints() do
		local point, _, relativePoint, xOfs, yOfs = frame:GetPoint(i)
		local posData = { relativePoint = relativePoint, xOfs = xOfs, yOfs = yOfs }
		result[point] = posData
	end
	if includeSize then
		result[self.consts.WINDOW_WIDTH] = frame.frame:GetWidth()
		result[self.consts.WINDOW_HEIGHT] = frame.frame:GetHeight()
	end

	log("saveWindowPos: Result", result)
	return result
end

function RB:restoreWindowPos(frame, array, defaultPos)
	log("RestoreWindowPos", array, defaultPos)

	local posArray = array
	if posArray == nil or RB:isTableEmpty(posArray) then
		posArray = defaultPos
	end

	for point,posData in pairs(posArray) do
		if point ~= self.consts.WINDOW_WIDTH and point ~= self.consts.WINDOW_HEIGHT then
			frame:SetPoint(point, "UIParent", posData.relativePoint, posData.xOfs, posData.yOfs)
		end
	end
	if posArray[self.consts.WINDOW_WIDTH] ~= nil and posArray[self.consts.WINDOW_HEIGHT] ~= nil then
		frame:SetWidth(posArray[self.consts.WINDOW_WIDTH])
		frame:SetHeight(posArray[self.consts.WINDOW_HEIGHT])
	end
end
