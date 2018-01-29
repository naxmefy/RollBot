
local RB = RollBot
local libI = LibStub("LibInspect")
local log = FH3095Debug.log
local module = {
	vars = {
		cache = {},
		counter = 1,
		inspectTimerId = nil,
		cleanupTimerId = nil,
	},
	consts = {
		RAID_MIN = 1,
		RAID_MAX = 40,
		CLEANUP_INTERVAL = 30 * 60,
		INSPECT_INTERVAL = 7,
		REFRESH_INTERVAL = 10 * 60,
	},
}

function module:inspectPlayer(unitId)
	if not (UnitIsConnected(unitId) and CanInspect(unitId) and not InCombatLockdown()) then
		return false
	end

	local canInspect, unitFound = libI:RequestData("items", unitId, false)
	log("InspectPlayer DataRequested", canInspect, unitFound)
	if not canInspect or not unitFound then
		return false
	end
	return true
end

function module:cleanupCache()
	log("InspectCleanupCache")
	local existingGUIDs = {}
	for i=self.consts.RAID_MIN,self.consts.RAID_MAX do
		local guid = UnitGUID("raid" .. i)
		if guid ~= nil then
			existingGUIDs[guid] = true
		end
	end
	for guid,_ in pairs(self.vars.cache) do
		if existingGUIDs[guid] == nil then
			log("InspectCleanupCache Player removed", guid)
			self.vars.cache[guid] = nil
		end
	end
end

function module:runCheck()
	if not IsInRaid() or InCombatLockdown() then
		return
	end

	local i = self.vars.counter
	local curTime = time()
	while i <= self.consts.RAID_MAX do
		local unitId = "raid" .. i
		local unitGuid = UnitGUID(unitId)
		if (self.vars.cache[unitGuid] == nil or self.vars.cache[unitGuid].maxAge <= curTime) and self:inspectPlayer(unitId) then
			break
		end
		i = i + 1
	end

	i = i + 1
	if i > self.consts.RAID_MAX then
		i = self.consts.RAID_MIN
	end
	self.vars.counter = i
end

function module:inspectReady(guid, data, age)
	log("InspectReady", guid, age)
	self.vars.cache[guid] = {}
	self.vars.cache[guid].maxAge = time() + self.consts.REFRESH_INTERVAL
	self.vars.cache[guid].items = data.items
	log("InspectReady done", guid, self.vars.cache[guid])
end

function RB:inspectStart()
	log("InspectStart")
	libI:SetMaxAge(module.consts.REFRESH_INTERVAL - 1)
	libI:AddHook(self.consts.ADDON_NAME, "items", function(guid, data, age) module:inspectReady(guid, data, age) end)
	if module.vars.timerId == nil then
		module.vars.inspectTimerId = self.timers:ScheduleRepeatingTimer(module.runCheck, module.consts.INSPECT_INTERVAL, module)
	end
	if module.vars.cleanupTimerId == nil then
		module.vars.cleanupTimerId = self.timers:ScheduleRepeatingTimer(module.cleanupCache, module.consts.CLEANUP_INTERVAL, module)
	end
end

function RB:inspectGetItemForSlot(player, slot)
	local guid = UnitGUID(player)
	local result = {}
	if module.vars.cache[guid] == nil or module.vars.cache[guid].items == nil then
		return result
	end

	for i=INVSLOT_FIRST_EQUIPPED,INVSLOT_LAST_EQUIPPED do
		local itemLink = module.vars.cache[guid].items[i]
		if itemLink ~= nil then
			local _,_,_,itemEquipLoc = GetItemInfoInstant(itemLink)
			if itemEquipLoc == slot then
				tinsert(result, itemLink)
			end
		end
	end
	log("InspectGetItem player, guid, slot, result", player, guid, slot, result)
	return result
end