local addonName, RollCaptureFrame = ...
SLASH_RCF = "/rcf";
RCF_GroupRosterAndRelatedMetadata = {}
RCF_rollInProgress = false
RCF_RollResults = {}
RCF_tied_players = {}

-- TODO: Make sure setting these here doesn't blow away the user's stored setting
RCFAutoLaunch = false
RCFNotifyDuplicateRolls = false
RCFMaxRoll = 100



-- Initial frame necessary to kick off the AddOn
local frame = CreateFrame("FRAME", "RollCaptureFrameInitialLoadFrame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
local function eventHandler(self, event, ...)
	RollCaptureFrame:RegisterCallback("ADDON_LOADED", RollCaptureFrame.Initialize, ...)
	RollCaptureFrame:RegisterCallback("GROUP_ROSTER_UPDATE", RollCaptureFrame.UpdateGroupRoster)
	RollCaptureFrame:RegisterCallback("CHAT_MSG_SYSTEM", RollCaptureFrame.ProcessRollResultAndUpdateFrame, ...)
end
frame:SetScript("OnEvent", eventHandler);

-- TODO: Make sure this actually receives the Args from the event
function RollCaptureFrame.Initialize(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
	if arg1 == "RollCaptureFrame" then --arg1 = addon name
		RCF_rollInProgress = false
		if RCFAutoLaunch == nil then
			RCFAutoLaunch = false
		end
		if RCFNotifyDuplicateRolls == nil then
			RCFNotifyDuplicateRolls = false
		end
		if RCFMaxRoll == nil then
			RCFMaxRoll = 100
		end
		if RCF_GroupRosterAndRelatedMetadata == nil then
			RCF_GroupRosterAndRelatedMetadata = {}
		end
	end
end

function RollCaptureFrame:UpdateGroupRoster()
	-- Only allow updates to the group roster if a roll is not currently being resolved
	if RCF_rollInProgress then
		return
	end
	RCF_GroupRosterAndRelatedMetadata = {};
	if UnitInRaid("player") then
		for i = 1, GetNumGroupMembers() do
			local name, _, group, _, class = GetRaidRosterInfo(i);
			if not name then break; end
			RCF_GroupRosterAndRelatedMetadata[name] = {
				[1] = class, -- The player's class
				[2] = group -- The raid group the player is in
			};
		end
	else
		-- TODO: Add 5man group handling?
		return
	end
end


function RollCaptureFrame:ProcessRollResultAndUpdateFrame(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
	-- Regex matches "Akaran rolls 1 (1-100)"
	local name, rollResult, minRoll, maxRoll = arg1:match("^(.+) rolls (%d+) %((%d+)%-(%d+)%)$")

	-- This is how we test to make sure we're processing a Roll Event of the
	-- range specified by RCFMaxRoll
	if name and maxRoll == RCFMaxRoll then

		-- If the frame isn't showing but a roll event was received, we check to see
		-- if the RCFAutoLaunch flag is set and, if so, initialize and launch the RCF frame
		if RCFAutoLaunch and not RCF_rollInProgress then
			RCF_rollInProgress = true
			RCFUI_ResetAndDisplayCaptureFrame()
		elseif not RCF_rollInProgress then
			return
		end

		-- Only process the roll if the player is in the raid group. This is likely unnecessary
		-- since the player wouldn't even see the chat message if the player isn't in the group,
		-- but a little extra precaution never hurt anybody
		if not RCF_tContains(RCF_GroupRosterAndRelatedMetadata, name, true) then
			return
		end

		-- If there are a nonzero number of tied players, then we are currently awaiting
		-- our tied players to finish rolling off, so we only want to focus on them
		if RCF_ntgetn(RCF_tied_players) > 0 then
			for index, record in pairs(RCF_tied_players) do
				if name == record["playerName"] then
					if tonumber(record["rollResult"]) == 0 then
						record["rollResult"] = tonumber(rollResult)
					elseif RCFNotifyDuplicateRolls then
						RollCaptureFrame:Print(format("Player %s just rolled again, but he/she has already rolled previously and got a %s", name, record["rollResult"]))
					end
					break
				end
			end
			-- See if we have all tiebreker rolls in now and determine a winner
			RollCaptureFrame:checkIfAllTieBreakerRollsAreInAndDetermineWinner()
			return
		end

		-- If a record for this member doesn't yet exist, then this is the first roll
		-- we are receiving from this member, so we process it and update the UI
		if not RCF_tContains(RCF_RollResults, name, true) then
			RCF_RollResults[name] = {
				[1] = tonumber(rollResult),
			}
			RollCaptureFrame:UpdateRowForPlayer(name, tonumber(rollResult))
		elseif RCFNotifyDuplicateRolls then
			RollCaptureFrame:Print(format("Player %s just rolled again, but he/she has already rolled previously and got a %s", name, RCF_RollResults[name][1]))
		end

		-- Check to see if all rolls are now in and, if so, announce the winner
		if RollCaptureFrame:HaveAllMembersRolled() then
			local winner, highRoll = RollCaptureFrame:DetermineWinner()

			-- Based on whether or not the winner is a tie, we want to update the
			-- "Announce" button accordingly.
			if string.find(winner, "+") then
				-- Initialize the Table that will contain the re-rolls of the tied players
				RCF_tied_players = {}
				local _, num = string.gsub(winner, "+", "")
				RCF_tied_players = RCF_split(winner, "+", num)

				-- Do a slight transform of this data into a slightly simpler format
				local transformed_tied_players = {}
				for index,playerName in pairs(RCF_tied_players) do
					transformed_tied_players[index] = {}
					transformed_tied_players[index]["playerName"] = playerName
					transformed_tied_players[index]["rollResult"] = 0
				end
				RCF_tied_players = transformed_tied_players

				-- Separate out all of the winners from the "+"-separated string
				local formattedString, numWinners = string.gsub(winner, "+", ", ")

				-- Enable the "Tiebreaker" butto
				RCFUI_ToggleTiebreakerButton(formattedString, highRoll)
			else
				-- A winner has been determined!
				RCF_tied_players = {}
				-- Enable the "Announce" button
				RCFUI_ToggleAnnounceButton(winner, highRoll)
				return
			end
		end

	end
end

-- Determines a winner and returns it as a string. If multiple players are tied,
-- the string will be in the format "Akaran+Anarra+Iopo"
function RollCaptureFrame:DetermineWinner()
	local highRoll = 0
	local winner = "No One"
	for player, playerRecord in pairs(RCF_RollResults) do
		local playerRoll = playerRecord[1]
		if playerRoll > highRoll then
			highRoll = playerRoll
			winner = player
		elseif playerRoll == highRoll then
			winner = winner .. "+" .. player
		end
	end
	return winner, highRoll
end

function RollCaptureFrame:checkIfAllTieBreakerRollsAreInAndDetermineWinner()
	local numRollsWeAreWaitingFor = RCF_ntgetn(RCF_tied_players)
	local numRollsReceived = 0
	for index, playerRecord in pairs(RCF_tied_players) do
		if playerRecord["rollResult"] > 0 then
			numRollsReceived = numRollsReceived + 1

			-- All rolls are in for the current item. Determine winner.
			if numRollsReceived == numRollsWeAreWaitingFor then
				local highRoll = 0
				local winner = "No One"
				for index, playerRecord in pairs(RCF_tied_players) do
					if playerRecord["rollResult"] > highRoll then
						highRoll = playerRecord["rollResult"]
						winner = playerRecord["playerName"]
					elseif playerRecord["rollResult"] == highRoll then
						winner = winner .. "+" .. playerRecord["playerName"]
					end
				end

				-- Determine the actual winner, and re-initiate the roll if necessary
				if string.find(winner, "+") then
					-- Initialize the Table that will contain the re-rolls of the tied players
					RCF_tied_players = {}
					local _, num = string.gsub(winner, "+", "")
					RCF_tied_players = RCF_split(winner, "+", num)

					-- Do a slight transform of this data into a slightly simpler format
					local transformed_tied_players = {}
					for index,playerName in pairs(RCF_tied_players) do
						transformed_tied_players[index] = {}
						transformed_tied_players[index]["playerName"] = playerName
						transformed_tied_players[index]["rollResult"] = 0
					end
					RCF_tied_players = transformed_tied_players

					-- Separate out all of the winners from the "+"-separated string
					local formattedString, numWinners = string.gsub(winner, "+", ", ")

					-- Enable the "Tiebreaker" butto
					RCFUI_ToggleTiebreakerButton(formattedString, highRoll)
				else
					-- A winner has been determined!
					RCF_tied_players = {}
					-- Enable the "Announce" button
					RCFUI_ToggleAnnounceButton(winner, highRoll)
					return
				end
			end
		end
	end
end

-- Simple function that confirms whether or not all members in the
-- current group have successfully rolled. Returns "true" if so, "false" otherwise
function RollCaptureFrame:HaveAllMembersRolled()
	if not RCF_GroupRosterAndRelatedMetadata then
		return false
	end

	-- If even one member has not yet rolled, return false
	for player, record in pairs(RCF_GroupRosterAndRelatedMetadata) do
		if not RCF_tContains(RCF_RollResults, player, true) then
			return false
		end
	end
	return true
end

-- Registers all of the slash commands the player who is running this AddOn can invoke
function SlashCmdList.RCF(msg, editbox)
	msg = string.lower(msg);
	if msg ~= "" then
		CEPGP_print("|cFFFF8080 RollCaptureFrame does not currently support any arguments. You can configure everything via the UI.|r", true);
	end
	RCF_rollInProgress = true
	RCFUI_ResetAndDisplayCaptureFrame()
end



------------------------------
-- Event/Callback Functions --
------------------------------

-- Callback registration logic lifted from user "zork" on the wowinterface.com forums:
-- Thread: https://www.wowinterface.com/forums/showthread.php?t=54358
function RollCaptureFrame:RegisterCallback(event, callback, ...)
	if not self.eventFrame then self.eventFrame = CreateFrame("Frame") end
	function self.eventFrame:OnEvent(event, ...)
		for callback, args in next, self.callbacks[event] do
			callback(args, ...)
		end
	end
	self.eventFrame:SetScript("OnEvent", self.eventFrame.OnEvent)
	if not self.eventFrame.callbacks then self.eventFrame.callbacks = {} end
	if not self.eventFrame.callbacks[event] then self.eventFrame.callbacks[event] = {} end
	self.eventFrame.callbacks[event][callback] = {...}
	self.eventFrame:RegisterEvent(event)
end
function RollCaptureFrame:UnregisterEvent(event)
	self.eventFrame:UnregisterEvent(event)
end


----------------------------
-- General/Core Functions --
----------------------------

-- Prints to the console with a bit of color added
function RollCaptureFrame:Print(...)
	local text = "|cff33ff99RollCaptureFrame|r:"
	for i = 1, select("#", ...) do
		text = text.." "..tostring(select(i, ...))
	end
	print(text)
end

-- Checks whether or not the given table "t" contains VALUE "val"
-- If checkKeyInsteadOfVal is true then CEPGP_tContains() returns
-- true if the table contains a KEY with the name "val"
-- Kudos to the author of Classic EPGP for this useful function
function RCF_tContains(t, val, checkKeyInsteadOfVal)
	if not t then return; end
	if checkKeyInsteadOfVal == nil then
		for _,value in pairs(t) do
			if value == val then
				return true;
			end
		end
	elseif checkKeyInsteadOfVal == true then
		for index,_ in pairs(t) do 
			if index == val then
				return true;
			end
		end
	end
	return false;
end

-- Returns the number of records in the given table
-- Kudos to the author of Classic EPGP for this useful function
function RCF_ntgetn(tbl)
	if tbl == nil then
		return 0;
	end
	local n = 0;
	for _,_ in pairs(tbl) do
		n = n + 1;
	end
	return n;
end

-- Kudos to the author of Classic EPGP for this useful function
function RCF_split(str, delim, iters) --String to be split, delimiter, number of iterations
	local frags = {};
	local remainder = str;
	local count = 1;
	for i = 1, iters+1 do
		if string.find(remainder, delim) then
			frags[count] = string.sub(remainder, 1, string.find(remainder, delim)-1);
			remainder = string.sub(remainder, string.find(remainder, delim)+1, string.len(remainder));
		else
			frags[count] = string.sub(remainder, 1, string.len(remainder));
		end
		count = count + 1;
	end
	return frags;
end