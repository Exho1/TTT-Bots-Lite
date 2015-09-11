if CLIENT then return end

tttBot = tttBot or {}

tttBot.winPercent = 0.66
tttBot.roundStartDelay = 120
tttBot.totalVotes = 0
tttBot.roundStartTime = 0
tttBot.chatCommands2 = {
	"!kickbot",
	"!nomorebot",
	"!bot",
}

function tttBot.shouldChange()
	return tttBot.totalVotes >= math.Round(#player.GetHumans()*tttBot.winPercent)
end

function tttBot.start()
	for _, bot in pairs( player.GetBots() ) do
		bot:Kick("Not wanted here")
	end
	
	PrintMessage( HUD_PRINTTALK, "All of the bots have been kicked as per the vote. They will return on the next map." )
	
	tttBot.shouldSpawnBots = false
end

function tttBot.addVote( ply )
	if tttBot.canVote( ply ) then
		tttBot.totalVotes = tttBot.totalVotes + 1
		ply.alreadyVoted = true
		MsgN( ply:Nick().." has voted to kick the bots" )
		local per = math.Round(#player.GetHumans()*tttBot.winPercent)

		PrintMessage( HUD_PRINTTALK, ply:Nick().." has voted to kick the bots. ("..tttBot.totalVotes.."/"..per..")" )

		if tttBot.shouldChange() then
			tttBot.start()
		end
	end
end

function tttBot.removeVote()
	tttBot.totalVotes = math.Clamp( tttBot.totalVotes - 1, 0, math.huge )
end

function tttBot.canVote( ply )
	local plyCount = table.Count(player.GetHumans())
	
	if #player.GetBots() == 0 then
		return false, "There are no bots to kick"
	elseif ply.alreadyVoted then
		return false, "You have already voted to kick the bots!"
	end
	return true
end


function tttBot.startVote( ply )
	local can, err = tttBot.canVote(ply)
	if not can then
		ply:ChatPrint(err)
		return ""
	end
	tttBot.addVote( ply )
end

hook.Add( "PlayerSay", "tttBotChatCommands", function( ply, text )
	text = string.lower(text)

	for k, v in pairs( tttBot.chatCommands2 ) do
		if string.sub(text, 1, string.len(v)) == v then
			tttBot.startVote( ply )
			return ""
		end
	end
end)

hook.Add( "PlayerDisconnected", "RemoveDCedVotes", function( ply )
	if ply.alreadyVoted then
		tttBot.removeVote()
	end
end)

function tttBot.reset()
	tttBot.roundStartTime = CurTime()
	
	for _, ply in pairs( player.GetHumans() ) do
		ply.alreadyVoted = false
		tttBot.totalVotes = 0
	end
end

hook.Add("TTTEndRound", "tttBotReset", tttBot.reset)
hook.Add("TTTBeginRound", "tttBotReset", tttBot.reset)
