




-- Initialize the frame with records for all group members, with "?"
-- showing as the value of their rolls, indicating that no one has rolled yet
function RCFUI_ResetAndDisplayCaptureFrame()
    RollCaptureFrame:UpdateGroupRoster()
    -- TODO: Hide both the Announce and Tiebreaker buttons
    -- TODO: Initialize all the player rows
	RCF_RollResults = {}
	return
end

-- Hides the "Announce" button and replaces it with a "Tiebreaker" button
-- tiedPlayersString - a human-readable comma-separated list of tied players to announce
-- highRoll - the specific value that these players all rolled
function RCFUI_ToggleTiebreakerButton(tiedPlayersString, highRoll)
    -- Hide the Announce button
    -- Display the Tiebreaker button
    -- Update the OnClick of the Tiebreaker button
    SendChatMessage(format("%s are all TIED with a roll of %s. Please re-roll now!",formattedString, highRoll), RAID, CEPGP_LANGUAGE);
end

-- Hides the "Tiebreaker" button and replaces it with an "Announce" button
-- winner - the player who won the roll
-- highRoll - the specific value that the winner rolled
function RCFUI_ToggleAnnounceButton(winner, highRoll)
    -- Hide the Tiebreaker button
    -- Display the Announce button
    -- Update the OnClick of the Announce button
    SendChatMessage(format("%s wins with a roll of %s!",winner, highRoll), RAID, CEPGP_LANGUAGE);
    RCF_rollInProgress = false
    RollCaptureFrame:UpdateGroupRoster()
	RCF_RollResults = {}    
end

-- Updates the row record for the given player
function RCFUI_UpdateRowForPlayer(player, rollResult)
    -- Update this player's record with the value, and set the color to Green
    -- Refresh the scrollview to apply the descending sort
end